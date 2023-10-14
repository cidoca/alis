#include <stdio.h>
#include <stdint.h>
#include "log.h"

#define DBG_TITLE "\033[1;34mMEMORY:\033[0m "

#define FRAME2_RAM      0x08    // 0 = ROM, 1 = RAM
#define FRAME2_BANK1    0x04    // 0 = bank0, 1 = bank1

uint8_t bankMask, frameConfiguration[4] = { 0, 0, 1, 2 };
uint8_t RAM[8 * 1024], RAM_EX[32 * 1024], ROM[1024 * 1024];
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
    if (address >= 0xFFFC)
        return frameConfiguration[address & 0x03];

    return RAM[address & 0x1FFF];
}

void writeMemory(unsigned address, uint8_t value) {
    if (address < 0x8000) {         // Frame 0 and 1 (invalid)
        DBG_PRINT("invalid writing %02X to %04X\n", value, address);
    } else if (address < 0xC000) {  // Frame 2
        if (frameConfiguration[0] & FRAME2_RAM)
            pBank2[address] = value;
        else
            DBG_PRINT("invalid writing %02X to %04X\n", value, address);
    } else if (address >= 0xFFFC) {
        if (address == 0xFFFC) {    // Frame 2 RAM Control Register
            frameConfiguration[0] = value;
            if (value & FRAME2_RAM)          // Activate RAM_EX on Frame 2
                pBank2 = RAM_EX - (value & FRAME2_BANK1 ? 0x4000 : 0x8000);
            else                    // Restore ROM on Frame 2
                pBank2 = pBank2ROM;
            if (value & 0xF3)
                DBG_PRINT("extra bits %02X in Frame control register %04X\n", value, address);
        } else {
            unsigned offset = (value & bankMask) << 14;

            frameConfiguration[address & 0x03] = value;
            if (address == 0xFFFD)
                pBank0 = ROM + offset;
            else if (address == 0xFFFE)
                pBank1 = ROM + offset - 0x4000;
            else {
                pBank2ROM = ROM + offset - 0x8000;
                if (!(frameConfiguration[0] & FRAME2_RAM))
                    pBank2 = pBank2ROM;
            }
            if (value & 0xE0)
                DBG_PRINT("extra bits %02X in Frame control register %04X\n", value, address);
        }
    } else                          // RAM
        RAM[address & 0x1FFF] = value;
}
