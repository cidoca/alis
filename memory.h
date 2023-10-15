struct MEMORY {
    uint8_t bankMask, frameConfig[4];
    uint8_t RAM[8 * 1024], RAM_EX[32 * 1024];
};

extern struct MEMORY mem;

const uint8_t readMemory(unsigned address);
void writeMemory(unsigned address, uint8_t value);
void loadROM(const char *fileName);
