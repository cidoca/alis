#include <stdint.h>
#include <string.h>
#include "vdp.h"
#include "log.h"

#define DBG_TITLE "\033[1;33mVDP:\033[0m "

#define VRAM                vdp.VRAM
#define CRAM                vdp.CRAM
#define commandFF           vdp.commandFF
#define lowValue            vdp.lowValue
#define mode                vdp.mode
#define lineCounter         vdp.lineCounter
#define VDP0                vdp.VDP0
#define VDP1                vdp.VDP1
#define horizontalScroll    vdp.horizontalScroll
#define verticalScroll      vdp.verticalScroll
#define pRAM                vdp.pRAM
#define nameTable           vdp.nameTable
#define spriteAttrTable     vdp.spriteAttrTable
#define spritePatternTable  vdp.spritePatternTable
#define backgroundColor     vdp.backgroundColor

struct VDP vdp;

unsigned VDPpalette[64] = {
    0x000000, 0x550000, 0xAA0000, 0xFF0000, 0x005500, 0x555500, 0xAA5500, 0xFF5500,
    0x00AA00, 0x55AA00, 0xAAAA00, 0xFFAA00, 0x00FF00, 0x55FF00, 0xAAFF00, 0xFFFF00,
    0x000055, 0x550055, 0xAA0055, 0xFF0055, 0x005555, 0x555555, 0xAA5555, 0xFF5555,
    0x00AA55, 0x55AA55, 0xAAAA55, 0xFFAA55, 0x00FF55, 0x55FF55, 0xAAFF55, 0xFFFF55,
    0x0000AA, 0x5500AA, 0xAA00AA, 0xFF00AA, 0x0055AA, 0x5555AA, 0xAA55AA, 0xFF55AA,
    0x00AAAA, 0x55AAAA, 0xAAAAAA, 0xFFAAAA, 0x00FFAA, 0x55FFAA, 0xAAFFAA, 0xFFFFAA,
    0x0000FF, 0x5500FF, 0xAA00FF, 0xFF00FF, 0x0055FF, 0x5555FF, 0xAA55FF, 0xFF55FF,
    0x00AAFF, 0x55AAFF, 0xAAAAFF, 0xFFAAFF, 0x00FFFF, 0x55FFFF, 0xAAFFFF, 0xFFFFFF
};

void resetVDP() {
    memset(&vdp, 0, sizeof(vdp));
}

uint8_t readVDPVertical() {
   DBG_PRINT("reading vertical\n");
   return 0xFF;
}

uint8_t readVDPHorizontal() {
    DBG_PRINT("reading horizontal\n");
    return 0xFF;
}

uint8_t readVDPData() {
    DBG_PRINT("reading data\n");
    return 0xFF;
}

uint8_t readVDPStatus() {
    DBG_PRINT("reading status\n");
    return 0x00;
}

void writeVDPData(uint8_t value) {
    if (mode == 0x40)        // VRAM
        VRAM[pRAM] = value;
    else if (mode == 0xC0) { // CRAM
        CRAM[pRAM & 0x1F] = VDPpalette[value & 0x3F];
    } else
        DBG_PRINT("writing data %02X to invalid mode %02X\n", value, mode);

    pRAM = (pRAM + 1) & 0x3FFF;
}

void updateVDPregisters(uint8_t value) {
    switch (value & 0x0F) {
        // Mode control 1
        case 0:
            VDP0 = lowValue;
            DBG_PRINT("command #0 [%02X] -> V:%d H:%d C0:%d IE1:%d EC:%d M4:%d M2:%d S:%d\n", VDP0,
                VDP0 & 0x80 ? 1 : 0, VDP0 & 0x40 ? 1 : 0, VDP0 & 0x20 ? 1 : 0, VDP0 & 0x10 ? 1 : 0,
                VDP0 & 0x08 ? 1 : 0, VDP0 & 0x04 ? 1 : 0, VDP0 & 0x02 ? 1 : 0, VDP0 & 0x01);
            break;

        // Mode control 2
        case 1:
            VDP1 = lowValue;
            DBG_PRINT("command #1 [%02X] -> BL:%d IE0:%d M1:%d M3:%d SIZE:%d MAG:%d\n", VDP1,
                VDP1 & 0x40 ? 1 : 0, VDP1 & 0x20 ? 1 : 0, VDP1 & 0x10 ? 1 : 0, VDP1 & 0x08 ? 1 : 0,
                VDP1 & 0x02 ? 1 : 0, VDP1 & 0x01);
            break;

        // Name table
        case 2:
            nameTable = (lowValue & 0x0E) << 10;
            DBG_PRINT("command #2 [%02X] -> name table %04X\n", lowValue, nameTable);
            break;

        // Color table (not used ???)
        case 3:
            DBG_PRINT("command #3 [%02X] -> color table\n", lowValue);
            break;

        // Tile pattern generator (not used ???)
        case 4:
            DBG_PRINT("command #4 [%02X] -> tile pattern table\n", lowValue);
            break;

        // Sprite attribute table
        case 5:
            spriteAttrTable = (lowValue & 0x7E) << 7;
            DBG_PRINT("command #5 [%02X] -> sprite attribute table %04X\n", lowValue, spriteAttrTable);
            break;

        // Sprite pattern generator
        case 6:
            spritePatternTable = (lowValue & 0x04) << 11;
            DBG_PRINT("command #6 [%02X] -> sprite pattern table %04X\n", lowValue, spritePatternTable);
            break;

        // Background color
        case 7:
            backgroundColor = VDPpalette[lowValue & 0x0F];
            DBG_PRINT("command #7 [%02X] -> background color %06X\n", lowValue, backgroundColor);
            break;

        // Background horizontal scroll
        case 8:
            horizontalScroll = lowValue;
            DBG_PRINT("command #8 [%02X] -> horizontal scroll %02X\n", lowValue, horizontalScroll);
            break;

        // Background vertical scroll
        case 9:
            verticalScroll = lowValue;
            DBG_PRINT("command #9 [%02X] -> vertical scroll %02X\n", lowValue, verticalScroll);
            break;

        // Line counter (line interrupt)
        case 10:
            lineCounter = lowValue;
            DBG_PRINT("command #10 [%02X] -> line counter %02X\n", lowValue, lineCounter);
            break;

        default:
            DBG_PRINT("writing to invalid register %d\n", value & 0x0F);
    }
}

void updateCRAMpointer() {
    pRAM = lowValue & 0x1F;
    DBG_PRINT("CRAM pointer %d\n", pRAM);
}

void updateVRAMpointer(uint8_t value) {
    pRAM = ((value & 0x3F) << 8) | lowValue;
    DBG_PRINT("VRAM pointer %04X %c\n", pRAM, value & 0x40 ? 'W' : 'R');
}

void writeVDPCommand(uint8_t value) {
    if (commandFF) {         // Second write
        mode = value & 0xC0;
        if (mode == 0xC0)
            updateCRAMpointer();
        else if (mode == 0x80)
            updateVDPregisters(value);
        else
            updateVRAMpointer(value);
    } else                      // First write
        lowValue = value;

    commandFF = !commandFF;
}
