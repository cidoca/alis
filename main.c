#include <stdint.h>
#include "cpu.h"
#include "memory.h"
#include "vdp.h"
#include "psg.h"
#include "sdl.h"

int main(int argc, char **argv) {
    loadROM(argv[1]);

    resetCPU();
    resetVDP();
    resetPSG();

    SDLinit();
    SDLmainLoop();
    SDLdeinit();

    return 0;
}
