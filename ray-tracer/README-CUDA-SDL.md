# SDL with MSVC and CUDA

From the project root in PowerShell:

```powershell
.\build-cuda-sdl.ps1 -Run
```

This builds and opens cuda_sdl_demo: CUDA creates a gradient, copies RGB24 pixels to CPU memory, and SDL displays them. Escape or the close button exits.

Build/run the existing CPU renderer:

```powershell
.\build-cuda-sdl.ps1 -Target raytracer_cpu -Run -ProgramArgs '640','16'
```

The existing GCC build-sdl.ps1 and sdl2-sdk are unchanged.

## Files to learn from

- src/cuda/sdl_demo.cpp: CPU main, SDL window/events/texture/display.
- src/cuda/sdl_gradient.hpp: ordinary C++ function interface.
- src/cuda/sdl_gradient.cu: kernel, GPU allocation, launch, and copy back.

The gradient example allocates for one image. For a progressive renderer, keep GPU scene and accumulation allocations between frames. This setup does not port the CPU ray-tracing algorithm.

CMake defines SDL_MAIN_HANDLED (the application calls SDL_SetMainReady) and NOMINMAX (avoids Windows macros conflicting with std::min/max). It uses the x64 Visual C++ SDL2 import library, copies its DLL beside each SDL executable, and selects the static MSVC runtime consistently for C++ and CUDA.

## Dependency

Official SDL2 2.32.10 Visual C++ archive:
https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-devel-2.32.10-VC.zip
SHA256: AF347939395A58B365846AAEA27391E69F9EC9D4DD650D6AC40802159B418A6E

Headers are under sdl2-msvc/include/SDL2 so existing #include <SDL2/SDL.h> statements work. x64 libraries are under sdl2-msvc/lib/x64. License: sdl2-msvc/LICENSE.txt.

## Validation

Release builds passed with MSVC 19.39 and CUDA 12.6.85. The CUDA/SDL demo verified GPU gradient corner values and successfully presented through SDL direct3d11. The existing CPU renderer loaded 634 model triangles and completed 16x16 at one sample per pixel using SDL's dummy video driver.
