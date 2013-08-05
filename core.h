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

// Banks
void init_banks(int ROM_size);
extern unsigned char battery, *ROM, RAM[], RAM_EX[];

// CPU
void reset_CPU();
void int_NMI();

// IO
extern unsigned char Joy1, Joy2;

// PSG
void reset_PSG();
void make_PSG();
extern unsigned char *SoundBuffer;

// VDP
void reset_VDP();
void scan_frame();

// Surface
void write_frame(void *surface, int bpp);
