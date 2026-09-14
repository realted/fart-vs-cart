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

struct Vec3 {
    double x, y, z;
    Vec3 operator+(Vec3 v) const { return {x+v.x,y+v.y,z+v.z}; }
    Vec3 operator-(Vec3 v) const { return {x-v.x,y-v.y,z-v.z}; }
    Vec3 operator*(double s) const { return {x*s,y*s,z*s}; }
    Vec3 operator*(Vec3 v) const { return {x*v.x,y*v.y,z*v.z}; }
};
double dot(Vec3 a, Vec3 b) { return a.x*b.x+a.y*b.y+a.z*b.z; }
Vec3 cross(Vec3 a, Vec3 b) { return {a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x}; }
Vec3 unit(Vec3 v) { return v*(1/std::sqrt(dot(v,v))); }
struct Ray { Vec3 origin, direction; };

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

struct Material {
    Vec3 color;
    bool metal;
    Vec3 emission;
};

// Create a profile for every object. The information about how the ray hit the object.
struct HitProfile {
    double dst;
    Vec3 hitPoint;
    Vec3 normal;
    Material material;
};

// Object class to generalize cases. Does the ray hit the object? 
class Object{
public:
    virtual bool intersect(const Ray& ray, HitProfile& hit) const = 0;
    virtual ~Object() = default;
};

// Sphere is an object that inherits the interesction property. Here, we initialize the characteristics of the sphere.
// We then determine if the sphere will be hit by a ray or not. 
class Sphere : public Object {
public:
    Vec3 center;
    double radius;
    Material material;

    Sphere(Vec3 c, double r, Material mat)
        : center(c), radius(r), material(mat) {}

    bool intersect(const Ray& ray, HitProfile& hit) const override {
        Vec3 offset = ray.origin - center;
        double a=dot(ray.direction,ray.direction), halfB=dot(offset,ray.direction);
        double c=dot(offset,offset)-radius*radius;
        double discriminant=halfB*halfB-a*c;

        // The discriminant between a line and a sphere is a quadratic. Discriminant less than zero means no real solutions. (i.e. does not intersect)
        if (discriminant < 0){
            return false;
        }

        double dst=(-halfB-std::sqrt(discriminant))/a;

        if(dst<=0.001) dst=(-halfB+std::sqrt(discriminant))/a;
        if (dst<=0.001){
            return false;
        }

        // Fill the properties of the sphere
        hit.dst = dst;
        hit.hitPoint = ray.origin + ray.direction * dst;
        hit.normal = (hit.hitPoint - center) * (1.0 / radius);
        hit.material.color = material.color;
        hit.material.metal = material.metal;
        hit.material.emission = material.emission;

        return true;
    }
};

class Plane : public Object {
public:
    Vec3 point;
    Vec3 vec1;
    Vec3 vec2;
    Material material;

    Plane(Vec3 p, Vec3 v1, Vec3 v2, Material mat)
        : point(p), vec1(v1), vec2(v2), material(mat) {}

    bool intersect(const Ray& ray, HitProfile& hit) const override {

        // Calculate unit normal to the plane
        Vec3 normal = unit(cross(vec1, vec2));

        double denominator = dot(normal, ray.direction);
        

        // If ray direction is perpendicular to the normal,
        // the ray is parallel to the plane
        if (std::abs(denominator) < 0.001) {
            return false;
        }

        // Solve for ray parameter t:
        // ray.origin + t * ray.direction lies on the plane
        double t = dot(normal, point - ray.origin) / denominator;

        // Intersection is behind the ray or too close to its origin
        if (t <= 0.001) {
            return false;
        }

        hit.dst = t;
        hit.hitPoint = ray.origin + ray.direction * t;
        hit.normal = denominator < 0 ? normal : normal * -1.0;
        hit.material.color = material.color;
        hit.material.metal = material.metal;
        hit.material.emission = material.emission;

        return true;
    }
};

class Square : public Object {
public:
    Vec3 point;
    Vec3 vec1;
    Vec3 vec2;
    Material material;

    Square(Vec3 p, Vec3 v1, Vec3 v2, Material mat)
        : point(p), vec1(v1), vec2(v2), material(mat) {}

    bool intersect(const Ray& ray, HitProfile& hit) const override {

        // Calculate unit normal to the plane
        Vec3 normal = unit(cross(vec2, vec1));

        double denominator = dot(normal, ray.direction);

        // If ray direction is perpendicular to the normal,
        // the ray is parallel to the plane
        if (std::abs(denominator) < 0.001) {
            return false;
        }

        double t = dot(normal, point - ray.origin) / denominator;

        if (t <= 0.001) {
            return false;
        }

        Vec3 hitPoint = ray.origin + ray.direction * t;

        // Here, perform a change of basis into a 1x1 rectange to determine if the ray hits the square region or not.
        Vec3 relative = hitPoint - point;
        double u = dot(relative, vec1) / dot(vec1, vec1);
        double v = dot(relative, vec2) / dot(vec2, vec2);

        if (u < 0 || u > 1 || v < 0 || v > 1)
            return false;

        hit.dst = t;
        hit.hitPoint = hitPoint;
        hit.normal = denominator < 0 ? normal : normal * -1.0;
        hit.material.color = material.color;
        hit.material.metal = material.metal;
        hit.material.emission = material.emission;

        return true;
    }
};

class Triangle : public Object {
public:
    Vec3 point1;
    Vec3 point2;
    Vec3 point3;
    Material material;

    Triangle(Vec3 p1, Vec3 p2, Vec3 p3, Material mat)
        : point1(p1), point2(p2), point3(p3), material(mat) {}

    bool intersect(const Ray& ray, HitProfile& hit) const override {
        Vec3 edge1 = point2 - point1;
        Vec3 edge2 = point3 - point1;
        Vec3 normal = unit(cross(edge1, edge2));

        double denominator = dot(normal, ray.direction);

        if (std::abs(denominator) < 0.001) {
            return false;
        }

        double t = dot(normal, point1 - ray.origin) / denominator;

        if (t <= 0.001) {
            return false;
        }

        Vec3 hitPoint = ray.origin + ray.direction * t;
        Vec3 relative = hitPoint - point1;
        
        // Change of basis is a bit more involved as the two edge vectors are not expected to be orthogonal
        double d00 = dot(edge1, edge1);
        double d01 = dot(edge1, edge2);
        double d11 = dot(edge2, edge2);

        double d20 = dot(relative, edge1);
        double d21 = dot(relative, edge2);

        double dz = d00 * d11 - d01 * d01;
        if (dz <= 1e-12)
            return false;

        double u = (d11 * d20 - d01 * d21) / dz;
        double v = (d00 * d21 - d01 * d20) / dz;

        if (u < 0 || v < 0 || u + v > 1)
           return false;

        hit.dst = t;
        hit.hitPoint = hitPoint;
        hit.normal  = denominator < 0 ? normal : normal * -1.0;
        hit.material.color = material.color;
        hit.material.metal = material.metal;
        hit.material.emission = material.emission;

        return true;
    }
};

// Initialize objects
const std::vector<std::shared_ptr<Object>> objects = {
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
    HitProfile closestHit;
    for (const auto& object : objects) {
        HitProfile tempHit;

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

void writeLE(std::ostream& out, std::uint32_t value, int bytes) {
    for(int i=0;i<bytes;++i) out.put(static_cast<char>((value>>(8*i))&255));
}


int main(int argc, char** argv) {
    SDL_Window* window=nullptr;
    SDL_Renderer* renderer=nullptr;
    SDL_Texture* texture=nullptr;
    int result=0;
    try {
        int width=argc>1?std::stoi(argv[1]):640;
        int samples=argc>2?std::stoi(argv[2]):64;
        bool autoClose=argc>3 && std::string(argv[3])=="--auto-close";
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

