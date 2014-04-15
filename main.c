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

#define JOY_THRESHOLD   5000
#define MESSAGE_TIME    2000
#define CHECK_KEY(key, port, value) if (keys[key]) port &= ~value;
#define CHECK_AXIS(joy, jn, axis, value1, value2) \
    if (joy_axis[jn][axis] <= -JOY_THRESHOLD) joy &= ~value1; \
    else if (joy_axis[jn][axis] >= JOY_THRESHOLD) joy &= ~value2;
#define CHECK_BUTTON(joy, jn, flag, value) if (joy_button[jn] & flag) joy &= ~value;
#define CHECK_STATE_KEY(key, state, action) if (keys[key] != state) { \
    state = keys[key]; if (state) action; }

Uint8 *keys;
SDL_Window *win;
SDL_Renderer *renderer;
SDL_Texture *texture;
SDL_Joystick *joy1 = NULL, *joy2 = NULL;
char rom_filename[FILENAME_MAX];
char message[32] = "";
Uint32 message_timeout = 0;
int audio_present = 1;
int cpu_delay_index = 3;
int cpu_delay[] = {2, 4, 8, 16, 32, 64, 128};
int joy_axis[2][2] = {{0, 0}, {0, 0}};
int joy_button[2] = {0, 0};
int record_fd = 0, play_fd = 0;

// Replace include unistd.h to avoid a lot of warnings
ssize_t read(int fd, void *buf, size_t count);
ssize_t write(int fd, const void *buf, size_t count);
int close(int fd);

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
    fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0664);
    if (fd > 0) {
        write(fd, RAM_EX, 32768);
        close(fd);
    }
}

void save_state(int fd)
{
    int pos;

    write(fd, &Flag, 18 + 16 + 6);          // CPU
    write(fd, &battery, 1 + 1);
    pos = pBank0 - ROM;                     // BANKS
    write(fd, &pos, 4);
    pos = pBank1 - ROM;
    write(fd, &pos, 4);
    pos = pBank2 - ROM;
    write(fd, &pos, 4);
    pos = pBank2ROM - ROM;
    write(fd, &pos, 4);
    write(fd, RAM, 8192);                   // RAM
    if (battery)
        write(fd, RAM_EX, 32768);           // SRAM
    write(fd, &Nationalization, 1);         // IO
    write(fd, &rVol1, 24 + 9);              // PSG
    write(fd, &VDPStatus, 1 + 2 + 16433);   // VDP
}

void load_state(int fd)
{
    read(fd, &Flag, 18 + 16 + 6);           // CPU
    read(fd, &battery, 1 + 1 + 16);
    pBank0 += (unsigned)ROM;                // BANKS
    pBank1 += (unsigned)ROM;
    pBank2 += (unsigned)ROM;
    pBank2ROM += (unsigned)ROM;
    read(fd, RAM, 8192);                    // RAM
    if (battery)
        read(fd, RAM_EX, 32768);            // SRAM
    read(fd, &Nationalization, 1);          // IO
    read(fd, &rVol1, 24 + 9);               // PSG
    read(fd, &VDPStatus, 1 + 2 + 16433);    // VDP
}

int stop_record_play()
{
    if (record_fd > 0) {
        close(record_fd);
        record_fd = 0;
        message_timeout = SDL_GetTicks() + MESSAGE_TIME;
        snprintf(message, sizeof(message), "STOPPED RECORDING");
        return 1;
    }

    if (play_fd > 0) {
        close(play_fd);
        play_fd = 0;
        message_timeout = SDL_GetTicks() + MESSAGE_TIME;
        snprintf(message, sizeof(message), "STOPPED PLAYING");
        return 1;
    }

    return 0;
}

void record_game(int slot)
{
    char filename[FILENAME_MAX];

    if (stop_record_play())
        return;

    snprintf(filename, FILENAME_MAX, "%s.rec%d", rom_filename, slot);
    record_fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0664);
    if (record_fd > 0) {
        save_state(record_fd);
        message_timeout = SDL_GetTicks() + MESSAGE_TIME;
        snprintf(message, sizeof(message), "RECORDING GAME TO SLOT %d", slot);
    }
}

void play_game(int slot)
{
    char filename[FILENAME_MAX];

    if (stop_record_play())
        return;

    snprintf(filename, FILENAME_MAX, "%s.rec%d", rom_filename, slot);
    play_fd = open(filename, O_RDONLY);
    if (play_fd > 0) {
        load_state(play_fd);
        message_timeout = SDL_GetTicks() + MESSAGE_TIME;
        snprintf(message, sizeof(message), "PLAYING GAME FROM SLOT %d", slot);
    }
}

void save_game(int slot)
{
    int fd;
    char filename[FILENAME_MAX];

    if (stop_record_play())
        return;

    snprintf(filename, FILENAME_MAX, "%s.sa%d", rom_filename, slot);
    fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0664);
    if (fd > 0) {
        save_state(fd);
        close(fd);
        message_timeout = SDL_GetTicks() + MESSAGE_TIME;
        snprintf(message, sizeof(message), "GAME SAVED TO SLOT %d", slot);
    }
}

void load_game(int slot)
{
    int fd;
    char filename[FILENAME_MAX];

    if (stop_record_play())
        return;

    snprintf(filename, FILENAME_MAX, "%s.sa%d", rom_filename, slot);
    fd = open(filename, O_RDONLY);
    if (fd > 0) {
        load_state(fd);
        close(fd);
        message_timeout = SDL_GetTicks() + MESSAGE_TIME;
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
    if ((delta < 0 && cpu_delay_index > 0) || (delta > 0 && cpu_delay_index < sizeof(cpu_delay) / sizeof(cpu_delay[0]) - 1)) {
        cpu_delay_index += delta;
        message_timeout = SDL_GetTicks() + MESSAGE_TIME;
        snprintf(message, sizeof(message), "CPU SPEED %d%%", 1600 / cpu_delay[cpu_delay_index]);
    }
}

void get_controls()
{
    static int pause = 0, slow = 0, fast = 0;
    static int record_slot1 = 0, record_slot2 = 0, record_slot3 = 0, record_slot4 = 0;
    static int play_slot1 = 0, play_slot2 = 0, play_slot3 = 0, play_slot4 = 0;
    static int save_slot1 = 0, save_slot2 = 0, save_slot3 = 0, save_slot4 = 0;
    static int load_slot1 = 0, load_slot2 = 0, load_slot3 = 0, load_slot4 = 0;

    // Change CPU speed
    CHECK_STATE_KEY(SDL_SCANCODE_MINUS, slow, change_cpu_speed(1))
    CHECK_STATE_KEY(SDL_SCANCODE_EQUALS, fast, change_cpu_speed(-1))

    if (keys[SDL_SCANCODE_LSHIFT]) {
        // Record game
        CHECK_STATE_KEY(SDL_SCANCODE_F5, record_slot1, record_game(1))
        CHECK_STATE_KEY(SDL_SCANCODE_F6, record_slot2, record_game(2))
        CHECK_STATE_KEY(SDL_SCANCODE_F7, record_slot3, record_game(3))
        CHECK_STATE_KEY(SDL_SCANCODE_F8, record_slot4, record_game(4))

        // Play game
        CHECK_STATE_KEY(SDL_SCANCODE_F9, play_slot1, play_game(1))
        CHECK_STATE_KEY(SDL_SCANCODE_F10, play_slot2, play_game(2))
        CHECK_STATE_KEY(SDL_SCANCODE_F11, play_slot3, play_game(3))
        CHECK_STATE_KEY(SDL_SCANCODE_F12, play_slot4, play_game(4))
    } else {
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

    // Play a record game
    if (play_fd > 0) {
        if (read(play_fd, &Joy1, 2) == 2) {
            if (!(Joy2 & 0x20)) {
                Joy2 |= 0x20;
                int_NMI();
            }
            return;
        }

        close(play_fd);
        play_fd = 0;
        message_timeout = SDL_GetTicks() + MESSAGE_TIME;
        snprintf(message, sizeof(message), "FINISHED PLAYING");
    }

    Joy1 = Joy2 = 0xFF;

    // Joystick 1 (Keyboard)
    CHECK_KEY(SDL_SCANCODE_UP, Joy1, 0x01)
    CHECK_KEY(SDL_SCANCODE_DOWN, Joy1, 0x02)
    CHECK_KEY(SDL_SCANCODE_LEFT, Joy1, 0x04)
    CHECK_KEY(SDL_SCANCODE_RIGHT, Joy1, 0x08)
    CHECK_KEY(SDL_SCANCODE_Z, Joy1, 0x10)
    CHECK_KEY(SDL_SCANCODE_X, Joy1, 0x20)

    // Joystick 1
    if (joy1) {
        CHECK_AXIS(Joy1, 0, 0, 0x04, 0x08);
        CHECK_AXIS(Joy1, 0, 1, 0x01, 0x02);
        CHECK_BUTTON(Joy1, 0, 0x55555555, 0x10);
        CHECK_BUTTON(Joy1, 0, 0xAAAAAAAA, 0x20);
    }

    // Joystick 2 (Keyboard)
    CHECK_KEY(SDL_SCANCODE_KP_5, Joy1, 0x40)
    CHECK_KEY(SDL_SCANCODE_KP_2, Joy1, 0x80)
    CHECK_KEY(SDL_SCANCODE_KP_1, Joy2, 0x01)
    CHECK_KEY(SDL_SCANCODE_KP_3, Joy2, 0x02)
    CHECK_KEY(SDL_SCANCODE_N, Joy2, 0x04)
    CHECK_KEY(SDL_SCANCODE_M, Joy2, 0x08)

    // Joystick 2
    if (joy2) {
        CHECK_AXIS(Joy1, 1, 1, 0x40, 0x80);
        CHECK_AXIS(Joy2, 1, 0, 0x01, 0x02);
        CHECK_BUTTON(Joy2, 1, 0x55555555, 0x04);
        CHECK_BUTTON(Joy2, 1, 0xAAAAAAAA, 0x08);
    }

    // Reset button
    CHECK_KEY(SDL_SCANCODE_ESCAPE, Joy2, 0x10)

    // Record a game
    if (record_fd > 0) {
        if (!pause && keys[SDL_SCANCODE_SPACE] != pause)
            Joy2 &= ~0x20;
        write(record_fd, &Joy1, 2);
        Joy2 |= 0x20;
    }

    // Pause button
    CHECK_STATE_KEY(SDL_SCANCODE_SPACE, pause, int_NMI())
}

void draw_message(void *buffer, Uint32 tick)
{
    static char *recording = "REC", *playing = "PLAY";

    if (message_timeout > tick) {
        int x = VDPR & 0x20 ? 16 : 8;
        draw_text(buffer, x + 1, 9, message, 0x202020);
        draw_text(buffer, x, 8, message, 0xE0E0E0);
    }

    if (record_fd > 0) {
        draw_text(buffer, 229, 9, recording, 0x202020);
        draw_text(buffer, 228, 8, recording, 0xE00000);
    } else if (play_fd > 0) {
        draw_text(buffer, 222, 9, playing, 0x202020);
        draw_text(buffer, 221, 8, playing, 0xE00000);
    }
}

void main_loop()
{
    int done = 0, p;
    SDL_Event event;
    void *buffer;
    unsigned int t, t2;
    SDL_Rect rect = {8, 0, 256, 192};

    if (audio_present)
        SDL_PauseAudio(0);

    while (!done) {
        t = SDL_GetTicks();

        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT)
                done = 1;
            else if (event.type == SDL_JOYAXISMOTION) {
                if (event.jaxis.which < 2 && event.jaxis.axis < 2)
                    joy_axis[event.jaxis.which][event.jaxis.axis] = event.jaxis.value;
            }
            else if ((event.type == SDL_JOYBUTTONDOWN || event.type == SDL_JOYBUTTONUP) &&
                                                         event.jbutton.which < 2) {
                if (event.jbutton.state)
                    joy_button[event.jbutton.which] |= 1 << event.jbutton.button;
                else
                    joy_button[event.jbutton.which] &= ~(1 << event.jbutton.button);
            }
        }

        get_controls();
        SDL_LockTexture(texture, NULL, &buffer, &p);
        scan_frame(buffer);
        draw_message(buffer, t);
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

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_JOYSTICK | SDL_INIT_TIMER) < 0) {
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
    joy1 = SDL_JoystickOpen(0);
    joy2 = SDL_JoystickOpen(1);

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
    if (joy2)
        SDL_JoystickClose(joy2);
    if (joy1)
        SDL_JoystickClose(joy1);
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
