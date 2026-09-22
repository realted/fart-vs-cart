#include "sdl_header.hpp"
#include <SDL2/SDL.h>
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
        bool autoClose = argc > 1 && std::string(argv[1]) == "--auto-close";
        const int width = 800, height = 600;
        std::vector<unsigned char> pixels(size_t(width)*height*3);
        initializeScene();
        initializeRandom(width, height);
        renderCudaImage(pixels.data(),width,height);
        SDL_SetMainReady();
        auto check = [](bool ok) { if (!ok) throw std::runtime_error(SDL_GetError()); };
        check(SDL_Init(SDL_INIT_VIDEO) == 0);
        window = SDL_CreateWindow("CUDA pixels - SDL display",SDL_WINDOWPOS_CENTERED,
            SDL_WINDOWPOS_CENTERED,width,height,SDL_WINDOW_SHOWN);
        check(window != nullptr);
        renderer = SDL_CreateRenderer(window,-1,SDL_RENDERER_ACCELERATED);
        if (!renderer) renderer = SDL_CreateRenderer(window,-1,SDL_RENDERER_SOFTWARE);
        check(renderer != nullptr);
        SDL_RendererInfo info{};
        check(SDL_GetRendererInfo(renderer,&info) == 0);
        texture = SDL_CreateTexture(renderer,SDL_PIXELFORMAT_RGB24,
            SDL_TEXTUREACCESS_STREAMING,width,height);
        check(texture != nullptr);
        check(SDL_UpdateTexture(texture,nullptr,pixels.data(),width*3) == 0);
        bool running = true;
        do {
            SDL_Event event;
            while (SDL_PollEvent(&event)) {
                if (event.type == SDL_QUIT ||
                    (event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE))
                    running = false;
            }
            check(SDL_RenderClear(renderer) == 0);
            check(SDL_RenderCopy(renderer,texture,nullptr,nullptr) == 0);
            SDL_RenderPresent(renderer);
            SDL_Delay(16);
        } while (running && !autoClose);
        std::printf("CUDA image presented using %s.\n",info.name);
    } catch (const std::exception& e) {
        std::fprintf(stderr,"%s\n",e.what()); result = 1;
    }
    try { destroyScene(); }
    catch (const std::exception& e) {
        std::fprintf(stderr, "Scene cleanup: %s\n", e.what()); result = 1;
    }
    try {destroyRandom();}
    catch (const std::exception& e) {
        std::fprintf(stderr, "Random cleanup: %s\n", e.what()); result = 1;
    }
    if (texture) SDL_DestroyTexture(texture);
    if (renderer) SDL_DestroyRenderer(renderer);
    if (window) SDL_DestroyWindow(window);
    SDL_Quit();
    return result;
}

