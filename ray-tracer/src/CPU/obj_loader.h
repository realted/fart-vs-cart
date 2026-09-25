#pragma once
// Include after Vec3, Material, Object and Triangle. Single-translation-unit loader.
#define TINYOBJLOADER_IMPLEMENTATION
#include "vendor/tiny_obj_loader.h"
#include <filesystem>

// Positions use: world = OBJ position * scale + translation.
// Geometry only: supplied material and flat face normals are used for all faces.
inline std::vector<std::shared_ptr<Object>> loadObj(
    const std::string& filename, const Material& material,
    double scale = 1.0, Vec3 translation = {0,0,0}) {
    if (!std::isfinite(scale) || scale == 0)
        throw std::runtime_error("OBJ scale must be finite and nonzero.");
    tinyobj::ObjReaderConfig config;
    config.triangulate = true;
    config.mtl_search_path = std::filesystem::path(filename).parent_path().string();
    tinyobj::ObjReader reader;
    if (!reader.ParseFromFile(filename, config))
        throw std::runtime_error("Cannot load OBJ " + filename + ": " + reader.Error());
    if (!reader.Warning().empty()) std::cerr << "OBJ warning: " << reader.Warning();
    const auto& vertices = reader.GetAttrib().vertices;
    auto vertex = [&](int index) {
        if(index < 0 || static_cast<size_t>(index) >= vertices.size()/3)
            throw std::runtime_error("OBJ has an invalid vertex index: " + filename);
        const size_t i = static_cast<size_t>(index)*3;
        Vec3 p = Vec3{vertices[i],vertices[i+1],vertices[i+2]}*scale + translation;
        if(!std::isfinite(p.x) || !std::isfinite(p.y) || !std::isfinite(p.z))
            throw std::runtime_error("OBJ has a nonfinite position: " + filename);
        return p;
    };
    std::vector<std::shared_ptr<Object>> triangles;
    size_t skipped=0;
    for(const auto& shape : reader.GetShapes()) {
        size_t offset=0;
        for(unsigned int count : shape.mesh.num_face_vertices) {
            if(count != 3 || offset+count > shape.mesh.indices.size())
                throw std::runtime_error("OBJ face could not be triangulated: " + filename);
            Vec3 a=vertex(shape.mesh.indices[offset].vertex_index);
            Vec3 b=vertex(shape.mesh.indices[offset+1].vertex_index);
            Vec3 c=vertex(shape.mesh.indices[offset+2].vertex_index);
            offset+=count;
            Vec3 n=cross(b-a,c-a);
            if(dot(n,n)<=1e-12) { ++skipped; continue; }
            triangles.push_back(std::make_shared<Triangle>(a,b,c,material));
        }
    }
    if(triangles.empty()) throw std::runtime_error("OBJ contains no usable triangles: " + filename);
    std::cout << "Loaded " << triangles.size() << " triangles from " << filename
              << " (skipped " << skipped << " degenerate/tiny triangles).\n";
    return triangles;
}
