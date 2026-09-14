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

struct Vec3 {
    double x, y, z;
    Vec3 operator+(Vec3 v) const { return {x+v.x,y+v.y,z+v.z}; }
    Vec3 operator-(Vec3 v) const { return {x-v.x,y-v.y,z-v.z}; }
    Vec3 operator*(double s) const { return {x*s,y*s,z*s}; }
    Vec3 operator*(Vec3 v) const { return {x*v.x,y*v.y,z*v.z}; }
};
double dot(Vec3 a, Vec3 b) { return a.x*b.x+a.y*b.y+a.z*b.z; }
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
        if(lengthSquared>1e-12 && lengthSquared<1) return unit(v);
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

// Initialize objects
const std::vector<std::shared_ptr<Object>> objects = {
    std::make_shared<Sphere>(Vec3{0,0,-1.2},0.5,Material{Vec3{0.16,0.48,0.85},false,{0,0,0}}),
    std::make_shared<Sphere>(Vec3{-1.05,-0.05,-1.6},0.5,Material{Vec3{1,0.6,0},true,{0,0,0}}),
    std::make_shared<Sphere>(Vec3{0,-20.5,-1},20,Material{Vec3{0.65,0.68,0.72},false,{0,0,0}}),
    std::make_shared<Sphere>(Vec3{1,1.2,-1.2},0.5,Material{Vec3{1,1,1},false,{5,5,5}})
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
            if(dot(direction,direction)<1e-12) direction=closestHit.normal;
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
    try {
        const char* path=argc>1?argv[1]:"render.bmp";
        int width=argc>2?std::stoi(argv[2]):640;
        int samples=argc>3?std::stoi(argv[3]):32;
        if(width<16 || width>8192 || samples<1 || samples>4096)
            throw std::runtime_error("Width must be 16..8192 and samples 1..4096.");
        int height=width*9/16, stride=(width*3+3)&~3;
        std::ofstream out(path,std::ios::binary);
        if(!out) throw std::runtime_error("Cannot open output image.");
        out.write("BM",2); writeLE(out,54+stride*height,4); writeLE(out,0,4); writeLE(out,54,4);
        writeLE(out,40,4); writeLE(out,width,4); writeLE(out,height,4);
        writeLE(out,1,2); writeLE(out,24,2); writeLE(out,0,4); writeLE(out,stride*height,4);
        for(int i=0;i<4;++i) writeLE(out,0,4);
        auto channel=[](double c) { return static_cast<unsigned char>(256*std::clamp(std::sqrt(c),0.0,0.999)); };
        for(int y=0;y<height;++y) {
            for(int x=0;x<width;++x) {
                Vec3 color{0,0,0};
                for(int s=0;s<samples;++s) {
                    double u=(x+random01())/width, v=(y+random01())/height;
                    color=color+trace({{0,0.35,1.3},{(2*u-1)*double(width)/height,(2*v-1)-0.15,-2.3}},12);
                }
                color=color*(1.0/samples);
                out.put(channel(color.z)); out.put(channel(color.y)); out.put(channel(color.x));
            }
            for(int p=width*3;p<stride;++p) out.put(0);
        }
        out.close();
        if(!out) throw std::runtime_error("Failed writing image.");
        std::cout<<"Rendered "<<width<<"x"<<height<<" at "<<samples<<" samples/pixel to "<<path<<'\n';
    } catch(const std::exception& error) { std::cerr<<error.what()<<'\n'; return 1; }
}