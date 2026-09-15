## Configure directly in SDL.cpp

Edit modelPath, modelScale, modelPosition, and modelMaterial in MODEL SETTINGS above the scene list, then run build-sdl.ps1 -Source src/SDL.cpp -Run. No model command-line arguments are needed. Optional CLI arguments still override these defaults. The render-obj.ps1 launcher explicitly supplies its own model settings; use build-sdl.ps1 to use your C++ settings.

# Rendering OBJ models

From the outer fart_vs_cart folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ray-tracer\render-obj.ps1
```

This compiles SDL.cpp and displays the provided cube. Relative OBJ paths below are resolved from ray-tracer, independent of your terminal directory.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\ray-tracer\render-obj.ps1 -Obj "C:\Users\Ted\Downloads\cube.obj" -Scale 0.35 -X 1 -Y -0.15 -Z -1.2 -Samples 128
```

The cube spans -1..1 originally. Scaling by 0.35 and translating to y=-0.15 places its bottom on the floor at y=-0.5. Other models may need different scale/position values; geometry is not automatically centered or normalized.

## Integration

src/obj_loader.h provides loadObj(filename, material, scale, translation). Include it after the Triangle definition in this single-translation-unit renderer. It returns a vector of shared_ptr<Object> containing your Triangle objects:

```cpp
auto mesh = loadObj("models/cube.obj",
    Material{{0.8,0.2,0.5}, false, {0,0,0}},
    0.35, Vec3{1.0,-0.15,-1.2});
objects.insert(objects.end(), mesh.begin(), mesh.end());
```

Call it before rendering. To load multiple models, call it repeatedly with different transforms/materials. C++ relative paths use the process working directory; the PowerShell launcher resolves them for you.

SDL.cpp accepts width and samples followed by --obj PATH, --scale S, --position X Y Z, and --auto-close. Loading an OBJ replaces the old demonstration triangle; spheres, floor, and light remain. Without --obj, the MODEL SETTINGS in SDL.cpp are used. Set modelPath to an empty string to retain the original scene. The imported material is configured in the loadObj call inside main().

## Supported and limitations

- OBJ polygon meshes, multiple groups/objects, positive and negative indices, and face tokens v, v/vt, v//vn, v/vt/vn.
- Triangulation is performed by vendored TinyObjLoader v2.0.0rc13 (MIT; license in header).
- Geometry only: UVs, imported normals, texture images, smoothing groups, and MTL shading are not applied. Triangles use flat face normals and the supplied renderer material.
- Missing cube.mtl produces a warning but does not prevent geometry rendering.
- For complicated concave or nonplanar polygons, triangulate during export in Blender; built-in polygon triangulation has limitations. Curves/lines/points are not rendered.
- Invalid indices/nonfinite positions fail clearly. Degenerate or tiny triangles are skipped using the existing renderer's 1e-12 area-squared threshold.
- All rays still test every object. Large meshes will be slow until a BVH or other acceleration structure is added.
- A guard was added before normalizing triangle normals. test.cpp was not changed.

## Validation

Provided cube: 6 quads converted to 12 triangles, rendered at 320x180 and 8 samples/pixel.
Tests in sdl-support/obj-tests/loader_test.cpp cover cube counts/bounds, scaling/translation, negative indices, invalid indices, and degenerate geometry. Build/run tests from sdl-support/bin so their fixture.obj stays in the ignored build directory.

Dependency source: https://github.com/tinyobjloader/tinyobjloader/tree/v2.0.0rc13
Header: src/vendor/tiny_obj_loader.h (vendored; no package install or extra linker flags needed).

