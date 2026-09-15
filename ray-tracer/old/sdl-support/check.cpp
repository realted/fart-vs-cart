#include <SDL2/SDL.h>
#include <iostream>
int main(int argc, char** argv) {
    (void)argc; (void)argv;
    if(SDL_Init(SDL_INIT_VIDEO)!=0) { std::cerr<<SDL_GetError(); return 1; }
    SDL_Window* window=SDL_CreateWindow("SDL2 setup test",SDL_WINDOWPOS_CENTERED,SDL_WINDOWPOS_CENTERED,320,180,SDL_WINDOW_HIDDEN);
    if(!window) { std::cerr<<SDL_GetError(); SDL_Quit(); return 1; }
    SDL_DestroyWindow(window);
    SDL_Quit();
    std::cout<<"SDL2 headers, linking, DLL loading, and window creation passed.\n";
    return 0;
}
