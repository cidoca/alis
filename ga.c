#include <stdint.h>
#include "log.h"

#define DBG_TITLE "\033[1;35mGA:\033[0m "

uint8_t readGAJoyP1() {
    DBG_PRINT("reading P1\n");
    return 0xFF;
}

uint8_t readGAJoyP2() {
    DBG_PRINT("reading P2\n");
    return 0xFF;
}

void writeGAMemoryControl(uint8_t value) {
    DBG_PRINT("writing %02X to memory control\n", value);
}

void writeGAJoyControl(uint8_t value) {
    DBG_PRINT("writing %02X to joy control\n", value);
}
