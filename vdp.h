struct VDP {
    uint8_t VRAM[16 * 1024];
    uint8_t commandFF, lowValue, mode;
    uint8_t VDP0, VDP1, horizontalScroll, verticalScroll, lineCounter;
    unsigned CRAM[32], pRAM, nameTable, spriteAttrTable, spritePatternTable, backgroundColor;
};

extern struct VDP vdp;

void resetVDP();
uint8_t readVDPVertical();
uint8_t readVDPHorizontal();
uint8_t readVDPData();
uint8_t readVDPStatus();
void writeVDPData(uint8_t value);
void writeVDPCommand(uint8_t value);
