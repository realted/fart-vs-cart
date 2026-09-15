#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <vector>
#include <memory>
#include <SDL2/SDL.h>
#include <string>
#include <windows.h>
#include "objects.hpp"
#include "obj_loader.h"

// This is what happens to rays that are diffused
std::mt19937 generator(42);
std::uniform_real_distribution<double> distribution(0,1);
double random01() { return distribution(generator); }
Vec3 randomUnit() {
    for (;;) {
        Vec3 v{2*random01()-1,2*random01()-1,2*random01()-1};
        double lengthSquared=dot(v,v);
        if(lengthSquared>1e-10 && lengthSquared<1) return unit(v);
    }
}

// MODEL SETTINGS: edit these values, then rebuild SDL.cpp.
// R"(...)" accepts Windows paths without doubling each backslash.
// Leave modelPath empty to render the original demonstration triangle.
const std::string modelPath = R"(C:\Users\Ted\Desktop\y4proj\fart_vs_cart\ray-tracer\models\utah_teapot.obj)";
const double modelScale = 0.2;
const Vec3 modelPosition = {1.0, -0.15, -1.2}; // X, Y, Z
const Material modelMaterial = {{0.8, 0.2, 0.5}, false, {0, 0, 0}};

// Initialize objects
std::vector<std::shared_ptr<Object>> objects = {
    std::make_shared<Sphere>(Vec3{0,0,-1.2},0.5,Material{Vec3{0.16,0.48,0.85},false,{0,0,0}}),
    std::make_shared<Sphere>(Vec3{-1.05,-0.05,-1.6},0.5,Material{Vec3{1,0.6,0},true,{0,0,0}}),
    //std::make_shared<Sphere>(Vec3{0,-20.5,-1},20,Material{Vec3{0.65,0.68,0.72},false,{0,0,0}}),
    std::make_shared<Plane>(Vec3{0,-0.5,0},Vec3{1,0,0},Vec3{0,0,1},Material{Vec3{0.1,0.78,0.2},false,{0,0,0}}),
    std::make_shared<Triangle>(Vec3{0.4,-0.3,-0.3},Vec3{1.0,-0.3,-0.3},Vec3{0.7,0.4,-0.3},Material{Vec3{0.8,0.2,0.5},false,{0,0,0}}),
    std::make_shared<Sphere>(Vec3{1,1.2,-1.2},0.5,Material{Vec3{1,1,1},false,{10,10,10}})
};

// Trace function acts as the main logic for how rays behave.
Vec3 trace(Ray ray, int depth) {
    if(depth==0) return {0,0,0};
    double nearest = std::numeric_limits<double>::infinity();
    bool didHit = false;
    HitProfile closestHit{};
    for (const auto& object : objects) {
        HitProfile tempHit{};

        if (object->intersect(ray, tempHit)) {
            if (tempHit.dst < nearest) {
                nearest = tempHit.dst;
                closestHit = tempHit;
                didHit = true;
            }
        }
    }

    if(didHit) {
        Vec3 direction;
        Vec3 emitted = closestHit.material.emission;
        if (dot(emitted, emitted) > 0) {
            return emitted;
        }
        if(closestHit.material.metal) {
            Vec3 incoming=unit(ray.direction);
            direction=incoming-closestHit.normal*(2*dot(incoming,closestHit.normal));
        } else {
            direction=closestHit.normal+randomUnit();
            if(dot(direction,direction)<1e-10) direction=closestHit.normal;
        }
        Vec3 bounceColor=closestHit.material.color*trace({closestHit.hitPoint,direction},depth-1);
        return emitted+bounceColor;
    }
    double reg_blend=0.5*(unit(ray.direction).y+1);
    double sharp_blend = 1.0/(1+std::exp(-10.0*ray.direction.y));
    return Vec3{1,1,1}*(1-reg_blend)+Vec3{0.45,0.65,1}*reg_blend;
}

int main(int argc, char** argv) {
    SDL_Window* window=nullptr;
    SDL_Renderer* renderer=nullptr;
    SDL_Texture* texture=nullptr;
    int result=0;
    try {
        int width=argc>1?std::stoi(argv[1]):640;
        int samples=argc>2?std::stoi(argv[2]):64;
        bool autoClose=false;
        std::string objPath=modelPath;
        double objScale=modelScale;
        Vec3 objPosition=modelPosition;
        for(int i=3;i<argc;++i) {
            std::string option=argv[i];
            if(option=="--auto-close") autoClose=true;
            else if(option=="--obj" && i+1<argc) objPath=argv[++i];
            else if(option=="--scale" && i+1<argc) objScale=std::stod(argv[++i]);
            else if(option=="--position" && i+3<argc) {
                objPosition.x=std::stod(argv[++i]);
                objPosition.y=std::stod(argv[++i]);
                objPosition.z=std::stod(argv[++i]);
            } else throw std::runtime_error("Usage: SDL.exe [width samples] [--obj file.obj] [--scale s] [--position x y z] [--auto-close]");
        }
        if(!objPath.empty()) {
            auto mesh=loadObj(objPath,modelMaterial,objScale,objPosition);
            // Replace the original demonstration triangle with the imported model.
            objects.erase(objects.begin()+3);
            objects.insert(objects.end(),mesh.begin(),mesh.end());
        }
        if(width<16 || width>4096 || samples<1 || samples>4096)
            throw std::runtime_error("Width must be 16..4096; samples must be 1..4096.");
        int height=width*9/16;
        SDL_SetMainReady();
        auto check=[](bool ok) { if(!ok) throw std::runtime_error(SDL_GetError()); };
        check(SDL_Init(SDL_INIT_VIDEO)==0);
        window=SDL_CreateWindow("Progressive ray tracer",SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,width,height,SDL_WINDOW_SHOWN);
        check(window!=nullptr);
        renderer=SDL_CreateRenderer(window,-1,SDL_RENDERER_ACCELERATED);
        if(!renderer) renderer=SDL_CreateRenderer(window,-1,SDL_RENDERER_SOFTWARE);
        check(renderer!=nullptr);
        texture=SDL_CreateTexture(renderer,SDL_PIXELFORMAT_RGB24,
            SDL_TEXTUREACCESS_STREAMING,width,height);
        check(texture!=nullptr);
        std::vector<Vec3> accumulation(static_cast<size_t>(width)*height,Vec3{0,0,0});
        std::vector<unsigned char> pixels(static_cast<size_t>(width)*height*3,0);
        auto channel=[](double c) {
            if(!std::isfinite(c) || c<=0) return static_cast<unsigned char>(0);
            return static_cast<unsigned char>(256*std::clamp(std::sqrt(c),0.0,0.999));
        };
        bool running=true;
        auto events=[&]() {
            SDL_Event event;
            while(SDL_PollEvent(&event)) {
                if(event.type==SDL_QUIT || (event.type==SDL_KEYDOWN && event.key.keysym.sym==SDLK_ESCAPE))
                    running=false;
            }
        };
        auto present=[&]() {
            check(SDL_UpdateTexture(texture,nullptr,pixels.data(),width*3)==0);
            check(SDL_RenderClear(renderer)==0);
            check(SDL_RenderCopy(renderer,texture,nullptr,nullptr)==0);
            SDL_RenderPresent(renderer);
        };
        present();
        for(int sample=0;sample<samples && running;++sample) {
            //Sleep(500);
            for(int y=0;y<height && running;++y) {
                events(); // Poll each row, not only once per full image.
                if(!running) break;
                for(int x=0;x<width;++x) {
                    double u=(x+random01())/width;
                    // SDL row zero is the TOP. Original BMP camera y increases upward.
                    double v=1.0-(y+random01())/height;
                    Vec3 value=trace({{0,0.35,1.3},
                        {(2*u-1)*double(width)/height,(2*v-1)-0.15,-2.3}},12);
                    size_t index=static_cast<size_t>(y)*width+x;
                    accumulation[index]=accumulation[index]+value;
                    Vec3 color=accumulation[index]*(1.0/(sample+1));
                    pixels[index*3]=channel(color.x);     // RGB, not BMP's BGR
                    pixels[index*3+1]=channel(color.y);
                    pixels[index*3+2]=channel(color.z);
                }
            }
            if(!running) break;
            present();
            std::string title="Ray tracer: "+std::to_string(sample+1)+" / "+std::to_string(samples)+" samples";
            SDL_SetWindowTitle(window,title.c_str());
        }
        if(running) {
            std::cout<<"Completed "<<width<<"x"<<height<<" at "<<samples<<" samples/pixel.\n";
            SDL_SetWindowTitle(window,"Render complete - Escape or close to exit");
        }
        while(running && !autoClose) {
            events();
            check(SDL_RenderClear(renderer)==0);
            check(SDL_RenderCopy(renderer,texture,nullptr,nullptr)==0);
            SDL_RenderPresent(renderer);
            SDL_Delay(16);
        }
    } catch(const std::exception& error) {
        std::cerr<<error.what()<<'\n'; result=1;
    }
    if(texture) SDL_DestroyTexture(texture);
    if(renderer) SDL_DestroyRenderer(renderer);
    if(window) SDL_DestroyWindow(window);
    SDL_Quit();
    return result;
}

