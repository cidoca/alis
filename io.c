#include <stdint.h>
#include "vdp.h"
#include "psg.h"
#include "ga.h"
#include "log.h"

#define DBG_TITLE "\033[1;32mIO:\033[0m "

uint8_t readIO(uint8_t port) {
    if ((port & 0xC0) == 0x40)
        return port & 1 ? readVDPHorizontal() : readVDPVertical();
    if ((port & 0xC0) == 0x80)
        return port & 1 ? readVDPStatus() : readVDPData();
    if ((port & 0xC0) == 0xC0)
        return port & 1 ? readGAJoyP2() : readGAJoyP1();

    DBG_PRINT("reading from %02X\n", port);
    return 0xFF;
}

void writeIO(uint8_t port, uint8_t value) {
    if ((port & 0xC0) == 0x00) {
        if (port & 1)
            writeGAJoyControl(value);
        else
            writeGAMemoryControl(value);
    } else if ((port & 0xC0) == 0x40) {
        if (port & 1)
            writePSG(value);
        else
            DBG_PRINT("writing %02X to %02X\n", value, port);
    } else if ((port & 0xC0) == 0x80) {
        if (port & 1)
            writeVDPCommand(value);
        else
            writeVDPData(value);
    } else
        DBG_PRINT("writing %02X to %02X\n", value, port);
}
