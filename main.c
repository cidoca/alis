/*
  Alis, A SEGA Master System emulator
  Copyright (C) 2002-2014 Cidorvan Leite

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
#include <SDL2/SDL.h>
#include "core.h"
//#include "icon.h"

#define MESSAGE_TIME (60 * 2)
#define CHECK_KEY(key, port, value) if (keys[key]) port &= ~value;
#define CHECK_STATE_KEY(key, state, action) if (keys[key] != state) { state = keys[key]; if (state) action; }

Uint8 *keys;
SDL_Window *win;
SDL_Renderer *renderer;
SDL_Texture *texture;
char rom_filename[FILENAME_MAX];
char message[32] = "";
int message_time = 0;
int audio_present = 1;
int cpu_delay_index = 3;
int cpu_delay[] = {2, 4, 8, 16, 32, 64, 128};

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

    snprintf(filename, FILENAME_MAX, "%s.sa%d", rom_filename, slot);
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
        message_time = MESSAGE_TIME;
        snprintf(message, sizeof(message), "GAME SAVED TO SLOT %d", slot);
    }
}

int load_game(int slot)
{
    int fd;
    char filename[FILENAME_MAX];

    snprintf(filename, FILENAME_MAX, "%s.sa%d", rom_filename, slot);
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
        message_time = MESSAGE_TIME;
        snprintf(message, sizeof(message), "GAME LOADED FROM SLOT %d", slot);
    }
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

void change_cpu_speed(int delta)
{
    if (delta < 0 && cpu_delay_index > 0 || delta > 0 && cpu_delay_index < sizeof(cpu_delay) / sizeof(cpu_delay[0]) - 1) {
        cpu_delay_index += delta;
        message_time = MESSAGE_TIME;
        snprintf(message, sizeof(message), "CPU SPEED %d%%", 1600 / cpu_delay[cpu_delay_index]);
    }
}

void get_controls()
{
    static int pause = 0, slow = 0, fast = 0;
    static int save_slot1 = 0, save_slot2 = 0, save_slot3 = 0, save_slot4 = 0, save_slot5 = 0;
    static int load_slot1 = 0, load_slot2 = 0, load_slot3 = 0, load_slot4 = 0, load_slot5 = 0;

    Joy1 = Joy2 = 0xFF;

    // Joystick 1
    CHECK_KEY(SDL_SCANCODE_UP, Joy1, 0x01)
    CHECK_KEY(SDL_SCANCODE_DOWN, Joy1, 0x02)
    CHECK_KEY(SDL_SCANCODE_LEFT, Joy1, 0x04)
    CHECK_KEY(SDL_SCANCODE_RIGHT, Joy1, 0x08)
    CHECK_KEY(SDL_SCANCODE_Z, Joy1, 0x10)
    CHECK_KEY(SDL_SCANCODE_X, Joy1, 0x20)

    // Joystick 2
    CHECK_KEY(SDL_SCANCODE_KP_5, Joy1, 0x40)
    CHECK_KEY(SDL_SCANCODE_KP_2, Joy1, 0x80)
    CHECK_KEY(SDL_SCANCODE_KP_1, Joy2, 0x01)
    CHECK_KEY(SDL_SCANCODE_KP_3, Joy2, 0x02)
    CHECK_KEY(SDL_SCANCODE_N, Joy2, 0x04)
    CHECK_KEY(SDL_SCANCODE_M, Joy2, 0x08)

    // Reset and pause button
    CHECK_KEY(SDL_SCANCODE_ESCAPE, Joy2, 0x10)
    CHECK_STATE_KEY(SDL_SCANCODE_SPACE, pause, int_NMI())

    // Change speed
    CHECK_STATE_KEY(SDL_SCANCODE_F3, slow, change_cpu_speed(1))
    CHECK_STATE_KEY(SDL_SCANCODE_F4, fast, change_cpu_speed(-1))

    // Save game
    CHECK_STATE_KEY(SDL_SCANCODE_F5, save_slot1, save_game(1))
    CHECK_STATE_KEY(SDL_SCANCODE_F6, save_slot2, save_game(2))
    CHECK_STATE_KEY(SDL_SCANCODE_F7, save_slot3, save_game(3))
    CHECK_STATE_KEY(SDL_SCANCODE_F8, save_slot4, save_game(4))

    // Load game
    CHECK_STATE_KEY(SDL_SCANCODE_F9, load_slot1, load_game(1))
    CHECK_STATE_KEY(SDL_SCANCODE_F10, load_slot2, load_game(2))
    CHECK_STATE_KEY(SDL_SCANCODE_F11, load_slot3, load_game(3))
    CHECK_STATE_KEY(SDL_SCANCODE_F12, load_slot4, load_game(4))
}

void draw_message(void *buffer)
{
    if (message_time > 0) {
        int x = VDPR & 0x20 ? 16 : 8;
        message_time--;
        draw_text(buffer, x + 1, 9, message, 0x202020);
        draw_text(buffer, x, 8, message, 0xE0E0E0);
    }
}

void main_loop()
{
    int done = 0;
    SDL_Event event;
    void *buffer;
    unsigned int t, t2, p;
    SDL_Rect rect = {8, 0, 256, 192};

    if (audio_present)
        SDL_PauseAudio(0);

    while (!done) {
        t = SDL_GetTicks();

        while (SDL_PollEvent(&event))
            if (event.type == SDL_QUIT)
                done = 1;

        get_controls();
        SDL_LockTexture(texture, NULL, &buffer, &p);
        scan_frame(buffer);
        draw_message(buffer);
        SDL_UnlockTexture(texture);
        SDL_RenderCopy(renderer, texture, VDPR & 0x20 ? &rect : NULL,  NULL);
        SDL_RenderPresent(renderer);
        t2 = SDL_GetTicks();
        if (t2 - t < cpu_delay[cpu_delay_index])
            SDL_Delay(cpu_delay[cpu_delay_index] - t2 + t);
    }

    if (audio_present)
        SDL_PauseAudio(1);

    save_battery();
}

void init_SDL(char *filename)
{
    char title[FILENAME_MAX];

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER) < 0) {
        printf("Error initializing SDL: %s\n", SDL_GetError());
        exit(-1);
    }

    // Create window and texture
    snprintf(title, FILENAME_MAX, "Alis - %s", filename);
    win = SDL_CreateWindow(title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 800, 600, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    renderer = SDL_CreateRenderer(win, -1, SDL_RENDERER_ACCELERATED);
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "1");
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, 256, 192);
    keys = (Uint8*)SDL_GetKeyboardState(NULL);

    // Define window icon
//    SDL_Surface *icon = SDL_CreateRGBSurfaceFrom(icon_pixels, 64, 64, 16, 64 * 2, 0xF800, 0x7E0, 0x1F, 0x0);
//    SDL_SetWindowIcon(win, icon);
//    SDL_FreeSurface(icon);

    // Setup audio
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

    // Ignore keyboard and mouse events
    SDL_EventState(SDL_KEYDOWN, SDL_IGNORE);
    SDL_EventState(SDL_KEYUP, SDL_IGNORE);
    SDL_EventState(SDL_TEXTINPUT, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEMOTION, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEBUTTONDOWN, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEBUTTONUP, SDL_IGNORE);
    SDL_EventState(SDL_MOUSEWHEEL, SDL_IGNORE);
}

void deinit_SDL()
{
    SDL_CloseAudio();
    SDL_DestroyTexture(texture);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(win);
    SDL_Quit();
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        printf("Alis - SEGA Master System emulator\n");
        printf("usage: %s <rom-file>\n\n", argv[0]);
        return 0;
    }

    open_ROM(argv[1]);

    init_SDL(argv[1]);

    main_loop();

    deinit_SDL();

    return 0;
}
