#include <stdint.h>
#include <string.h>
#include "vdp.h"
#include "cpu.h"
#include "log.h"
#include "ftdi.h"

#define DBG_TITLE "\033[1;33mVDP:\033[0m "

#define VRAM                vdp.VRAM
#define CRAM                vdp.CRAM
#define pRAM                vdp.pRAM
#define commandFF           vdp.commandFF
#define lowValue            vdp.lowValue
#define writePal            vdp.writePal
#define dataBuffer          vdp.dataBuffer
#define status              vdp.status
#define spriteSize          vdp.spriteSize
#define lineInt             vdp.lineInt

#define VDP0                vdp.VDP0
#define VDP1                vdp.VDP1
#define nameTable           vdp.nameTable
#define spriteAttrTable     vdp.spriteAttrTable
#define spritePatternTable  vdp.spritePatternTable
#define borderColor         vdp.borderColor
#define horizontalScroll    vdp.horizontalScroll
#define verticalScroll      vdp.verticalScroll
#define lineIntCounter      vdp.lineIntCounter

#define STATUS_INT          0x80
#define STATUS_OVR          0x40
#define STATUS_COL          0x20

#define TILE_HFLIP          0x0200
#define TILE_VFLIP          0x0400
#define TILE_PALETTE        0x0800
#define TILE_PRIORITY       0x1000

#define VDP0_VSCROLL        0x80
#define VDP0_HSCROLL        0x40
#define VDP0_HIDECOL        0x20
#define VDP0_IE1            0x10
#define VDP0_SHIFTSPR       0x08

#define VDP1_BLK            0x40
#define VDP1_IE0            0x20
#define VDP1_SIZE           0x02
#define VDP1_MAG            0x01

struct VDP vdp;
uint16_t *pNameTable = (uint16_t*)VRAM;
int VDPscanLine, VDPmaxSprites = 8, PALmode = 0;
uint8_t *pSpriteAttrTable = VRAM, spritePos[MAX_SPRITES], spriteCount;
uint32_t spritePattern[MAX_SPRITES], *pSpritePatternTable = (uint32_t*)VRAM;
uint32_t VDPpalette[64] = {
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

uint32_t *drawBlankLine(uint32_t *frameBuffer) {
    uint32_t color = CRAM[borderColor];

    for (int i = 0; i < 256; i++)
        *frameBuffer++ = color;

    return frameBuffer;
}


void searchSprites() {
    spriteCount = 0;
    for (int i = 0; i < 64 && pSpriteAttrTable[i] != 0xD0; i++) {
        uint8_t line = VDPscanLine - pSpriteAttrTable[i] - 1;
        if (line < spriteSize) {
            if (spriteCount == 8)
                status |= STATUS_OVR;

            if (spriteCount < VDPmaxSprites) {
                uint8_t index = pSpriteAttrTable[128 + 2 * i + 1];
                if (VDP1 & VDP1_SIZE)
                    index &= 0xFE;
                if (VDP1 & VDP1_MAG)
                    line >>= 1;

                int x = pSpriteAttrTable[128 + 2 * i];
                uint32_t pattern = pSpritePatternTable[index * 8 + line];
                if (VDP0 & VDP0_SHIFTSPR) {
                    x = x - 8;
                    while (x < 0) {
                        pattern = (pattern & 0x7F7F7F7F) << 1;
                        x++;
                    }
                }

                spritePos[spriteCount] = x;
                spritePattern[spriteCount++] = pattern;
            } else
                break;
        }
    }
}

uint8_t nextSpritePixel(int sprite) {
    uint8_t pixel = 0;

    if (spritePos[sprite] > 0)
        spritePos[sprite]--;
    else if (spritePattern[sprite]) {
        uint32_t tmp, index = (spritePattern[sprite] & 0x80808080) >> 7;
        spritePattern[sprite] = (spritePattern[sprite] & 0x7F7F7F7F) << 1;
        tmp = index >> 7;
        index |= tmp;
        tmp >>= 7;
        index |= tmp;
        tmp >>= 7;
        pixel = (index | tmp) & 0xF;
    }

   return pixel;
}

uint8_t nextSpritesPixel() {
    uint8_t pixels[MAX_SPRITES], count = 0;

    for (int i = 0; i < spriteCount; i++) {
        pixels[i] = nextSpritePixel(i);
        if (i < 8 && pixels[i])
            count++;
    }

    if (count > 1)
        status |= STATUS_COL;

    for (int i = 0; i < spriteCount; i++)
        if (pixels[i])
            return pixels[i];

    return 0;
}

uint32_t *drawScanLine(uint32_t *frameBuffer) {
    uint32_t *pPattern, pattern, name, tile = 0;
    uint32_t scanLineScrolled = VDPscanLine + verticalScroll;
    int hScroll = (VDP0 & VDP0_HSCROLL) && VDPscanLine < 16 ? 0 : horizontalScroll;
    int fine = hScroll % 8, column = 32 - hScroll / 8, step = 0;

    searchSprites();
    if (scanLineScrolled >= 224)
        scanLineScrolled -= 224;

    uint16_t *pName = pNameTable + (scanLineScrolled / 8 * 32);

    for (int i = 0; i < 256; i++) {
        uint8_t sprite = nextSpritesPixel();

        if (i == 24 * 8 && (VDP0 & VDP0_VSCROLL)) {
            scanLineScrolled = VDPscanLine;
            pName = pNameTable + (VDPscanLine / 8 * 32);
        }

        if (fine > 0)
            fine--;
        else {
            if (!step) {
                step = 8;
                name = pName[(column++) % 32];
                pPattern = (uint32_t*)&VRAM[(name & 0x1FF) * 32];
                pattern = name & TILE_VFLIP ? pPattern[7 - (scanLineScrolled % 8)] :
                    pPattern[scanLineScrolled % 8];
            }

            if (name & TILE_HFLIP) {
                tile = pattern & 0x01010101;
                pattern >>= 1;
            } else {
                tile = (pattern & 0x80808080) >> 7;
                pattern <<= 1;
            }

            uint32_t tmp = tile >> 7;
            tile |= tmp;
            tmp >>= 7;
            tile |= tmp;
            tmp >>= 7;
            tile = (tile | tmp) & 0xF;

            step--;
        }

        if (i < 8 && (VDP0 & VDP0_HIDECOL))
            *frameBuffer++ = CRAM[borderColor];
        else if (sprite && (!(name & TILE_PRIORITY) || ((name & TILE_PRIORITY) && !tile)))
            *frameBuffer++ = CRAM[sprite + 16];
        else
            *frameBuffer++ = CRAM[tile + (name & TILE_PALETTE ? 16 : 0)];
    }

    return frameBuffer;
}

#ifdef DRAW_TILES
void drawTiles(uint32_t *frameBuffer) {
    unsigned spriteStartIndex = (spritePatternTable & 0x04) << 6;
    for (int i = 0; i < 128; i++) {
        for (int j = 0; j < 32; j++) {
            unsigned pal = i / 8 * 32 + j >= spriteStartIndex ? 16 : 0;
            uint32_t pattern = *(uint32_t*)&VRAM[i / 8 * 1024 + j * 32 + (i % 8) * 4];
            for (int k = 0; k < 8; k++) {
                uint32_t tmp, index = (pattern & 0x80808080) >> 7;
                pattern <<= 1;
                tmp = index >> 7;
                index |= tmp;
                tmp >>= 7;
                index |= tmp;
                tmp >>= 7;
                index |= tmp;
                *frameBuffer++ = CRAM[pal + (index & 0xF)];
                //*frameBuffer++ = CRAM[index & 0xF];
            }
        }
    }
}
#endif

void renderFrame(uint32_t *frameBuffer) {
    uint8_t lineCounter;
    int firstScanLine = PALmode ? -70 : -43, scanLines = PALmode ? 313 : 262;

    VDPscanLine = firstScanLine;
    while (VDPscanLine < scanLines + firstScanLine) {
        if (VDPscanLine >= 0 && VDPscanLine < 192) {
            if (VDP1 & VDP1_BLK)
                frameBuffer = drawScanLine(frameBuffer);
            else
                frameBuffer = drawBlankLine(frameBuffer);
        }

        while (cpu.TClock < 228) {
            if ((VDP1 & VDP1_IE0 && status & STATUS_INT) || (VDP0 & VDP0_IE1 && lineInt))
                intZ80();
            executeNextOpcode();
        }
        cpu.TClock -= 228;

        VDPscanLine++;
        if (VDPscanLine == 0)
            lineCounter = lineIntCounter;
        else if (VDPscanLine == 193) {
            status |= STATUS_INT;
#ifdef DRAW_TILES
            drawTiles(frameBuffer);
#endif
            FTDI_FlushBuffer();
        }
        if (VDPscanLine >= 0 && VDPscanLine < 193) {
            if (!lineCounter) {
                lineInt = 1;
                lineCounter = lineIntCounter;
            } else
                lineCounter--;
        }
    }

}

uint8_t readVDPVertical() {
    DBG_PRINT("reading vertical %02X %d/%d\n", (uint8_t)VDPscanLine,  cpu.TClock, VDPscanLine);
    return (uint8_t)VDPscanLine;
}

uint8_t readVDPHorizontal() {
    DBG_PRINT("reading horizontal\n");
    return 0xFF;
}

uint8_t readVDPData() {
    uint8_t tmp = dataBuffer;

    commandFF = 0;
    dataBuffer = VRAM[pRAM];
    pRAM = (pRAM + 1) & 0x3FFF;

    return tmp;
}

uint8_t readVDPStatus() {
    uint8_t oldStatus = status;

    status = 0;
    lineInt = 0;
    commandFF = 0;
//    DBG_PRINT("reading status %02X\n", oldStatus);

    return oldStatus;
}

void writeVDPData(uint8_t value) {
    commandFF = 0;
    dataBuffer = value;

    if (writePal)
        CRAM[pRAM & 0x1F] = VDPpalette[value & 0x3F];
    else
        VRAM[pRAM] = value;

    pRAM = (pRAM + 1) & 0x3FFF;
}

void updateVDPregisters(uint8_t value) {
    switch (value & 0x0F) {
        // Mode control 1
        case 0:
            VDP0 = lowValue;
            DBG_PRINT("command #0 -> V:%d H:%d C0:%d IE1:%d EC:%d M4:%d M2:%d S:%d [%02X] %d/%d\n",
                VDP0 & 0x80 ? 1 : 0, VDP0 & 0x40 ? 1 : 0, VDP0 & 0x20 ? 1 : 0, VDP0 & 0x10 ? 1 : 0,
                VDP0 & 0x08 ? 1 : 0, VDP0 & 0x04 ? 1 : 0, VDP0 & 0x02 ? 1 : 0, VDP0 & 0x01, VDP0,
                cpu.TClock, VDPscanLine);
            break;

        // Mode control 2
        case 1:
            VDP1 = lowValue;
            if ((lowValue & (VDP1_SIZE | VDP1_MAG)) == (VDP1_SIZE | VDP1_MAG))
                spriteSize = 32;
            else if (lowValue & (VDP1_SIZE | VDP1_MAG))
                spriteSize = 16;
            else
                spriteSize = 8;
            DBG_PRINT("command #1 -> BL:%d IE0:%d M1:%d M3:%d SIZE:%d MAG:%d [%02X] %d/%d\n",
                VDP1 & 0x40 ? 1 : 0, VDP1 & 0x20 ? 1 : 0, VDP1 & 0x10 ? 1 : 0, VDP1 & 0x08 ? 1 : 0,
                VDP1 & 0x02 ? 1 : 0, VDP1 & 0x01, VDP1, cpu.TClock, VDPscanLine);
            break;

        // Name table
        case 2:
            nameTable = lowValue;
            pNameTable = (uint16_t*)&VRAM[(lowValue & 0x0E) << 10];
            DBG_PRINT("command #2 -> name table %04X [%02X] %d/%d\n", (lowValue & 0x0E) << 10,
                lowValue, cpu.TClock, VDPscanLine);
            break;

        // Color table (not used ???)
        case 3:
            DBG_PRINT("command #3 -> color table [%02X] %d/%d\n", lowValue, cpu.TClock, VDPscanLine);
            break;

        // Tile pattern generator (not used ???)
        case 4:
            DBG_PRINT("command #4 -> tile pattern table [%02X] %d/%d\n", lowValue, cpu.TClock, VDPscanLine);
            break;

        // Sprite attribute table
        case 5:
            spriteAttrTable = lowValue;
            pSpriteAttrTable = &VRAM[(lowValue & 0x7E) << 7];
            DBG_PRINT("command #5 -> sprite attribute table %04X [%02X] %d/%d\n",
                (lowValue & 0x7E) << 7, lowValue, cpu.TClock, VDPscanLine);
            break;

        // Sprite pattern generator
        case 6:
            spritePatternTable = lowValue;
            pSpritePatternTable = (uint32_t*)&VRAM[(lowValue & 0x04) << 11];
            DBG_PRINT("command #6 -> sprite pattern table %04X [%02X] %d/%d\n",
                (lowValue & 0x04) << 11, lowValue, cpu.TClock, VDPscanLine);
            break;

        // Background color
        case 7:
            borderColor = (lowValue & 0x0F) + 16;
            DBG_PRINT("command #7 -> background color [%02X] %d/%d\n", lowValue, cpu.TClock, VDPscanLine);
            break;

        // Background horizontal scroll
        case 8:
            horizontalScroll = lowValue;
            DBG_PRINT("command #8 -> horizontal scroll [%02X] %d/%d\n", lowValue, cpu.TClock, VDPscanLine);
            break;

        // Background vertical scroll
        case 9:
            verticalScroll = lowValue;
            DBG_PRINT("command #9 -> vertical scroll [%02X] %d/%d\n", lowValue, cpu.TClock, VDPscanLine);
            break;

        // Line counter (line interrupt)
        case 10:
            lineIntCounter = lowValue;
            DBG_PRINT("command #10 -> line counter [%02X] %d/%d\n", lowValue, cpu.TClock, VDPscanLine);
            break;

        default:
            DBG_PRINT("writing to invalid register #%d [%02X]\n", value & 0x0F, lowValue);
    }
}

void writeVDPCommand(uint8_t value) {
    if (commandFF) {
        uint8_t mode = value & 0xC0;

        writePal = mode == 0xC0;
        pRAM = ((value & 0x3F) << 8) | lowValue;

        if (mode == 0x80)
            updateVDPregisters(value);
        else {
            if (writePal) {
                DBG_PRINT("CRAM pointer %d\n", pRAM & 0x1F);
            } else
                DBG_PRINT("VRAM pointer %04X %c\n", pRAM, value & 0x40 ? 'W' : 'R');

            if (mode == 0x00) {
                dataBuffer = VRAM[pRAM];
                pRAM = (pRAM + 1) & 0x3FFF;
                for (int i = 0; i < 8; i++)
                    FTDI_WriteBuffer(0x40, 0);
            }
        }
    } else {
        lowValue = value;
        pRAM = (pRAM & 0x3F00) | value;
    }

    commandFF = !commandFF;
}
