#include <fcntl.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
#include "cpu.h"
#include "memory.h"
#include "vdp.h"

int main(int argc, char **argv) {
    int fd = open(argv[1], O_RDONLY);
    ssize_t size = read(fd, ROM, 1024 * 1024) / 512;
    close(fd);

    if (size & 1)
        memcpy(ROM, ROM + 0x200, 512 * (--size));
    bankMask = (size / 32) - 1;

    resetCPU();
    resetVDP();
    for (int i = 0; i < 16384; i++)
        executeNextOpcode();

    return 0;
}
