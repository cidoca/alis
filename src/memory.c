#include <fcntl.h>
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#include "cpu.h"
#include "memory.h"
#include "psg.h"
#include "vdp.h"
#include "log.h"

#undef DBG_PRINT
#define DBG_PRINT(f, ...) {}
#define DBG_TITLE "\033[1;34mMEMORY:\033[0m "

#define RAM             mem.RAM
#define frameConfig     mem.frameConfig
#define battery         mem.battery

#define FRAME2_RAM      0x08    // 0 = ROM, 1 = RAM
#define FRAME2_BANK1    0x04    // 0 = bank0, 1 = bank1

struct MEMORY mem;
char ROMfilename[128] = "";
uint8_t ROM[1024 * 1024], RAM_EX[32 * 1024];
uint8_t *pBank0 = ROM, *pBank1 = ROM, *pBank2 = ROM, *pBank2ROM = ROM;

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
                unsigned offset = (value & 0x3F) << 14;

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

    battery = 0;
    writeMemory(0xFFFC, 0);
    writeMemory(0xFFFD, 0);
    writeMemory(0xFFFE, 1);
    writeMemory(0xFFFF, 2);

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
        if (read(fd, RAM_EX, 32768) == 32768)
            printf("Saved battery found and restored!\n");
        else
            printf("Error trying to restore saved battery!\n");
        close(fd);
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
        if (write(fd, RAM_EX, 32768) == 32768)
            printf("Save battery updated!\n");
        else
            printf("Error trying to save the battery!\n");
        close(fd);
    }
}

void save_game(int slot) {
    int fd;
    char filename[FILENAME_MAX];

    snprintf(filename, FILENAME_MAX, "%s.sa%d", ROMfilename, slot);
    fd = open(filename, O_CREAT | O_TRUNC | O_WRONLY, 0664);
    if (fd > 0) {
        if (write(fd, &cpu, sizeof(cpu)) != sizeof(cpu)) goto error_saving;
        if (write(fd, &psg, sizeof(psg)) != sizeof(psg)) goto error_saving;
        if (write(fd, &vdp, sizeof(vdp)) != sizeof(vdp)) goto error_saving;
        if (write(fd, &mem, sizeof(mem)) != sizeof(mem)) goto error_saving;
        if (battery)
            if (write(fd, RAM_EX, sizeof(RAM_EX)) != sizeof(RAM_EX)) goto error_saving;

        close(fd);
        return;
    }

error_saving:
    printf("Not possible to save game in %s\n", filename);
    if (fd > 0)
        close(fd);
}

#undef battery

void load_game(int slot) {
    int fd;
    char filename[FILENAME_MAX];
    struct CPU cpu_tmp;
    struct PSG psg_tmp;
    struct VDP vdp_tmp;
    struct MEMORY mem_tmp;
    char ram_ex_tmp[sizeof(RAM_EX)];

    snprintf(filename, FILENAME_MAX, "%s.sa%d", ROMfilename, slot);
    fd = open(filename, O_RDONLY);
    if (fd > 0) {
        if (read(fd, &cpu_tmp, sizeof(cpu_tmp)) != sizeof(cpu_tmp)) goto error_loading;
        if (read(fd, &psg_tmp, sizeof(psg_tmp)) != sizeof(psg_tmp)) goto error_loading;
        if (read(fd, &vdp_tmp, sizeof(vdp_tmp)) != sizeof(vdp_tmp)) goto error_loading;
        if (read(fd, &mem_tmp, sizeof(mem_tmp)) != sizeof(mem_tmp)) goto error_loading;
        if (mem_tmp.battery)
            if (read(fd, ram_ex_tmp, sizeof(ram_ex_tmp)) != sizeof(ram_ex_tmp)) goto error_loading;

        close(fd);

        memcpy(&cpu, &cpu_tmp, sizeof(cpu));
        memcpy(&psg, &psg_tmp, sizeof(psg));
        memcpy(&vdp, &vdp_tmp, sizeof(vdp));
        memcpy(&mem, &mem_tmp, sizeof(mem));
        if (mem_tmp.battery)
            memcpy(&RAM_EX, &ram_ex_tmp, sizeof(RAM_EX));

        writeMemory(0xFFFC, frameConfig[0]);
        writeMemory(0xFFFD, frameConfig[1]);
        writeMemory(0xFFFE, frameConfig[2]);
        writeMemory(0xFFFF, frameConfig[3]);

        updateVDPafterLoading();

        return;
    }

error_loading:
    printf("Not possible to load game in %s\n", filename);
    if (fd > 0)
        close(fd);
}

void save_load_game(int slot) {
    if (slot < 4)
        save_game(slot);
    else
        load_game(slot - 4);
}