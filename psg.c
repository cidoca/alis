#include <stdint.h>
#include "log.h"

#define DBG_TITLE "\033[1;36mPSG:\033[0m "

void writePSG(uint8_t value) {
    DBG_PRINT("writing data %02X\n", value);
}
