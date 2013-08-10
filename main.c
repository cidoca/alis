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

#include <fcntl.h>
#include <string.h>
#include <SDL/SDL.h>
#include "core.h"

#define CHECK_KEY(key, port, value) if (keys[key]) port &= ~value;
#define CHECK_STATE_KEY(key, state, action) if (keys[key] != state) { state = keys[key]; if (state) action; }

Uint8 *keys;
SDL_Surface *screen;
char rom_filename[FILENAME_MAX];
int cpu_running = 1, audio_present = 1;

void init_battery()
{
    int fd;
    char filename[FILENAME_MAX];

    strcpy(filename, rom_filename);
    strcat(filename, ".srm");
    fd = open(filename, O_RDONLY);
    if (fd > 0) {
        read(fd, RAM_EX, 32768);
        close(fd);
    }
}

void save_battery()
{
    int fd;
    char filename[FILENAME_MAX];

    if (!battery)
        return;

    strcpy(filename, rom_filename);
    strcat(filename, ".srm");
    fd = open(filename, O_CREAT | O_WRONLY, 0664);
    if (fd > 0) {
        write(fd, RAM_EX, 32768);
        close(fd);
    }
}

void save_game(int slot)
{
    int fd, pos;
    char filename[FILENAME_MAX];

    sprintf(filename, "%s.sa%d", rom_filename, slot);
    fd = open(filename, O_CREAT | O_WRONLY, 0664);
    if (fd > 0) {
        write(fd, &Flag, 18 + 16 + 6);          // CPU
        write(fd, &battery, 1 + 1);
        pos = pBank0 - ROM;
        write(fd, &pos, 4);
        pos = pBank1 - ROM;
        write(fd, &pos, 4);
        pos = pBank2 - ROM;
        write(fd, &pos, 4);
        pos = pBank2ROM - ROM;
        write(fd, &pos, 4);                     // BANKS
        write(fd, RAM, 8192);                   // RAM
        if (battery)
            write(fd, RAM_EX, 32768);           // SRAM
        write(fd, &Nationalization, 1);         // IO
        write(fd, &rVol1, 24 + 9);              // PSG
        write(fd, &VDPStatus, 1 + 2 + 16433);   // VDP
        close(fd);
        printf("game saved to slot %d\n", slot);
    }
}

int load_game(int slot)
{
    int fd;
    char filename[FILENAME_MAX];

    sprintf(filename, "%s.sa%d", rom_filename, slot);
    fd = open(filename, O_RDONLY);
    if (fd > 0) {
        read(fd, &Flag, 18 + 16 + 6);           // CPU
        read(fd, &battery, 1 + 1 + 16);
        pBank0 += (unsigned)ROM;
        pBank1 += (unsigned)ROM;
        pBank2 += (unsigned)ROM;
        pBank2ROM += (unsigned)ROM;             // BANKS
        read(fd, RAM, 8192);                    // RAM
        if (battery)
            read(fd, RAM_EX, 32768);            // SRAM
        read(fd, &Nationalization, 1);          // IO
        read(fd, &rVol1, 24 + 9);               // PSG
        read(fd, &VDPStatus, 1 + 2 + 16433);    // VDP
        close(fd);
        printf("game load from slot %d\n", slot);
    }
}

void get_controls()
{
    static int pause = 0;
    static int save_slot1 = 0, save_slot2 = 0, save_slot3 = 0, save_slot4 = 0, save_slot5 = 0;
    static int load_slot1 = 0, load_slot2 = 0, load_slot3 = 0, load_slot4 = 0, load_slot5 = 0;

    Joy1 = Joy2 = 0xFF;

    // Joystick 1
    CHECK_KEY(SDLK_UP, Joy1, 0x01)
    CHECK_KEY(SDLK_DOWN, Joy1, 0x02)
    CHECK_KEY(SDLK_LEFT, Joy1, 0x04)
    CHECK_KEY(SDLK_RIGHT, Joy1, 0x08)
    CHECK_KEY(SDLK_z, Joy1, 0x10)
    CHECK_KEY(SDLK_x, Joy1, 0x20)

    // Joystick 2
    CHECK_KEY(SDLK_KP5, Joy1, 0x40)
    CHECK_KEY(SDLK_KP2, Joy1, 0x80)
    CHECK_KEY(SDLK_KP1, Joy2, 0x01)
    CHECK_KEY(SDLK_KP3, Joy2, 0x02)
    CHECK_KEY(SDLK_n, Joy2, 0x04)
    CHECK_KEY(SDLK_m, Joy2, 0x08)

    // Reset and pause button
    CHECK_KEY(SDLK_ESCAPE, Joy2, 0x10)
    CHECK_STATE_KEY(SDLK_SPACE, pause, int_NMI())

    // Save game
    CHECK_STATE_KEY(SDLK_F5, save_slot1, save_game(1))
    CHECK_STATE_KEY(SDLK_F6, save_slot2, save_game(2))
    CHECK_STATE_KEY(SDLK_F7, save_slot3, save_game(3))
    CHECK_STATE_KEY(SDLK_F8, save_slot4, save_game(4))

    // Load game
    CHECK_STATE_KEY(SDLK_F9, load_slot1, load_game(1))
    CHECK_STATE_KEY(SDLK_F10, load_slot2, load_game(2))
    CHECK_STATE_KEY(SDLK_F11, load_slot3, load_game(3))
    CHECK_STATE_KEY(SDLK_F12, load_slot4, load_game(4))
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
    int fd = open(filename, O_RDONLY);
    if (fd == -1) {
        printf("** Error opening rom %s\n", filename);
        exit(-1);
    }

    strcpy(rom_filename, filename);
    char *ext = strrchr(rom_filename, '.');
    if (ext)
        *ext = 0;

    ROM = (unsigned char *)malloc(512 * 2048);
    int size = read(fd, ROM, 512 * 2048) / 512;
    close(fd);
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
