#include <stdint.h>
#include "log.h"

#define DBG_TITLE "\033[1;33mVDP:\033[0m "

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
    DBG_PRINT("writing data %02X\n", value);
}

void writeVDPCommand(uint8_t value) {
    DBG_PRINT("writing command %02X\n", value);
}
