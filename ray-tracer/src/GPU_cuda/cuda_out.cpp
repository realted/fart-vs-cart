#include "sdl_header.hpp"
#include <SDL2/SDL.h>
#include <algorithm>
#include <cstdio>
#include <stdexcept>
#include <string>
#include <vector>

int main(int argc, char** argv) {
    SDL_Window* window = nullptr;
    SDL_Renderer* renderer = nullptr;
    SDL_Texture* texture = nullptr;
    int result = 0;
    try {
        int width = 640, height = 640, targetSamples = 256;
        bool heightSpecified = false;
        bool autoClose = false;
        for (int i=1; i<argc; ++i) {
            std::string arg = argv[i];
            if (arg == "--auto-close") autoClose = true;
            else if (arg == "--help") {
                std::puts("Options: --width N --height N --samples N --auto-close\n"
                          "Escape: close. R: restart accumulation.");
                return 0;
            } else if ((arg == "--width" || arg == "--height" || arg == "--samples") && i+1<argc) {
                std::string value = argv[++i];
                size_t used = 0;
                int number = std::stoi(value, &used);
                if (used != value.size()) throw std::runtime_error("Expected an integer for " + arg);
                if (arg == "--width") width = number;
                else if (arg == "--height") { height = number; heightSpecified = true; }
                else targetSamples = number;
            } else throw std::runtime_error("Unknown or incomplete option: " + arg);
        }
        // Match simple_render.cpp: square unless an explicit height is supplied.
        if (!heightSpecified) height = width;
        if (width<16 || width>4096 || height<16 || height>4096 ||
            targetSamples<1 || targetSamples>1000000)
            throw std::runtime_error("Width/height must be 16..4096; samples must be 1..1000000");

        SDL_SetMainReady();
        auto check = [](bool ok) { if (!ok) throw std::runtime_error(SDL_GetError()); };
        check(SDL_Init(SDL_INIT_VIDEO) == 0);
        window = SDL_CreateWindow("CUDA renderer - initializing",SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,width,height,SDL_WINDOW_SHOWN);
        check(window != nullptr);
        renderer = SDL_CreateRenderer(window,-1,SDL_RENDERER_ACCELERATED);
        if (!renderer) renderer = SDL_CreateRenderer(window,-1,SDL_RENDERER_SOFTWARE);
        check(renderer != nullptr);
        texture = SDL_CreateTexture(renderer,SDL_PIXELFORMAT_RGB24,
            SDL_TEXTUREACCESS_STREAMING,width,height);
        check(texture != nullptr);
        std::vector<unsigned char> pixels(size_t(width)*height*3,0);
        auto present = [&]() {
            check(SDL_RenderClear(renderer) == 0);
            check(SDL_RenderCopy(renderer,texture,nullptr,nullptr) == 0);
            SDL_RenderPresent(renderer);
        };
        check(SDL_UpdateTexture(texture,nullptr,pixels.data(),width*3) == 0);
        present();

        initializeScene();
        initializeRandom(width,height);
        initializeRenderBuffers(width,height);
        bool running = true;
        int samples = 0;
        while (running) {
            SDL_Event event;
            bool restart = false;
            while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT ||
                    (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE))
                    running = false;
                if (event.type == SDL_KEYDOWN && !event.key.repeat && event.key.keysym.sym == SDLK_r)
                    restart = true;
            }
            if (!running) break;
            if (restart) {
                resetAccumulation();
                samples = 0;
                std::fill(pixels.begin(),pixels.end(),0);
                check(SDL_UpdateTexture(texture,nullptr,pixels.data(),width*3) == 0);
            }
            if (samples < targetSamples) {
                // GPU adds one sample to each pixel's persistent linear sum.
                samples = renderCudaImage(pixels.data(),width,height);
                check(SDL_UpdateTexture(texture,nullptr,pixels.data(),width*3) == 0);
                std::string title = "CUDA renderer: " + std::to_string(samples) +
                    " / " + std::to_string(targetSamples) + " samples/pixel - R: restart, Esc: close";
                SDL_SetWindowTitle(window,title.c_str());
                present();
                if (samples == targetSamples) {
                    std::printf("Completed %dx%d at %d samples/pixel.\n",width,height,samples);
                    if (autoClose) running = false;
                }
            } else {
                // Preserve the completed image and continue processing window events.
                present();
                SDL_Delay(16);
            }
        }
    } catch (const std::exception& e) {
        std::fprintf(stderr,"%s\n",e.what()); result = 1;
    }
    auto cleanup = [&](void (*release)(), const char* name) {
        try { release(); }
        catch (const std::exception& e) {
            std::fprintf(stderr,"%s cleanup: %s\n",name,e.what()); result = 1;
        }
    };
    cleanup(destroyRenderBuffers,"Image buffers");
    cleanup(destroyScene,"Scene");
    cleanup(destroyRandom,"Random states");
    if (texture) SDL_DestroyTexture(texture);
    if (renderer) SDL_DestroyRenderer(renderer);
    if (window) SDL_DestroyWindow(window);
    SDL_Quit();
    return result;
}
