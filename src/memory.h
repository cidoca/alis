#include <stdint.h>

struct MEMORY {
    uint8_t battery, frameConfig[4];
    uint8_t RAM[8 * 1024];
};

extern struct MEMORY mem;
extern char ROMfilename[128];
extern uint8_t RAM_EX[32 * 1024];

const uint8_t readMemory(unsigned address);
void writeMemory(unsigned address, uint8_t value);
void loadROM();
void initBattery();
void saveBattery();
void save_load_game(int slot);
