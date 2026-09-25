#pragma once
#include "types_cuda.cuh"

// Object class to generalize cases. Does the ray hit the object? 
class Object{
public:
    __host__ __device__ Object() {}
    __device__ virtual bool intersect(const Ray& ray, HitProfile& hit) const = 0;
    __host__ __device__ virtual ~Object() {}
};

// Sphere is an object that inherits the interesction property. Here, we initialize the characteristics of the sphere.
// We then determine if the sphere will be hit by a ray or not. 
class Sphere : public Object {
public:
    Vec3 center;
    double radius;
    Material material;

    __host__ __device__
    Sphere(Vec3 c, double r, Material mat)
        : center(c), radius(r), material(mat) {}
    
    __host__ __device__
    ~Sphere() override {}

    __device__
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

    __host__ __device__
    Plane(Vec3 p, Vec3 v1, Vec3 v2, Material mat)
        : point(p), vec1(v1), vec2(v2), material(mat) {}
    
    __host__ __device__
    ~Plane() override {}

    __device__
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

    __host__ __device__
    Square(Vec3 p, Vec3 v1, Vec3 v2, Material mat)
        : point(p), vec1(v1), vec2(v2), material(mat) {}

    __host__ __device__
    ~Square() override {}

    __device__
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

    __host__ __device__
    Triangle(Vec3 p1, Vec3 p2, Vec3 p3, Material mat)
        : point1(p1), point2(p2), point3(p3), material(mat) {}

    __host__ __device__
    ~Triangle() override {}

    __device__
    bool intersect(const Ray& ray, HitProfile& hit) const override {
        Vec3 edge1 = point2 - point1;
        Vec3 edge2 = point3 - point1;
        Vec3 faceNormal = cross(edge1, edge2);
        if (dot(faceNormal, faceNormal) <= 1e-12) return false;
        Vec3 normal = unit(faceNormal);

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

