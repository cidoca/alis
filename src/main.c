#include <getopt.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "cpu.h"
#include "memory.h"
#include "vdp.h"
#include "psg.h"
#include "sdl.h"
#include "ftdi.h"

void printHelp(const char *argv0) {
    printf("Usage: %s [options] <rom file>\n"
           "Options:\n"
           "  -h        Display this information\n"
           "  -p        PAL mode\n"
           "  -s        Show up to %d sprites per scanline\n"
#ifdef FTDI
           "  --ftdi        Send VDP data directly to an external VDP/FPGA\n"
#endif
        , argv0, MAX_SPRITES);
    exit(1);
}

void parserCmdLine(int argc, char **argv) {
    int c;

    while ((c = getopt(argc, argv, ":hps")) != -1) {
        switch (c) {
            case 'p':
                PALmode = 1;
                break;
            case 's':
                VDPmaxSprites = MAX_SPRITES;
                break;
            default:
                printf("Invalid parameter '%c' !!!\n", optopt);
            case 'h':
                printHelp(argv[0]);
        }
    }

    if (optind < argc)
        strncpy(ROMfilename, argv[optind], sizeof(ROMfilename) - 1);
    else
        printHelp(argv[0]);
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
