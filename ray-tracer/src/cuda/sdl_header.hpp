#pragma once
// Construct the GPU scene once; edit makeScene() in main.cu to change objects.
void initializeScene();

void initializeRandom(int width, int height);

// Synchronous: returns after RGB24 pixels have been copied to CPU memory.
void renderCudaImage(unsigned char* cpuPixels, int width, int height);
// Destroy GPU objects and free their pointer array. Safe to call again.
void destroyScene();
void destroyRandom();