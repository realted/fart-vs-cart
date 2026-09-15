#pragma once

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