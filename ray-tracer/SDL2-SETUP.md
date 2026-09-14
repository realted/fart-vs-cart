# SDL2 setup (additions only)

SDL2 is installed locally in sdl2-sdk. All pre-existing project files were preserved.

From the outer fart_vs_cart folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ray-tracer\build-sdl.ps1 -Source src/test.cpp -Run
```

From ray-tracer:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build-sdl.ps1 -Source src/test.cpp -Run
```

Replace src/test.cpp with any single C++ source path relative to ray-tracer. Omit -Run to compile only. Executables and SDL2.dll are placed in sdl-support/bin, separate from existing build outputs. This script currently builds one translation unit; multi-file programs will require extending it.

Your source can use #include <SDL2/SDL.h> (or <SDL.h>). For SDL2's standard Windows entry-point handling use int main(int argc, char** argv). The script links mingw32, SDL2main, and SDL2. Code that explicitly uses SDL_MAIN_HANDLED plus SDL_SetMainReady is also supported.

New c_cpp_properties.json files support opening either the outer folder or ray-tracer in VS Code with Microsoft's C/C++ extension. Existing tasks.json, settings.json, build.ps1 and CMakeLists.txt were not changed. Therefore existing build tasks do NOT use the new SDL setup; run build-sdl.ps1 explicitly. Existing outer settings.json contains an old CMake source path; it was preserved as requested.

Dependency setup alone does not replace your BMP output with an SDL display. Add your desired SDL display code yourself when ready; your rendering files were not edited.

Validation: SDL include, link, DLL load, and hidden Windows window creation passed via sdl-support/check.cpp. Existing src/test.cpp compiled successfully with its existing warnings. SHA256 comparison confirmed all 16 pre-existing non-Git files remained unchanged.

SDL2 version 2.32.10, MSYS2 UCRT64 package. License included under sdl2-sdk/share/licenses/SDL2. Package source: https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-SDL2
