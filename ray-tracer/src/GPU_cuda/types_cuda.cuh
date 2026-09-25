#pragma once

#include <cuda_runtime.h>
#include <cmath>

struct Vec3 {
    double x, y, z;
    __host__ __device__ Vec3 operator+(Vec3 v) const { return {x+v.x,y+v.y,z+v.z}; }
    __host__ __device__ Vec3 operator*(double s) const { return {x*s,y*s,z*s}; }
    __host__ __device__ Vec3 operator-(Vec3 v) const { return {x-v.x,y-v.y,z-v.z}; }
    __host__ __device__ Vec3 operator*(Vec3 v) const { return {x*v.x,y*v.y,z*v.z}; }
};
__host__ __device__ inline double dot(Vec3 a, Vec3 b) { return a.x*b.x+a.y*b.y+a.z*b.z; }
__host__ __device__ inline Vec3 cross(Vec3 a, Vec3 b) { return {a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x}; }
__host__ __device__ inline Vec3 unit(Vec3 v) { return v*(1/std::sqrt(dot(v,v))); }

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
