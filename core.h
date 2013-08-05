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
