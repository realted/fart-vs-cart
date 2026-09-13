# C++ ray tracer

A CPU path tracing starter with spheres, diffuse and reflective materials, sky lighting, antialiasing, gamma correction, and native BMP output. No external libraries or GPU SDK required.

## Build and run on this computer

Open PowerShell in this folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1 -Render
Start-Process ./render.bmp
```

If script execution is restricted, use a process-scoped invocation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./build.ps1 -Render
```

Higher quality (takes longer):

```powershell
./build.ps1 -Render -Width 1280 -Samples 128
```

The executable also accepts positional arguments: output filename, width, samples per pixel.

```powershell
./build/raytracer.exe custom.bmp 800 64
```

## Dependencies

- C++17 compiler: existing MSYS2 UCRT64 GCC 14.2.0 at `C:/msys64/ucrt64/bin/g++.exe`.
- PowerShell for the build script.
- C++ standard library and GCC runtime supplied by MSYS2. Keep the compiler's bin directory on PATH when running the executable.

All required dependencies are already installed on this computer. The build script uses GCC directly. CMake is optional and is not installed by this setup; a CMakeLists.txt is included for other environments that already use CMake.

## Project structure

- `src/main.cpp`: vector math, intersections, materials, camera rays, renderer, BMP writer.
- `build.ps1`: compile, optionally render.
- `.vscode/tasks.json`: default VS Code build task (Ctrl+Shift+B).
- `CMakeLists.txt`: optional portable CMake build definition.

Edit the `scene` list to move spheres or change colors. Camera rays are generated in the sampling loop. A fixed random seed makes renders reproducible with the same compiler/runtime. This starter is single-threaded and uses CPU rendering; GPU acceleration and interactive viewing can be added later.
