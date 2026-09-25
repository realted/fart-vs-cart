#pragma once
void initializeScene();
void initializeRandom(int width, int height);
void initializeRenderBuffers(int width, int height);
// Reset the sum, sample count, and random sequence after a scene/camera change.
void resetAccumulation();
// Add one sample per pixel and copy the gamma-corrected average to CPU RGB24.
// Returns the total number of samples accumulated per pixel.
int renderCudaImage(unsigned char* cpuPixels, int width, int height);
void destroyRenderBuffers();
void destroyScene();
void destroyRandom();
