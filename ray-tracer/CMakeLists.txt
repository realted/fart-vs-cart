cmake_minimum_required(VERSION 3.24)
project(RayTracer LANGUAGES CXX CUDA)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# SDL's Visual C++ x64 SDK. The existing MinGW SDK remains separate.
if(NOT MSVC OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "Use Visual Studio 2022 with -A x64 for this CUDA/SDL build.")
endif()
set(SDL2_MSVC_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/sdl2-msvc")
add_library(SDL2_msvc SHARED IMPORTED)
set_target_properties(SDL2_msvc PROPERTIES
    IMPORTED_IMPLIB "${SDL2_MSVC_ROOT}/lib/x64/SDL2.lib"
    IMPORTED_LOCATION "${SDL2_MSVC_ROOT}/lib/x64/SDL2.dll"
    INTERFACE_INCLUDE_DIRECTORIES "${SDL2_MSVC_ROOT}/include;${SDL2_MSVC_ROOT}/include/SDL2")

function(enable_sdl target)
    target_link_libraries(${target} PRIVATE SDL2_msvc)
    target_compile_features(${target} PRIVATE cxx_std_17)
    target_compile_definitions(${target} PRIVATE SDL_MAIN_HANDLED NOMINMAX)
    add_custom_command(TARGET ${target} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:SDL2_msvc>" "$<TARGET_FILE_DIR:${target}>"
        VERBATIM)
endfunction()
  
add_executable(raytracer_cpu src/CPU/render.cpp)
enable_sdl(raytracer_cpu)

# CPU main()/SDL + CUDA pixel generation in a separate translation unit.
add_executable(cuda_sdl_demo src/GPU_cuda/cuda_out.cpp src/GPU_cuda/main.cu)
set_target_properties(cuda_sdl_demo PROPERTIES
    CUDA_STANDARD 17 CUDA_STANDARD_REQUIRED ON CUDA_ARCHITECTURES 86)
enable_sdl(cuda_sdl_demo)
