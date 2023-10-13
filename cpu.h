struct CPU {
    uint8_t regs[8], regs2[8];
    uint8_t rFlags, rFlags2;
    uint8_t rI, rR, rRhigh, halt, IFF1, IFF2, im;
    unsigned rPC, TClock, rSP, rIX, rIY;
};

extern struct CPU cpu;

void resetCPU();
void intZ80();
void executeNextOpcode();

#define regs    cpu.regs
#define regs2   cpu.regs2
#define rFlags  cpu.rFlags
#define rFlags2 cpu.rFlags2
#define rI      cpu.rI
#define rR      cpu.rR
#define rRhigh  cpu.rRhigh
#define halt    cpu.halt
#define IFF1    cpu.IFF1
#define IFF2    cpu.IFF2
#define im      cpu.im
#define rPC     cpu.rPC
#define TClock  cpu.TClock
#define rSP     cpu.rSP
#define rIX     cpu.rIX
#define rIY     cpu.rIY

