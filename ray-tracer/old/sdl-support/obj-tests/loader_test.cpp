#include <algorithm>
#include <cmath>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <vector>
struct Vec3 { double x,y,z; Vec3 operator+(Vec3 b)const{return{x+b.x,y+b.y,z+b.z};} Vec3 operator-(Vec3 b)const{return{x-b.x,y-b.y,z-b.z};} Vec3 operator*(double s)const{return{x*s,y*s,z*s};} };
double dot(Vec3 a,Vec3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
Vec3 cross(Vec3 a,Vec3 b){return{a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x};}
struct Material { Vec3 color; bool metal; Vec3 emission; };
struct Object { virtual ~Object()=default; };
struct Triangle : Object {Vec3 a,b,c; Triangle(Vec3 a,Vec3 b,Vec3 c,Material):a(a),b(b),c(c){} };
#include "../../src/obj_loader.h"
void require(bool ok){if(!ok)throw std::runtime_error("Test failed");}
int main(int argc,char**argv){
    try {
        if(argc!=2) return 2;
        auto cube=loadObj(argv[1],Material{},0.35,{1,-0.15,-1.2});
        require(cube.size()==12);
        double minY=1e9,maxY=-1e9;
        for(auto& obj:cube){auto t=std::dynamic_pointer_cast<Triangle>(obj); for(auto v:{t->a,t->b,t->c}){minY=std::min(minY,v.y); maxY=std::max(maxY,v.y);}}
        require(std::abs(minY+0.5)<1e-6 && std::abs(maxY-0.2)<1e-6);
        {std::ofstream f("fixture.obj"); f<<"v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\nf -4 -3 -2 -1\n";}
        require(loadObj("fixture.obj",Material{}).size()==2);
        {std::ofstream f("fixture.obj"); f<<"v 0 0 0\nv 1 0 0\nv 0 1 0\nf 1 2 99\n";}
        bool rejected=false; try{loadObj("fixture.obj",Material{});}catch(const std::exception&){rejected=true;} require(rejected);
        {std::ofstream f("fixture.obj"); f<<"v 0 0 0\nv 1 0 0\nv 2 0 0\nf 1 2 3\n";}
        rejected=false; try{loadObj("fixture.obj",Material{});}catch(const std::exception&){rejected=true;} require(rejected);
        std::cout<<"PASS: cube triangulation, transform, negative indices, invalid indices, degeneracy.\n";
    }catch(const std::exception&e){std::cerr<<e.what(); return 1;}
}
