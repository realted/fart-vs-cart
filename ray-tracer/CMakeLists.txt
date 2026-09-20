cmake_minimum_required(VERSION 3.24)
project(RayTracer LANGUAGES CXX CUDA)

add_executable(raytracer_cuda src/cuda/main.cu)

set_target_properties(raytracer_cuda PROPERTIES
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
    CUDA_STANDARD 17
    CUDA_STANDARD_REQUIRED ON
    CUDA_ARCHITECTURES 86
)