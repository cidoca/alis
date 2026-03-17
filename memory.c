#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include "memory.h"
#include "log.h"

#undef DBG_PRINT
#define DBG_PRINT(f, ...) {}
#define DBG_TITLE "\033[1;34mMEMORY:\033[0m "

#define RAM         mem.RAM
#define RAM_EX      mem.RAM_EX
#define battery     mem.battery
#define bankMask    mem.bankMask
#define frameConfig mem.frameConfig

#define FRAME2_RAM      0x08    // 0 = ROM, 1 = RAM
#define FRAME2_BANK1    0x04    // 0 = bank0, 1 = bank1

struct MEMORY mem;
uint8_t ROM[1024 * 1024];
uint8_t *pBank0 = ROM, *pBank1 = ROM, *pBank2 = ROM, *pBank2ROM = ROM;
char ROMfilename[128] = "";

const uint8_t readMemory(unsigned address) {
    if (address < 0x0400)
        return ROM[address];
    if (address < 0x4000)
        return pBank0[address];
    if (address < 0x8000)
        return pBank1[address];
    if (address < 0xC000)
        return pBank2[address];

    return RAM[address & 0x1FFF];
}

void writeMemory(unsigned address, uint8_t value) {
    // Invalid area
    if (address < 0x8000) {
        DBG_PRINT("invalid writing %02X to %04X\n", value, address);

    // External RAM on Frame 2
    } else if (address < 0xC000) {
        if (frameConfig[0] & FRAME2_RAM)
            pBank2[address] = value;
        else
            DBG_PRINT("invalid writing %02X to %04X\n", value, address);

    // RAM and Frame configuration
    } else {
        RAM[address & 0x1FFF] = value;

        if (address >= 0xFFFC) {
            frameConfig[address & 0x03] = value;

            if (address == 0xFFFC) {
                if (value & FRAME2_RAM) {
                    battery = 1;
                    pBank2 = RAM_EX - (value & FRAME2_BANK1 ? 0x4000 : 0x8000);
                } else
                    pBank2 = pBank2ROM;
                if (value & 0xF3)
                    DBG_PRINT("extra bits %02X in Frame control register %04X\n", value, address);
            } else {
                unsigned offset = (value & bankMask) << 14;

                if (address == 0xFFFD)
                    pBank0 = ROM + offset;
                else if (address == 0xFFFE)
                    pBank1 = ROM + offset - 0x4000;
                else {
                    pBank2ROM = ROM + offset - 0x8000;
                    if (!(frameConfig[0] & FRAME2_RAM))
                        pBank2 = pBank2ROM;
                }
                if (value & 0xE0)
                    DBG_PRINT("extra bits %02X in Frame control register %04X\n", value, address);
            }
        }
    }
}

void loadROM() {
    int fd;
    ssize_t size;
    struct stat buf;

    printf("Loading ROM \"%s\" ", ROMfilename);
    fflush(stdout);

    fd = open(ROMfilename, O_RDONLY);
    if (fd == -1 || fstat(fd, &buf)) {
        printf("- ERROR: could not open!!!!\n");
        exit(1);
    }

    printf("(%dKb) ... ", (unsigned)buf.st_size / 1024);
    fflush(stdout);

    size = read(fd, ROM, 1024 * 1024);
    close(fd);

    if (size != buf.st_size) {
        printf("ERROR: could not read!!!\n");
        exit(1);
    }

    if (size & 0x200)
        memcpy(ROM, ROM + 512, size - 512);
    bankMask = (size / 16384) - 1;
    *(uint32_t*)&frameConfig = 0x02010000;

    battery = 0;
    char *ext = strrchr(ROMfilename, '.');
    if (ext)
        *ext = 0;

    printf("OK\n");
}

void initBattery()
{
    int fd;
    char filename[FILENAME_MAX];

    strcpy(filename, ROMfilename);
    strcat(filename, ".srm");
    fd = open(filename, O_RDONLY);
    if (fd > 0) {
        read(fd, RAM_EX, 32768);
        close(fd);
        printf("Save battery found and restored!\n");
    }
}

void saveBattery()
{
    int fd;
    char filename[FILENAME_MAX];

    if (!battery)
        return;

    strcpy(filename, ROMfilename);
    strcat(filename, ".srm");
    fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0664);
    if (fd > 0) {
        write(fd, RAM_EX, 32768);
        close(fd);
        printf("Save battery updated!\n");
    }
}
