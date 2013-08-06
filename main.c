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
#include <SDL/SDL.h>
#include "core.h"

Uint8 *keys;
SDL_Surface *screen;
void init_battery() {}

int open_ROM(char *filename)
{
	FILE *fd = fopen(filename, "rb");
	int size = fread(ROM, 512, 2048, fd);
	fclose(fd);

	if (size & 1)
		memcpy(ROM, ROM + 0x200, 512 * (--size));

	init_banks(size / 32);

	return 1;
}

void get_controls()
{
	Joy1 = 0xFF;
	Joy2 = 0xFF;

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
}

void run()
{
	reset_CPU();
	reset_VDP();
	reset_PSG();

	unsigned int t, t2;
	while (!keys[SDLK_ESCAPE]) {
		t = SDL_GetTicks();
		get_controls();
		scan_frame();
		write_frame(screen->pixels, screen->format->BitsPerPixel);
		SDL_Flip(screen);
		SDL_PumpEvents();
		t2 = SDL_GetTicks();
		if (t2 - t < 16)
			SDL_Delay(16 - t2 + t);
	}
}

int main(int argc, char **argv)
{
	if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_TIMER | SDL_INIT_AUDIO) < 0) {
		printf("Error initializing SDL: %s\n", SDL_GetError());
		return 0;
	}

	SDL_AudioSpec wanted;
	wanted.freq = 44160;
	wanted.format = AUDIO_U8;
	wanted.channels = 1;
	wanted.samples = 736 * 2;
	wanted.callback = make_PSG;
	wanted.userdata = NULL;

	if (SDL_OpenAudio(&wanted, NULL) < 0) {
		printf("Couldn't open audio: %s\n", SDL_GetError());
		return 0;
	}

	keys = SDL_GetKeyState(NULL);
	screen = SDL_SetVideoMode(256, 192, 0, SDL_HWSURFACE | SDL_DOUBLEBUF);

	ROM = (unsigned char *)malloc(64 * 16384);
	open_ROM(argv[1]);

	SDL_PauseAudio(0);
	run();
	SDL_PauseAudio(1);

	SDL_CloseAudio();
	SDL_Quit();

	return 0;
}
