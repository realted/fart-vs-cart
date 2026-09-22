#include "sdl_header.hpp"
#include "objects_cuda.cuh"
#include <cuda_runtime.h>
#include <algorithm>
#include <limits>
#include <stdexcept>
#include <vector>

// Plain descriptions cross from CPU to GPU; polymorphic objects do not.
enum class ObjectType { Sphere, Square, Plane, Triangle };
struct ObjectDesc {
    ObjectType type;
    Material material;
    Vec3 position{};       // Sphere center, square corner, or point on plane.
    double radius{};      // Sphere.
    Vec3 edgeU{}, edgeV{}; // Square edges or directions spanning a plane.
    Vec3 a{}, b{}, c{};    // Triangle vertices.
};

namespace {
void check(cudaError_t result) {
    if (result != cudaSuccess) throw std::runtime_error(cudaGetErrorString(result));
}

// CPU ownership handles and device globals used by trace().
Object** d_objects = nullptr;
int objectCount = 0;
__device__ Object** sceneObjects = nullptr;
__device__ int sceneObjectCount = 0;

// Edit the scene here on the CPU, not inside the pixel kernel.
std::vector<ObjectDesc> makeScene() {
    std::vector<ObjectDesc> scene;

    const Material pink{{0.75, 0.18, 0.35}, false, {0, 0, 0}};
    const Material dark{{0.035, 0.025, 0.03}, false, {0, 0, 0}};
    const Material cream{{0.80, 0.72, 0.62}, false, {0, 0, 0}};
    const Material lightdark{{0.14, 0.14, 0.14}, false, {0, 0, 0}};

    auto addSquare = [&](Vec3 corner, Vec3 edgeU,
                         Vec3 edgeV, Material material) {
        ObjectDesc square{};
        square.type = ObjectType::Square;
        square.material = material;
        square.position = corner;
        square.edgeU = edgeU;
        square.edgeV = edgeV;
        scene.push_back(square);
    };

    // Left wall.
    addSquare(
        {-1.3, -0.5, -4},
        {0, 1.9, 0}, {0, 0, 4},
        pink
    );

    // Right wall.
    addSquare(
        {1.3, -0.5, -4},
        {0, 1.9, 0}, {0, 0, 4},
        pink
    );

    // Back wall.
    addSquare(
        {-1.3, -0.5, -4},
        {2.6, 0, 0}, {0, 1.9, 0},
        dark
    );

    // Ceiling.
    addSquare(
        {-1.3, 1.4, -4},
        {2.6, 0, 0}, {0, 0, 4},
        cream
    );

    // Floor.
    addSquare(
        {-1.3, -0.5, -4},
        {2.6, 0, 0}, {0, 0, 4},
        lightdark
    );

    // Metallic sphere.
    ObjectDesc sphere{};
    sphere.type = ObjectType::Sphere;
    sphere.material = Material{{0.5, 0.5, 0.5}, true, {0, 0, 0}};
    sphere.position = {0.0, 0.0, -1.225};
    sphere.radius = 0.5;
    scene.push_back(sphere);

    // Pink panel behind the camera.
    addSquare(
        {-2.0, 0.2, 3.2},
        {4.0, 0, 0}, {0, 1.6, 0},
        pink
    );

    return scene;
}

__global__ void initializeObjects(const ObjectDesc* descriptions,
                                  Object** objects, int count, int* failed) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= count) return;
    const ObjectDesc& d = descriptions[i];
    Object* object = nullptr;
    switch (d.type) {
    case ObjectType::Sphere:
        object = new Sphere(d.position, d.radius, d.material);
        break;
    case ObjectType::Square:
        object = new Square(d.position, d.edgeU, d.edgeV, d.material);
        break;
    case ObjectType::Plane:
        object = new Plane(d.position, d.edgeU, d.edgeV, d.material);
        break;
    case ObjectType::Triangle:
        object = new Triangle(d.a, d.b, d.c, d.material);
        break;
    }
    objects[i] = object;
    if (!object) atomicExch(failed, 1);
}

__global__ void deleteObjects(Object** objects, int count) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < count) {
        delete objects[i]; // GPU virtual destructor.
        objects[i] = nullptr;
    }
}

__device__ Vec3 trace(Ray ray, int depth) {
    if (depth <= 0) return {0, 0, 0};
    double nearest = 1e30;
    HitProfile closestHit{};
    bool didHit = false;
    for (int i = 0; i < sceneObjectCount; ++i) {
        HitProfile hit{};
        if (sceneObjects[i]->intersect(ray, hit) && hit.dst < nearest) {
            nearest = hit.dst;
            closestHit = hit;
            didHit = true;
        }
    }
    // Flat color only; depth will limit bounces when they are added.
    return didHit ? closestHit.material.color : Vec3{0, 0, 0};
}

__device__ unsigned char channel(double value) {
    if (!isfinite(value) || value <= 0.0) return 0;
    return static_cast<unsigned char>(255.0 * fmin(value, 1.0));
}

__global__ void genIm(unsigned char* pixels, int width, int height) {
    int x = blockIdx.x * blockDim.x + threadIdx.x;
    int y = blockIdx.y * blockDim.y + threadIdx.y;
    if (x >= width || y >= height) return;
    double u = (x + 0.5) / width;
    double v = 1.0 - (y + 0.5) / height;
    Ray ray{{0, 0.45, 2.6},
            {(2*u-1)*0.5*double(width)/height, (2*v-1)*0.5, -1.0}};
    Vec3 color = trace(ray, 12);
    size_t i = 3 * (size_t(y) * width + x);
    pixels[i] = channel(color.x);
    pixels[i+1] = channel(color.y);
    pixels[i+2] = channel(color.z);
}
} // namespace

// Once before rendering. Repeated calls keep the existing scene.
void initializeScene() {
    if (d_objects) return;
    const auto descriptions = makeScene();
    if (descriptions.empty() || descriptions.size() > size_t(std::numeric_limits<int>::max()))
        throw std::runtime_error("Scene must contain a valid number of objects");
    const int count = static_cast<int>(descriptions.size());
    const size_t largest = std::max({sizeof(Sphere), sizeof(Square), sizeof(Plane), sizeof(Triangle)});
    size_t heapSize = 0;
    check(cudaDeviceGetLimit(&heapSize, cudaLimitMallocHeapSize));
    const size_t requiredHeap = std::max(size_t(8)*1024*1024, size_t(count)*(largest+128)*2);
    if (heapSize < requiredHeap)
        check(cudaDeviceSetLimit(cudaLimitMallocHeapSize, requiredHeap));

    ObjectDesc* d_descriptions = nullptr;
    int* d_failed = nullptr;
    Object** objects = nullptr;
    bool constructionStarted = false;
    try {
        check(cudaMalloc(reinterpret_cast<void**>(&d_descriptions), count*sizeof(ObjectDesc)));
        check(cudaMalloc(reinterpret_cast<void**>(&objects), count*sizeof(Object*)));
        check(cudaMemset(objects, 0, count*sizeof(Object*)));
        check(cudaMalloc(reinterpret_cast<void**>(&d_failed), sizeof(int)));
        check(cudaMemset(d_failed, 0, sizeof(int)));
        check(cudaMemcpy(d_descriptions, descriptions.data(), count*sizeof(ObjectDesc), cudaMemcpyHostToDevice));
        initializeObjects<<<(count+127)/128, 128>>>(d_descriptions, objects, count, d_failed);
        check(cudaGetLastError());
        constructionStarted = true;
        check(cudaDeviceSynchronize());
        int failed = 0;
        check(cudaMemcpy(&failed, d_failed, sizeof(int), cudaMemcpyDeviceToHost));
        if (failed) throw std::runtime_error("GPU object construction failed (device heap or object type)");
        check(cudaMemcpyToSymbol(sceneObjects, &objects, sizeof(objects)));
        check(cudaMemcpyToSymbol(sceneObjectCount, &count, sizeof(count)));
    } catch (...) {
        if (constructionStarted) {
            deleteObjects<<<(count+127)/128, 128>>>(objects, count);
            cudaDeviceSynchronize();
        }
        Object** empty = nullptr;
        int zero = 0;
        cudaMemcpyToSymbol(sceneObjects, &empty, sizeof(empty));
        cudaMemcpyToSymbol(sceneObjectCount, &zero, sizeof(zero));
        cudaFree(objects);
        cudaFree(d_descriptions);
        cudaFree(d_failed);
        throw;
    }
    d_objects = objects;
    objectCount = count;
    const cudaError_t descResult = cudaFree(d_descriptions);
    const cudaError_t flagResult = cudaFree(d_failed);
    check(descResult);
    check(flagResult);
}

void renderCudaImage(unsigned char* cpuPixels, int width, int height) {
    if (!d_objects) throw std::runtime_error("Call initializeScene() before rendering");
    if (!cpuPixels || width < 2 || height < 2 ||
        size_t(width) > std::numeric_limits<size_t>::max()/size_t(height)/3)
        throw std::runtime_error("Invalid image buffer or dimensions");
    size_t bytes = size_t(width)*height*3;
    unsigned char* gpuPixels = nullptr;
    check(cudaMalloc(reinterpret_cast<void**>(&gpuPixels), bytes));
    try {
        dim3 threads(16,16);
        dim3 blocks((unsigned(width)+15)/16, (unsigned(height)+15)/16);
        genIm<<<blocks,threads>>>(gpuPixels,width,height);
        check(cudaGetLastError());
        check(cudaDeviceSynchronize());
        check(cudaMemcpy(cpuPixels,gpuPixels,bytes,cudaMemcpyDeviceToHost));
    } catch (...) {
        cudaFree(gpuPixels);
        throw;
    }
    check(cudaFree(gpuPixels));
}

// Attempt all cleanup operations, then report the first error.
void destroyScene() {
    if (!d_objects) return;
    cudaError_t firstError = cudaSuccess;
    auto record = [&](cudaError_t result) {
        if (firstError == cudaSuccess) firstError = result;
    };
    deleteObjects<<<(objectCount+127)/128, 128>>>(d_objects, objectCount);
    record(cudaGetLastError());
    record(cudaDeviceSynchronize());
    Object** empty = nullptr;
    int zero = 0;
    record(cudaMemcpyToSymbol(sceneObjects, &empty, sizeof(empty)));
    record(cudaMemcpyToSymbol(sceneObjectCount, &zero, sizeof(zero)));
    record(cudaFree(d_objects));
    d_objects = nullptr;
    objectCount = 0;
    check(firstError);
}
