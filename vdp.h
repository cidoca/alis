//#define DRAW_TILES

struct VDP {
    uint8_t VRAM[16 * 1024];
    uint8_t commandFF, lowValue, dataBuffer, writePal, lineInt, status;
    uint8_t VDP0, VDP1, nameTable, spriteAttrTable, spritePatternTable;
    uint8_t borderColor, horizontalScroll, verticalScroll, lineIntCounter;
    uint32_t CRAM[32], pRAM;
};

extern struct VDP vdp;
extern int VDPscanLine;

void resetVDP();
void renderFrame(uint32_t *frameBuffer);
uint8_t readVDPVertical();
uint8_t readVDPHorizontal();
uint8_t readVDPData();
uint8_t readVDPStatus();
void writeVDPData(uint8_t value);
void writeVDPCommand(uint8_t value);
