#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <vector>

void checkCuda(cudaError_t result) {
    if (result != cudaSuccess) {
        std::fprintf(stderr, "CUDA error: %s\n",
                     cudaGetErrorString(result));
        std::exit(EXIT_FAILURE);
    }
}