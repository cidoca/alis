#include <stdint.h>
#include "log.h"

#undef DBG_PRINT
#define DBG_PRINT(f, ...) {}
#define DBG_TITLE "\033[1;35mGA:\033[0m "

uint8_t nationalization = 0x00, joyP1 = 0xFF, joyP2 = 0xFF;

uint8_t readGAJoyP1() {
    return joyP1;
}

uint8_t readGAJoyP2() {
    uint8_t mask = 0xFF;

    if (!(nationalization & 0x80))
        mask &= ~0x80;
    if (!(nationalization & 0x20))
        mask &= ~0x40;

    return joyP2 & mask;
}

void writeGAMemoryControl(uint8_t value) {
    DBG_PRINT("writing %02X to memory control\n", value);
}

void writeGAJoyControl(uint8_t value) {
    nationalization = value;
    DBG_PRINT("writing %02X to joy control\n", value);
}
