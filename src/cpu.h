#include <stdint.h>

struct CPU {
    uint8_t regs[8], regs2[8];
    uint8_t rFlags, rFlags2;
    uint8_t rI, rR, rRhigh, halt, IFF1, IFF2, im;
    unsigned rPC, TClock, rSP, rIX, rIY;
};

extern struct CPU cpu;

void resetCPU();
void intZ80();
void intNMI();
void executeNextOpcode();

