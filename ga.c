#include <stdint.h>
#include "log.h"

#define DBG_TITLE "\033[1;35mGA:\033[0m "

uint8_t joyP1 = 0xFF, joyP2 = 0xFF;

uint8_t readGAJoyP1() {
    return joyP1;
}

uint8_t readGAJoyP2() {
    return joyP2;
}

void writeGAMemoryControl(uint8_t value) {
    DBG_PRINT("writing %02X to memory control\n", value);
}

void writeGAJoyControl(uint8_t value) {
    DBG_PRINT("writing %02X to joy control\n", value);
}
