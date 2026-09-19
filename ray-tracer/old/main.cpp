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
const std::string modelPath = R"(C:\Users\Ted\Desktop\y4proj\fart_vs_cart\ray-tracer\models\bewear.obj)";
const double modelScale = 0.006;
const Vec3 modelPosition = {1.3, -0.49, -2.5};
const Material modelMaterial = {{0.8, 0.2, 0.5}, false, {0, 0, 0}};

auto light1 = std::make_shared<Sphere>(
    Vec3{1, 1.2, -1.2}, 0.5,
    Material{{1, 1, 1}, false, {10, 10, 10}}
);

auto light2 = std::make_shared<Sphere>(
    Vec3{-2, 1.5, -2}, 0.3,
    Material{{1, 1, 1}, false, {8, 3, 1}}
);

std::vector<std::shared_ptr<Sphere>> lights = {
    light1, light2
};

// Initialize objects
std::vector<std::shared_ptr<Object>> objects = {
    std::make_shared<Sphere>(Vec3{0,0,-1.2},0.5,Material{Vec3{0.16,0.48,0.85},false,{0,0,0}}),
    std::make_shared<Sphere>(Vec3{-1.05,-0.05,-1.6},0.5,Material{Vec3{1,0.6,0},true,{0,0,0}}),
    light1,
    light2,
    //std::make_shared<Sphere>(Vec3{0,-20.5,-1},20,Material{Vec3{0.65,0.68,0.72},false,{0,0,0}}),
    std::make_shared<Plane>(Vec3{0,-0.5,0},Vec3{1,0,0},Vec3{0,0,1},Material{Vec3{0.1,0.78,0.2},false,{0,0,0}}),
    //std::make_shared<Triangle>(Vec3{0.4,-0.3,-0.3},Vec3{1.0,-0.3,-0.3},Vec3{0.7,0.4,-0.3},Material{Vec3{0.8,0.2,0.5},false,{0,0,0}}),
    //std::make_shared<Sphere>(Vec3{1,1.2,-1.2},0.5,Material{Vec3{1,1,1},false,{10,10,10}})
};

Vec3 sampleDirectLightSphere(const HitProfile& hit, const Sphere& light) {
    constexpr double pi = 3.141592653589793;
    constexpr double epsilon = 0.001;

    // Uniformly sample the sphere's entire surface.
    Vec3 lightNormal = randomUnit();
    Vec3 lightPoint =
        light.center + lightNormal * light.radius;

    Vec3 toLight = lightPoint - hit.hitPoint;
    double distanceSquared = dot(toLight, toLight);

    if (distanceSquared <= epsilon * epsilon)
        return {0, 0, 0};

    Vec3 lightDir = toLight * (1.0 / std::sqrt(distanceSquared));

    double surfaceCos = std::max(0.0, dot(hit.normal, lightDir));
    double lightCos = std::max(
        0.0, dot(lightNormal, lightDir * -1.0)
    );

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
        shadowVector * (1.0 / shadowDistance)
    };

    for (const auto& object : objects) {
        HitProfile blocker{};

        if (object->intersect(shadowRay, blocker) &&
            blocker.dst < shadowDistance - epsilon) {
            return {0, 0, 0};
        }
    }

    double area = 4.0 * pi
        * light.radius * light.radius;

    double weight =
        area * surfaceCos * lightCos / (pi * distanceSquared);

    return hit.material.color * light.material.emission * weight;
}

Vec3 sphereHalo(const Ray& ray) {
    const double softness = 0.20; // Halo width relative to apparent radius.
    const double strength = 1.0;

    Vec3 result{0, 0, 0};
    Vec3 direction = unit(ray.direction);

    for (const auto& light : lights) {
        Vec3 toCenter = light->center - ray.origin;
        double distance = std::sqrt(dot(toCenter, toCenter));

        if (light->radius <= 0 || distance <= light->radius)
            continue;

        Vec3 centerDirection = toCenter * (1.0 / distance);
        double alignment = dot(direction, centerDirection);

        if (alignment <= 0)
            continue; // Light is behind this ray.

        // Angular distance from the light's center.
        double angle = std::acos(
            std::clamp(alignment, -1.0, 1.0)
        );

        // Apparent angular radius of the actual sphere.
        double angularRadius = std::asin(
            std::clamp(light->radius / distance, 0.0, 1.0)
        );

        double outsideEdge = std::max(0.0, angle - angularRadius);
        double haloWidth = std::max(angularRadius * softness, 1e-6);
        double t = outsideEdge / haloWidth;

        // Smooth fade beyond the sphere's edge.
        double fade = std::exp(-0.5 * t * t);

        result = result
            + light->material.emission * (strength * fade);
    }

    return result;
}

// Trace function acts as the main logic for how rays behave.
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
        Vec3 origin = closestHit.hitPoint + closestHit.normal * epsilon;
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
            return closestHit.material.color* trace({origin, reflected}, depth - 1, true);
        }
        
        Vec3 direct{0, 0, 0};

        for (const auto& light : lights) {
            direct = direct + sampleDirectLightSphere(closestHit, *light);
        }

        Vec3 direction = closestHit.normal + randomUnit();
        if (dot(direction, direction) < 1e-10)
            direction = closestHit.normal;
        
        direction = unit(direction);
        Vec3 indirect = closestHit.material.color
            * trace({origin, direction}, depth - 1, false);
        return direct+indirect;
    }

    double reg_blend=0.5*(unit(ray.direction).y+1);
    Vec3 sky = Vec3{1,1,1}*(1-reg_blend)+Vec3{0.45,0.65,1}*reg_blend;


    return cameraRay ? sky + sphereHalo(ray) : sky;
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
        auto mesh=loadObj(objPath,modelMaterial,objScale,objPosition);
        objects.insert(objects.end(),mesh.begin(),mesh.end());
        
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
                        {(2*u-1)*double(width)/height,(2*v-1)-0.15,-2.3}},12,true,true);
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

