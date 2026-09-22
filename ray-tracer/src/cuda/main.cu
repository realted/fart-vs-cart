#include "sdl_header.hpp"
#include "objects_cuda.cuh"
#include <cuda_runtime.h>
#include <curand_kernel.h> 
#include <algorithm>
#include <limits>
#include <stdexcept>
#include <vector>

// Plain descriptions cross from CPU to GPU; polymorphic objects do not.
enum class ObjectType
{
    Sphere,
    Square,
    Plane,
    Triangle
};
struct ObjectDesc
{
    ObjectType type;
    Material material;
    Vec3 position{};       // Sphere center, square corner, or point on plane.
    double radius{};       // Sphere.
    Vec3 edgeU{}, edgeV{}; // Square edges or directions spanning a plane.
    Vec3 a{}, b{}, c{};    // Triangle vertices.
};

namespace{
    void check(cudaError_t result)
    {
        if (result != cudaSuccess)
            throw std::runtime_error(cudaGetErrorString(result));
    }

    using RandomState = curandStatePhilox4_32_10_t;

    // CPU variable holding the GPU allocation's address.
    Object **d_objects = nullptr;
    Sphere **d_lights = nullptr;
    RandomState* d_randomStates = nullptr;
    int objectCount = 0;
    int lightCount = 0;

    // GPU globals used by trace().
    __device__ Object **sceneObjects = nullptr;
    __device__ int sceneObjectCount = 0;
    __device__ Sphere **sceneLights = nullptr;
    __device__ int sceneLightCount = 0;
    __device__ RandomState* randomStates = nullptr;
    __device__ int randomImageWidth = 0;

    // Edit the scene here on the CPU, not inside the pixel kernel.
    std::vector<ObjectDesc> makeScene()
    {
        std::vector<ObjectDesc> scene;

        const Material pink{{0.75, 0.18, 0.35}, false, {0, 0, 0}};
        const Material dark{{0.035, 0.025, 0.03}, false, {0, 0, 0}};
        const Material cream{{0.80, 0.72, 0.62}, false, {0, 0, 0}};
        const Material lightdark{{0.14, 0.14, 0.14}, false, {0, 0, 0}};

        auto addSquare = [&](Vec3 corner, Vec3 edgeU,
                             Vec3 edgeV, Material material)
        {
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
            pink);

        // Right wall.
        addSquare(
            {1.3, -0.5, -4},
            {0, 1.9, 0}, {0, 0, 4},
            pink);

        // Back wall.
        addSquare(
            {-1.3, -0.5, -4},
            {2.6, 0, 0}, {0, 1.9, 0},
            dark);

        // Ceiling.
        addSquare(
            {-1.3, 1.4, -4},
            {2.6, 0, 0}, {0, 0, 4},
            cream);

        // Floor.
        addSquare(
            {-1.3, -0.5, -4},
            {2.6, 0, 0}, {0, 0, 4},
            lightdark);

        // Metallic sphere.
        ObjectDesc sphere{};
        sphere.type = ObjectType::Sphere;
        sphere.material = Material{{0.5, 0.5, 0.5}, true, {0, 0, 0}};
        sphere.position = {0.0, 0.0, -1.225};
        sphere.radius = 0.5;
        scene.push_back(sphere);

        // Metallic sphere.
        ObjectDesc light1{};
        sphere.type = ObjectType::Sphere;
        sphere.material = Material{{1, 1, 1}, false, {10, 10, 10}};
        sphere.position = {0.0, 1.35, -0.7};
        sphere.radius = 0.25;
        scene.push_back(sphere);

        // Pink panel behind the camera.
        addSquare(
            {-2.0, 0.2, 3.2},
            {4.0, 0, 0}, {0, 1.6, 0},
            pink);

        return scene;
    }

    __global__ void initializeObjects(const ObjectDesc *descriptions, Object **objects, int count, int *failed)
    {
        int i = blockIdx.x * blockDim.x + threadIdx.x;
        if (i >= count)
            return;
        const ObjectDesc &d = descriptions[i];
        Object *object = nullptr;
        switch (d.type)
        {
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
        if (!object)
            atomicExch(failed, 1);
    }
    
    __global__ void initializeSphereLights(const ObjectDesc* descriptions, Object** objects, int count, Sphere** lights) {
    // Scene initialization happens once; one thread keeps this simple
    // and preserves scene order without an atomic counter.
    if (blockIdx.x != 0 || threadIdx.x != 0)
        return;

    int lightIndex = 0;

    for (int i = 0; i < count; ++i) {
        const ObjectDesc& d = descriptions[i];

        if (d.type == ObjectType::Sphere &&
            dot(d.material.emission, d.material.emission) > 0.0)
        {
            lights[lightIndex++] =
                static_cast<Sphere*>(objects[i]);
        }
    }
    }

    __global__ void deleteObjects(Object **objects, int count)
    {
        int i = blockIdx.x * blockDim.x + threadIdx.x;
        if (i < count)
        {
            delete objects[i]; // GPU virtual destructor.
            objects[i] = nullptr;
        }
    }

    __global__
    void initializeRandomStates(
        RandomState* states,
        int width,
        int height,
        unsigned long long seed)
    {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;

        if (x >= width || y >= height)
            return;

        size_t index = size_t(y) * width + x;

        curand_init(
            seed,                        // Reproducible starting seed.
            static_cast<unsigned long long>(index), // Pixel's subsequence.
            0,                           // Starting offset.
            &states[index]               // State to initialize.
        );
    }

    __device__
    double random01()
    {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;

        size_t index = size_t(y) * randomImageWidth + x;

        // cuRAND returns (0, 1]; subtracting from 1 gives [0, 1).
        return 1.0 - curand_uniform_double(&randomStates[index]);
    }

    __device__
    Vec3 randomUnit() {
    for (;;) {
        Vec3 v{2*random01()-1,2*random01()-1,2*random01()-1};
        double lengthSquared=dot(v,v);
        if(lengthSquared>1e-10 && lengthSquared<1) return unit(v);
    }
    }   

    __device__
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
    Vec3 lightDir = toLight*(1.0 / sqrt(distanceSquared));
    double surfaceCos = fmax(0.0, dot(hit.normal, lightDir));
    double lightCos = fmax(0.0, dot(lightNormal, lightDir * -1.0));

    // Reject directions below the surface and the light's far side.
    if (surfaceCos <= 0 || lightCos <= 0)
        return {0, 0, 0};

    // Aim from the offset origin toward the sampled endpoint.
    Vec3 origin = hit.hitPoint + hit.normal * epsilon;
    Vec3 shadowVector = lightPoint - origin;
    double shadowDistance = sqrt(dot(shadowVector, shadowVector));

    if (shadowDistance <= epsilon)
        return {0, 0, 0};

    Ray shadowRay{origin,shadowVector*(1.0/shadowDistance)};

    // Check if anything is blocking the sampled light point
     for (int i = 0; i < sceneObjectCount; ++i){
        HitProfile blocker{};
        if (sceneObjects[i]->intersect(shadowRay, blocker) &&
            blocker.dst < shadowDistance - epsilon) {
            return {0, 0, 0};
        }
    }

    double area = 4.0*pi*light.radius*light.radius;
    double weight = area*surfaceCos*lightCos/(pi*distanceSquared);
    return hit.material.color*light.material.emission*weight;
}

    __device__ Vec3 trace(Ray ray, int depth, bool allowSampledLightEmission=true){
        if (depth <= 0)
            return {0, 0, 0};
        double nearest = 1e30;
        HitProfile closestHit{};
        const Object* closestObject = nullptr;
        bool didHit = false;
        for (int i = 0; i < sceneObjectCount; ++i)
        {
            HitProfile hit{};
            if (sceneObjects[i]->intersect(ray, hit) && hit.dst < nearest)
            {
                nearest = hit.dst;
                closestHit = hit;
                closestObject = sceneObjects[i];
                didHit = true;
            }
        }
        if(didHit) {
        constexpr double epsilon = 0.001;
        Vec3 origin = closestHit.hitPoint+closestHit.normal*epsilon;
        Vec3 emitted = closestHit.material.emission;

        bool isSampledLight = false;
        for (int i = 0; i < sceneLightCount; ++i) {
            if (sceneLights[i] == closestObject) {
                isSampledLight = true;
                break;
            }
        }

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

        for (int i = 0; i < sceneLightCount; ++i) {
            direct = direct + sampleDirectLightSphere(closestHit, *sceneLights[i]);
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

    __device__ unsigned char channel(double value)
    {
        if (!isfinite(value) || value <= 0.0)
            return 0;
        return static_cast<unsigned char>(255.0 * fmin(value, 1.0));
    }

    __global__ void genIm(unsigned char *pixels, int width, int height) {
        int x = blockIdx.x * blockDim.x + threadIdx.x;
        int y = blockIdx.y * blockDim.y + threadIdx.y;
        if (x >= width || y >= height)
            return;
        double jitterX = random01();
        double jitterY = random01();
        double u = (x + jitterX) / width;
        double v = 1.0 - (y + jitterY) / height;
        Ray ray{{0, 0.45, 2.6},
                {(2 * u - 1) * 0.5 * double(width) / height, (2 * v - 1) * 0.5, -1.0}};
        Vec3 color = trace(ray, 12);
        size_t i = 3 * (size_t(y) * width + x);
        pixels[i] = channel(color.x);
        pixels[i + 1] = channel(color.y);
        pixels[i + 2] = channel(color.z);
    }
} // namespace

// Once before rendering. Repeated calls keep the existing scene.
void initializeScene(){
    // CPU loads the object descriptions and structs
    if (d_objects)
        return;
    // Recursive trace() needs additional per-thread GPU stack space.
    check(cudaDeviceSetLimit(cudaLimitStackSize, 16 * 1024));

    const auto descriptions = makeScene();
    if (descriptions.empty() || descriptions.size() > size_t(std::numeric_limits<int>::max()))
        throw std::runtime_error("Scene must contain a valid number of objects");
    const int count = static_cast<int>(descriptions.size());

    int numberOfLights = 0;

    for (const ObjectDesc& d : descriptions) {
        if (d.type == ObjectType::Sphere && dot(d.material.emission, d.material.emission) > 0.0) {
        ++numberOfLights;
        }   
    }

    // Compute the largest object size, and calculate size of heap to allocate to GPU
    const size_t largest = std::max({sizeof(Sphere), sizeof(Square), sizeof(Plane), sizeof(Triangle)});
    size_t heapSize = 0;
    check(cudaDeviceGetLimit(&heapSize, cudaLimitMallocHeapSize));
    const size_t requiredHeap = std::max(size_t(8) * 1024 * 1024, size_t(count) * (largest + 128) * 2);
    if (heapSize < requiredHeap)
        check(cudaDeviceSetLimit(cudaLimitMallocHeapSize, requiredHeap));

    // Pointers in CPU holding memory add of GPU
    ObjectDesc *d_descriptions = nullptr;
    int *d_failed = nullptr;
    Object **objects = nullptr;
    Sphere** lights = nullptr;
    bool constructionStarted = false;
    try
    {
        check(cudaMalloc(reinterpret_cast<void **>(&d_descriptions), count * sizeof(ObjectDesc))); // Allocate Object Profiles
        check(cudaMalloc(reinterpret_cast<void **>(&objects), count * sizeof(Object *)));          // Allocate pointer array
        check(cudaMemset(objects, 0, count * sizeof(Object *)));
        check(cudaMalloc(reinterpret_cast<void **>(&d_failed), sizeof(int)));
        check(cudaMemset(d_failed, 0, sizeof(int)));
        check(cudaMemcpy(d_descriptions, descriptions.data(), count * sizeof(ObjectDesc), cudaMemcpyHostToDevice)); // Copy CPU Desc to GPU for compute
        initializeObjects<<<(count + 127) / 128, 128>>>(d_descriptions, objects, count, d_failed);                  // GPU Compute
        check(cudaGetLastError());
        constructionStarted = true;
        check(cudaDeviceSynchronize());
        if (numberOfLights > 0) {
        check(cudaMalloc(
            reinterpret_cast<void**>(&lights),
            numberOfLights * sizeof(Sphere*)
        ));

        initializeSphereLights<<<1, 1>>>(
            d_descriptions, objects, count, lights
        );

        check(cudaGetLastError());
        check(cudaDeviceSynchronize());
        }

        int failed = 0;
        check(cudaMemcpy(&failed, d_failed, sizeof(int), cudaMemcpyDeviceToHost));
        if (failed)
            throw std::runtime_error("GPU object construction failed (device heap or object type)");
        check(cudaMemcpyToSymbol(sceneObjects, &objects, sizeof(objects)));
        check(cudaMemcpyToSymbol(sceneObjectCount, &count, sizeof(count)));
        check(cudaMemcpyToSymbol(sceneLights, &lights, sizeof(lights)));
        check(cudaMemcpyToSymbol(sceneLightCount, &numberOfLights, sizeof(numberOfLights)));
    }
    catch (...)
    {
        if (constructionStarted)
        {
            deleteObjects<<<(count + 127) / 128, 128>>>(objects, count);
            cudaDeviceSynchronize(); // Ensure construction is done before CPU proceeds
        }
        Object **empty = nullptr;
        Sphere** emptyLights = nullptr;
        int zero = 0;

        // Set GPU globals
        cudaMemcpyToSymbol(sceneObjects, &empty, sizeof(empty));
        cudaMemcpyToSymbol(sceneObjectCount, &zero, sizeof(zero));
        cudaMemcpyToSymbol(sceneLights, &emptyLights, sizeof(emptyLights));
        cudaMemcpyToSymbol(sceneLightCount, &zero, sizeof(zero));
        cudaFree(objects);
        cudaFree(d_descriptions);
        cudaFree(d_failed);
        cudaFree(lights);
        throw;
    }
    d_objects = objects;
    objectCount = count;
    d_lights = lights;
    lightCount = numberOfLights;    
    const cudaError_t descResult = cudaFree(d_descriptions);
    const cudaError_t flagResult = cudaFree(d_failed);
    check(descResult);
    check(flagResult);
}

void initializeRandom(int width, int height)
{
    if (width < 2 || height < 2)
        throw std::runtime_error("Invalid random-state dimensions");

    if (d_randomStates)
        throw std::runtime_error("Random states are already initialized");

    RandomState* states = nullptr;
    size_t count = size_t(width) * height;

    check(cudaMalloc(
        reinterpret_cast<void**>(&states),
        count * sizeof(RandomState)
    ));

    try {
        dim3 threads(16, 16);
        dim3 blocks((width + 15) / 16,(height + 15) / 16);

        initializeRandomStates<<<blocks, threads>>>(states, width, height, 42ULL);
        check(cudaGetLastError());
        check(cudaDeviceSynchronize());
        check(cudaMemcpyToSymbol(randomImageWidth, &width, sizeof(width)));
        check(cudaMemcpyToSymbol(randomStates, &states, sizeof(states)));
    }
    catch (...) {
        cudaFree(states);
        throw;
    }

    d_randomStates = states;
}

void renderCudaImage(unsigned char *cpuPixels, int width, int height)
{
    if (!d_objects)
        throw std::runtime_error("Call initializeScene() before rendering");
    if (!cpuPixels || width < 2 || height < 2 ||
        size_t(width) > std::numeric_limits<size_t>::max() / size_t(height) / 3)
        throw std::runtime_error("Invalid image buffer or dimensions");
    size_t bytes = size_t(width) * height * 3;
    unsigned char *gpuPixels = nullptr;
    check(cudaMalloc(reinterpret_cast<void **>(&gpuPixels), bytes));
    try
    {
        dim3 threads(16, 16);
        dim3 blocks((unsigned(width) + 15) / 16, (unsigned(height) + 15) / 16);
        genIm<<<blocks, threads>>>(gpuPixels, width, height);
        check(cudaGetLastError());
        check(cudaDeviceSynchronize());
        check(cudaMemcpy(cpuPixels, gpuPixels, bytes, cudaMemcpyDeviceToHost));
    }
    catch (...)
    {
        cudaFree(gpuPixels);
        throw;
    }
    check(cudaFree(gpuPixels));
}

// Attempt all cleanup operations, then report the first error.
void destroyScene()
{
    if (!d_objects)
        return;
    cudaError_t firstError = cudaSuccess;
    auto record = [&](cudaError_t result)
    {
        if (firstError == cudaSuccess)
            firstError = result;
    };
    deleteObjects<<<(objectCount + 127) / 128, 128>>>(d_objects, objectCount);
    record(cudaGetLastError());
    record(cudaDeviceSynchronize());
    Object **empty = nullptr;
    int zero = 0;
    record(cudaMemcpyToSymbol(sceneObjects, &empty, sizeof(empty)));
    record(cudaMemcpyToSymbol(sceneObjectCount, &zero, sizeof(zero)));
    record(cudaFree(d_objects));
    d_objects = nullptr;
    objectCount = 0;
    Sphere** emptyLights = nullptr;

    // Same for light objects
    record(cudaMemcpyToSymbol(sceneLights, &emptyLights, sizeof(emptyLights)));
    record(cudaMemcpyToSymbol(sceneLightCount, &zero, sizeof(zero)));
    record(cudaFree(d_lights));
    d_lights = nullptr;
    lightCount = 0;

    check(firstError);
}

void destroyRandom()
{
    if (!d_randomStates)
        return;

    RandomState* empty = nullptr;
    check(cudaMemcpyToSymbol(randomStates, &empty, sizeof(empty)));

    check(cudaFree(d_randomStates));
    d_randomStates = nullptr;
}
