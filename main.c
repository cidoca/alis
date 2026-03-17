#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "cpu.h"
#include "memory.h"
#include "vdp.h"
#include "psg.h"
#include "sdl.h"
#include "ftdi.h"

void printHelp() {
    printf("Usage: alis [options] <rom file>\n"
           "Options:\n"
           "  -h            Display this information\n"
           "  --pal         PAL mode\n"
           "  --sprites     Show up to %d sprites per scanline\n"
#ifdef FTDI
           "  --ftdi        Send VDP data directly to an external VDP/FPGA\n"
#endif
        , MAX_SPRITES);
    exit(1);
}

void parserCmdLine(int argc, char **argv) {
    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "-h")) {
            printHelp();
        } else if (!strcmp(argv[i], "--pal")) {
            PALmode = 1;
        } else if (!strcmp(argv[i], "--sprites")) {
            VDPmaxSprites = MAX_SPRITES;
#ifdef FTDI
        } else if (!strcmp(argv[i], "--ftdi")) {
            FTDI_Enabled();
#endif
        } else if (argv[i][0] == '-') {
            printf("** Command line option '%s' not valid! **\n", argv[i]);
            printHelp();
        } else if (!ROMfilename[0]) {
            strncpy(ROMfilename, argv[i], sizeof(ROMfilename) - 1);
        }
    }

    if (!ROMfilename[0])
        printHelp();
}

int main(int argc, char **argv) {
    parserCmdLine(argc, argv);

    loadROM();
    initBattery();
    FTDI_Open();

    resetCPU();
    resetVDP();
    resetPSG();

    SDLinit();
    SDLmainLoop();
    SDLdeinit();

    saveBattery();
    FTDI_Close();

    return 0;
}
