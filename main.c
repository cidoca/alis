#include <stdint.h>
#include "cpu.h"
#include "memory.h"
#include "vdp.h"

int main(int argc, char **argv) {
    loadROM(argv[1]);

    resetCPU();
    resetVDP();
    for (int i = 0; i < 16384; i++)
        executeNextOpcode();

    return 0;
}
