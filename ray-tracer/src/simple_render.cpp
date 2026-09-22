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

// Light Initialization
auto light1 = std::make_shared<Sphere>(
    Vec3{0.0, 1.35, -0.7},
    0.25,
    Material{{1, 1, 1}, false, {25, 25, 25}}
);

std::vector<std::shared_ptr<Sphere>> lights = {light1};

// List of wall objects for the scene
std::vector<std::shared_ptr<Object>> objects = [] {
    std::vector<std::shared_ptr<Object>> scene;
    Material pink  {{0.75, 0.18, 0.35}, false, {0,0,0}};
    Material dark  {{0.035, 0.025, 0.03}, false, {0,0,0}};
    Material cream {{0.80, 0.72, 0.62}, false, {0,0,0}};
    Material lightdark {{0.14, 0.14, 0.14}, false, {0,0,0}};

    // Left wall
    scene.push_back(std::make_shared<Square>(
        Vec3{-1.3, -0.5, -4},
        Vec3{0, 1.9, 0}, Vec3{0, 0, 4}, pink
    ));

    // Right wall
    scene.push_back(std::make_shared<Square>(
        Vec3{1.3, -0.5, -4},
        Vec3{0, 1.9, 0}, Vec3{0, 0, 4}, pink
    ));

    // Back wall
    scene.push_back(std::make_shared<Square>(
        Vec3{-1.3, -0.5, -4},
        Vec3{2.6, 0, 0}, Vec3{0, 1.9, 0}, dark
    ));

    // Ceiling
    scene.push_back(std::make_shared<Square>(
        Vec3{-1.3, 1.4, -4},
        Vec3{2.6, 0, 0}, Vec3{0, 0, 4}, cream
    ));

    scene.push_back(std::make_shared<Square>(
    Vec3{-1.3, -0.5, -4},
    Vec3{2.6, 0, 0},
    Vec3{0, 0, 4},
    lightdark
    ));

    // Metallic Sphere
    scene.push_back(std::make_shared<Sphere>(
    Vec3{0.0, 0.0, -1.225},
    0.5,
    Material{Vec3{0.5, 0.5, 0.5}, true, {0, 0, 0}}
    ));

    scene.push_back(std::make_shared<Square>(
    Vec3{-2.0, 0.2, 3.2}, // Corner
    Vec3{4.0, 0, 0},      // Width
    Vec3{0, 1.6, 0},      // Height
    pink
    ));

    scene.push_back(light1);
    return scene;
}();

// Light sampling function. This ensures rays are not only randomly diffused to a bright area, but also intentionally sampled to there. 
Vec3 sampleDirectLightSphere(const HitProfile& hit, const Sphere& light) {
    constexpr double pi = 3.141592653589793;
    constexpr double epsilon = 0.001;

    // Uniformly sample the sphere's entire surface.
    Vec3 lightNormal = randomUnit();
    Vec3 lightPoint = light.center+lightNormal*light.radius; // Here is the point on the surface of the light
    Vec3 toLight = lightPoint-hit.hitPoint;
    double distanceSquared = dot(toLight, toLight); // Distance to the sample point

    if (distanceSquared <= epsilon * epsilon)
        return {0, 0, 0};

    
    // Implement Lambert's Cosine Law
    Vec3 lightDir = toLight*(1.0 / std::sqrt(distanceSquared));
    double surfaceCos = std::max(0.0, dot(hit.normal, lightDir));
    double lightCos = std::max(0.0, dot(lightNormal, lightDir * -1.0));

    // Reject directions below the surface and the light's far side.
    if (surfaceCos <= 0 || lightCos <= 0)
        return {0, 0, 0};

    // Aim from the offset origin toward the sampled endpoint.
    Vec3 origin = hit.hitPoint + hit.normal * epsilon;
    Vec3 shadowVector = lightPoint - origin;
    double shadowDistance = std::sqrt(dot(shadowVector, shadowVector));

    if (shadowDistance <= epsilon)
        return {0, 0, 0};

    Ray shadowRay{
        origin,
        shadowVector*(1.0/shadowDistance)
    };

    // Check if anything is blocking the sampled light point
    for (const auto& object : objects) {
        HitProfile blocker{};
        if (object->intersect(shadowRay, blocker) &&
            blocker.dst < shadowDistance - epsilon) {
            return {0, 0, 0};
        }
    }

    double area = 4.0*pi*light.radius*light.radius;
    double weight = area*surfaceCos*lightCos/(pi*distanceSquared);
    return hit.material.color*light.material.emission*weight;
}

// Trace function acts as the main logic for how rays behave
Vec3 trace(Ray ray, int depth, bool allowSampledLightEmission = true, bool cameraRay = false) {
    if(depth==0) return {0,0,0};
    double nearest = std::numeric_limits<double>::infinity();
    bool didHit = false;
    const Object* closestObject = nullptr;
    HitProfile closestHit{};
    for (const auto& object : objects) {
        HitProfile tempHit{};

        if (object->intersect(ray, tempHit)) {
            if (tempHit.dst < nearest) {
                nearest = tempHit.dst;
                closestHit = tempHit;
                closestObject = object.get();
                didHit = true;
            }
        }
    }

    if(didHit) {
        constexpr double epsilon = 0.001;
        Vec3 origin = closestHit.hitPoint+closestHit.normal*epsilon;
        Vec3 emitted = closestHit.material.emission;

        bool isSampledLight = std::any_of(
            lights.begin(), lights.end(),
            [closestObject](const auto& light) {
                return light.get() == closestObject;
            }
        );

        if (dot(emitted, emitted) > 0) {
            if (isSampledLight && !allowSampledLightEmission)
                return {0, 0, 0};
            return emitted;
        }

        if(closestHit.material.metal) {
            Vec3 incoming=unit(ray.direction);
            Vec3 reflected=incoming-closestHit.normal*(2*dot(incoming,closestHit.normal));
            return closestHit.material.color* trace({origin, reflected}, depth-1, true);
        }
        
        Vec3 direct{0, 0, 0};

        for (const auto& light : lights) {
            direct = direct+sampleDirectLightSphere(closestHit, *light);
        }

        Vec3 direction = closestHit.normal+randomUnit();
        if (dot(direction, direction) < 1e-10)
            direction = closestHit.normal;
        
        direction = unit(direction);
        //Vec3 indirect = closestHit.material.color*trace({origin, direction}, depth-1, false);
        return direct;
    }

    double reg_blend = 0.5*(unit(ray.direction).y+1);
    //Vec3 sky = Vec3{1,1,1}*(1-reg_blend)+Vec3{0.45,0.65,1}*reg_blend;


    return {0,0,0};
}

int main(int argc, char** argv) {
    SDL_Window* window=nullptr;
    SDL_Renderer* renderer=nullptr;
    SDL_Texture* texture=nullptr;
    int result=0;
    try {
        int width=argc>1?std::stoi(argv[1]):640;
        int samples=argc>2?std::stoi(argv[2]):256;
        bool autoClose=false;

        if(width<16 || width>4096 || samples<1 || samples>4096)
            throw std::runtime_error("Width must be 16..4096; samples must be 1..4096.");
        int height=width;
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
                    Vec3 value=trace({{0,0.45,2.6},
                        {(2*u-1)*0.5*double(width)/height,(2*v-1)*0.5,-1.0}},12,true,true);
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

