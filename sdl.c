#include <SDL2/SDL.h>
#include "psg.h"
#include "ga.h"
#include "vdp.h"
#include "log.h"

#ifdef DRAW_TILES
    #define SCREEN_HEIGHT (192 + 128)
#else
    #define SCREEN_HEIGHT (192)
#endif

Uint8 *keys;
SDL_Window *win;
SDL_Renderer *renderer;
SDL_Texture *texture;

void SDLinit() {
    printf("Initializing SDL ... ");
    fflush(stdout);

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER) < 0)
        goto error;

    // Create window and texture
    win = SDL_CreateWindow("Alis", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 256 * 3,
        SCREEN_HEIGHT * 3, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!win)
        goto error;

    renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer)
        goto error;

    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING,
        256, SCREEN_HEIGHT);
    if (!texture)
        goto error;

    // Setup keyboard and joysticks
    keys = (Uint8*)SDL_GetKeyboardState(NULL);

    // Setup audio
    SDL_AudioSpec wanted;
    wanted.freq = PSG_FREQUENCY;
    wanted.format = AUDIO_U8;
    wanted.channels = 1;
    wanted.samples = PSG_FREQUENCY / 60;
    wanted.callback = PSGupdateBuffer;
    wanted.userdata = NULL;
    if (SDL_OpenAudio(&wanted, NULL) < 0)
        goto error;

    // Ignore keyboard and mouse events
    SDL_EventState(SDL_KEYDOWN, SDL_IGNORE);
    SDL_EventState(SDL_KEYUP, SDL_IGNORE);
    SDL_EventState(SDL_TEXTINPUT, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEMOTION, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEBUTTONDOWN, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEBUTTONUP, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEWHEEL, SDL_IGNORE);

    printf("OK\n");
    return;

error:
    printf("ERROR: %s\n", SDL_GetError());
    exit(-1);
}

void SDLdeinit() {
    SDL_CloseAudio();
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(win);
    SDL_Quit();
}

void mapJoystick() {
    joyP1 = joyP2 = 0xFF;

    if (keys[SDL_SCANCODE_UP])
        joyP1 &= ~0x01;
    if (keys[SDL_SCANCODE_DOWN])
        joyP1 &= ~0x02;
    if (keys[SDL_SCANCODE_LEFT])
        joyP1 &= ~0x04;
    if (keys[SDL_SCANCODE_RIGHT])
        joyP1 &= ~0x08;
    if (keys[SDL_SCANCODE_Z])
        joyP1 &= ~0x10;
    if (keys[SDL_SCANCODE_X])
        joyP1 &= ~0x20;
    if (keys[SDL_SCANCODE_ESCAPE])
        joyP2 &= ~0x10;
//    if (keys[SDL_SCANCODE_SPACE]) // TODO: missing Z80 NMI logic for pause button

#ifdef DEBUG
    if (keys[SDL_SCANCODE_F12])
        dumping = 1;
#endif

}

void SDLmainLoop() {
    int pitch;
    SDL_Event event;
    void *frameBuffer;
    unsigned done = 0, t, tc, tf = 0;

    SDL_PauseAudio(0);

    t = SDL_GetTicks();
    while (!done) {
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT)
                done = 1;
        }

//        printf("** NEW FRAME **\n");
        mapJoystick();
        SDL_LockTexture(texture, NULL, &frameBuffer, &pitch);
        renderFrame(frameBuffer);
        SDL_UnlockTexture(texture);
        SDL_RenderCopy(renderer, texture, NULL, NULL);
        SDL_RenderPresent(renderer);

        t += (tf++ % 3 == 0) ? 16 : 17;
        tc = SDL_GetTicks();
        if (t > tc)
            SDL_Delay(t - tc);
        else
            t = tc;
    }

    SDL_PauseAudio(1);
}

