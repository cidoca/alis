/*
  Alis, A SEGA Master System emulator
  Copyright (C) 2002-2013 Cidorvan Leite

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see [http://www.gnu.org/licenses/].
*/

#include <stdio.h>
#include <string.h>
#include <SDL/SDL.h>
#include "core.h"

Uint8 *keys;
SDL_Surface *screen;
char rom_filename[FILENAME_MAX];
int cpu_running = 1, audio_present = 1;

void init_battery()
{
    FILE *fd;
    char filename[FILENAME_MAX];

    strcpy(filename, rom_filename);
    strcat(filename, ".srm");
    fd = fopen(filename, "rb");
    if (fd) {
        int unused = fread(RAM_EX, 1, 32768, fd);
        fclose(fd);
    }
}

void save_battery()
{
    FILE *fd;
    char filename[FILENAME_MAX];

    if (!battery)
        return;

    strcpy(filename, rom_filename);
    strcat(filename, ".srm");
    fd = fopen(filename, "wb");
    if (fd) {
        fwrite(RAM_EX, 1, 32768, fd);
        fclose(fd);
    }
}

void get_controls()
{
    static int pause = 0;

    Joy1 = Joy2 = 0xFF;

    // Joystick 1
    if (keys[SDLK_UP])
        Joy1 &= ~0x01;
    if (keys[SDLK_DOWN])
        Joy1 &= ~0x02;
    if (keys[SDLK_LEFT])
        Joy1 &= ~0x04;
    if (keys[SDLK_RIGHT])
        Joy1 &= ~0x08;
    if (keys[SDLK_z])
        Joy1 &= ~0x10;
    if (keys[SDLK_x])
        Joy1 &= ~0x20;

    // Joystick 2
    if (keys[SDLK_KP5])
        Joy1 &= ~0x40;
    if (keys[SDLK_KP2])
        Joy1 &= ~0x80;
    if (keys[SDLK_KP1])
        Joy2 &= ~0x01;
    if (keys[SDLK_KP3])
        Joy2 &= ~0x02;
    if (keys[SDLK_n])
        Joy2 &= ~0x04;
    if (keys[SDLK_m])
        Joy2 &= ~0x08;

    // Reset and pause button
    if (keys[SDLK_ESCAPE])
        Joy2 &= ~0x10;
    if (keys[SDLK_SPACE]) {
        if (!pause) {
            pause = 1;
            int_NMI();
        }
    } else
        pause = 0;
}

int run(void *data)
{
    unsigned int t, t2;

    if (audio_present)
        SDL_PauseAudio(0);

    while (cpu_running) {
        t = SDL_GetTicks();
        get_controls();
        scan_frame();
        write_frame(screen->pixels, screen->format->BitsPerPixel);
        SDL_Flip(screen);
        t2 = SDL_GetTicks();
        if (t2 - t < 16)
            SDL_Delay(16 - t2 + t);
    }

    if (audio_present)
        SDL_PauseAudio(1);

    save_battery();

    return 1;
}

void init_SDL() {
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER) < 0) {
        printf("Error initializing SDL: %s\n", SDL_GetError());
        exit(-1);
    }

    keys = SDL_GetKeyState(NULL);
    screen = SDL_SetVideoMode(256, 192, 0, SDL_HWSURFACE | SDL_DOUBLEBUF);

    SDL_AudioSpec wanted;
    wanted.freq = 44160;
    wanted.format = AUDIO_U8;
    wanted.channels = 1;
    wanted.samples = 736 * 2;
    wanted.callback = make_PSG;
    wanted.userdata = NULL;
    if (SDL_OpenAudio(&wanted, NULL) < 0) {
        audio_present = 0;
        printf("Could not open audio: %s\n", SDL_GetError());
    }

    SDL_EventState(SDL_ACTIVEEVENT, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEMOTION, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEBUTTONDOWN, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEBUTTONUP, SDL_IGNORE);
}

void open_ROM(char *filename)
{
    FILE *fd = fopen(filename, "rb");
    if (fd == NULL) {
        printf("** Error opening rom %s\n", filename);
        exit(-1);
    }

    strcpy(rom_filename, filename);
    char *ext = strrchr(rom_filename, '.');
    if (ext)
        *ext = 0;

    ROM = (unsigned char *)malloc(64 * 16384);
    int size = fread(ROM, 512, 2048, fd);
    fclose(fd);
    if (size & 1)
        memcpy(ROM, ROM + 0x200, 512 * (--size));

    // Initialize core engine
    init_banks(size / 32);
    reset_CPU();
    reset_VDP();
    reset_PSG();
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        printf("Alis - SEGA Master System emulator\n");
        printf("usage: %s <rom-file>\n\n", argv[0]);
        return 0;
    }

    open_ROM(argv[1]);

    init_SDL();

    SDL_Event event;
    SDL_Thread *thread = SDL_CreateThread(run, NULL);

    while (cpu_running) {
        if (SDL_WaitEvent(&event)) {
            if (event.type == SDL_QUIT)
                cpu_running = 0;
        }
    }

    SDL_WaitThread(thread, NULL);
    SDL_CloseAudio();
    SDL_Quit();

    return 0;
}
