#include <algorithm>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <random>
#include <stdexcept>
#include <vector>

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
struct Sphere { Vec3 center; double radius; Vec3 color; bool metal; };
const std::vector<Sphere> scene = {
    {{0,-100.5,-1},100,{0.65,0.68,0.72},false},
    {{0,0,-1.2},0.5,{0.16,0.48,0.85},true},
    {{-1.05,0,-1.6},0.5,{0.85,0.3,0.16},false},
    {{1.05,0,-1.4},0.5,{0.86,0.8,0.65},false}
};
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
Vec3 trace(Ray ray, int depth) {
    if(depth==0) return {0,0,0};
    double nearest=std::numeric_limits<double>::infinity();
    const Sphere* hit=nullptr;
    for(const auto& sphere: scene) {
        Vec3 offset=ray.origin-sphere.center;
        double a=dot(ray.direction,ray.direction), halfB=dot(offset,ray.direction);
        double c=dot(offset,offset)-sphere.radius*sphere.radius;
        double discriminant=halfB*halfB-a*c;
        if(discriminant<0) continue;
        double t=(-halfB-std::sqrt(discriminant))/a;
        if(t<=0.001) t=(-halfB+std::sqrt(discriminant))/a;
        if(t>0.001 && t<nearest) { nearest=t; hit=&sphere; }
    }
    if(hit) {
        Vec3 point=ray.origin+ray.direction*nearest;
        Vec3 normal=(point-hit->center)*(1/hit->radius);
        Vec3 direction;
        if(hit->metal) {
            Vec3 incoming=unit(ray.direction);
            direction=incoming-normal*(2*dot(incoming,normal));
        } else {
            direction=normal+randomUnit();
            if(dot(direction,direction)<1e-12) direction=normal;
        }
        return hit->color*trace({point,direction},depth-1);
    }
    double blend=0.5*(unit(ray.direction).y+1);
    return Vec3{1,1,1}*(1-blend)+Vec3{0.45,0.65,1}*blend;
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
