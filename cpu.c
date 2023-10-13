#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "cpu.h"
#include "io.h"
#include "memory.h"
#include "log.h"

// #define WAIT_ON_M1

#define DBG_TITLE "\033[1;36mCPU:\033[0m "

#define rA      (regs[7])
#define rB      (regs[0])
#define rC      (regs[1])
#define rD      (regs[2])
#define rE      (regs[3])
#define rH      (regs[4])
#define rL      (regs[5])
#define rBC     ((rB << 8) | rC)
#define rDE     ((rD << 8) | rE)
#define rHL     ((rH << 8) | rL)

#define FLAG_S  (0x80)          // Signal
#define FLAG_Z  (0x40)          // Zero
#define FLAG_H  (0x10)          // Half carry
#define FLAG_PV (0x04)          // Parity/overflow
#define FLAG_N  (0x02)          // Negative
#define FLAG_C  (0x01)          // Carry
#define FLAG_XX (0x20 | 0x08)   // Must be copied from result

#define GET_FLAG_S(reg)   ((reg) & (FLAG_S | FLAG_XX))
#define GET_FLAG_Z(reg)   ((reg) == 0 ? FLAG_Z : 0)
#define GET_FLAG_P(reg)   (parityTable[reg])
#define GET_FLAG_SZ(reg)  (GET_FLAG_S(reg) | GET_FLAG_Z(reg))
#define GET_FLAG_SZP(reg) (GET_FLAG_SZ(reg) | GET_FLAG_P(reg))

#define GET_ADD_FLAG_HVNC(s) \
    ((((rA & 15) + ((s) & 15) > 15 ? FLAG_H : 0) | (rA + (unsigned)(s) > 255 ? FLAG_C : 0)) | \
    (((int8_t)(rA) >= 0 && (int8_t)(s) >= 0 && (int8_t)(rA + (s)) < 0) || \
    ((int8_t)(rA) < 0 && (int8_t)(s) < 0 && (int8_t)(rA + (s)) >= 0) ? FLAG_PV : 0))
#define GET_ADC_FLAG_HVNC(s) \
    (((rA & 15) + ((s) & 15) + (rFlags & FLAG_C) > 15 ? FLAG_H : 0) | \
    (rA + (unsigned)(s) + (rFlags & FLAG_C) > 255 ? FLAG_C : 0) | \
    (((int8_t)(rA) >= 0 && (int8_t)(s) >= 0 && (int8_t)(rA + (s) + (rFlags & FLAG_C)) < 0) || \
    ((int8_t)(rA) < 0 && (int8_t)(s) < 0 && (int8_t)(rA + (s) + (rFlags & FLAG_C)) >= 0) ? FLAG_PV : 0))
#define GET_ADC16_FLAG_HVNC(s) \
    (((rHL & 0xFFF) + ((s) & 0xFFF) + (rFlags & FLAG_C) > 0xFFF ? FLAG_H : 0) | \
    (rHL + (unsigned)(s) + (rFlags & FLAG_C) > 0xFFFF ? FLAG_C : 0) | \
    (((int16_t)(rHL) >= 0 && (int16_t)(s) >= 0 && (int16_t)(rHL + (s) + (rFlags & FLAG_C)) < 0) || \
    ((int16_t)(rHL) < 0 && (int16_t)(s) < 0 && (int16_t)(rHL + (s) + (rFlags & FLAG_C)) >= 0) ? \
    FLAG_PV : 0))

#define GET_SUB_FLAG_H(s) ((rA & 15) < ((s) & 15) ? FLAG_H : 0)
#define GET_SUB_FLAG_HVNC(s) \
    (FLAG_N | GET_SUB_FLAG_H(s) | (rA < (s) ? FLAG_C : 0) | \
    (((int8_t)(rA) < 0 && (int8_t)(s) >= 0 && (int8_t)(rA - (s)) >= 0) || \
    ((int8_t)(rA) >= 0 && (int8_t)(s) < 0 && (int8_t)(rA - (s)) < 0) ? FLAG_PV : 0))
#define GET_SBC_FLAG_HVNC(s) \
    (((rA & 15) < (((unsigned)(s) & 15) + (rFlags & FLAG_C)) ? FLAG_H : 0) | \
    (rA < ((unsigned)(s) + (rFlags & FLAG_C)) ? FLAG_C : 0) | FLAG_N | \
    (((int8_t)(rA) < 0 && (int8_t)(s) >= 0 && (int8_t)(rA - (s) - (rFlags & FLAG_C)) >= 0) || \
    ((int8_t)(rA) >= 0 && (int8_t)(s) < 0 && (int8_t)(rA - (s) - (rFlags & FLAG_C)) < 0) ? FLAG_PV : 0))
#define GET_SBC16_FLAG_HVNC(s) \
    (((rHL & 0xFFF) < ((s) & 0xFFF) + (rFlags & FLAG_C) ? FLAG_H : 0) | \
    (rHL < (s) + (rFlags & FLAG_C) ? FLAG_C : 0) | FLAG_N | \
    (((int16_t)(rHL) < 0 && (int16_t)(s) >= 0 && (int16_t)(rHL - (s) - (rFlags & FLAG_C)) >= 0) || \
    ((int16_t)(rHL) >= 0 && (int16_t)(s) < 0 && (int16_t)(rHL - (s) - (rFlags & FLAG_C)) < 0) ? \
    FLAG_PV : 0));

#define END_OPCODE(pc, clk) rPC += (pc); TClock += (clk); break;

const uint8_t parityTable[256] = {
    4, 0, 0, 4, 0, 4, 4, 0, 0, 4, 4, 0, 4, 0, 0, 4, 0, 4, 4, 0, 4, 0, 0, 4, 4, 0, 0, 4, 0, 4, 4, 0,
    0, 4, 4, 0, 4, 0, 0, 4, 4, 0, 0, 4, 0, 4, 4, 0, 4, 0, 0, 4, 0, 4, 4, 0, 0, 4, 4, 0, 4, 0, 0, 4,
    0, 4, 4, 0, 4, 0, 0, 4, 4, 0, 0, 4, 0, 4, 4, 0, 4, 0, 0, 4, 0, 4, 4, 0, 0, 4, 4, 0, 4, 0, 0, 4,
    4, 0, 0, 4, 0, 4, 4, 0, 0, 4, 4, 0, 4, 0, 0, 4, 0, 4, 4, 0, 4, 0, 0, 4, 4, 0, 0, 4, 0, 4, 4, 0,
    0, 4, 4, 0, 4, 0, 0, 4, 4, 0, 0, 4, 0, 4, 4, 0, 4, 0, 0, 4, 0, 4, 4, 0, 0, 4, 4, 0, 4, 0, 0, 4,
    4, 0, 0, 4, 0, 4, 4, 0, 0, 4, 4, 0, 4, 0, 0, 4, 0, 4, 4, 0, 4, 0, 0, 4, 4, 0, 0, 4, 0, 4, 4, 0,
    4, 0, 0, 4, 0, 4, 4, 0, 0, 4, 4, 0, 4, 0, 0, 4, 0, 4, 4, 0, 4, 0, 0, 4, 4, 0, 0, 4, 0, 4, 4, 0,
    0, 4, 4, 0, 4, 0, 0, 4, 4, 0, 0, 4, 0, 4, 4, 0, 4, 0, 0, 4, 0, 4, 4, 0, 0, 4, 4, 0, 4, 0, 0, 4
};

struct CPU cpu;

void resetCPU() {
    memset(&cpu, 0, sizeof(cpu));
    im = 1;
}

void intZ80() {
    if (IFF1) {
        rR++;
        IFF1 = IFF2 = 0;

        if (halt) {
            halt = 0;
            rPC++;
        }

        writeMemory(--rSP, rPC >> 8);
        writeMemory(--rSP, rPC & 0xFF);

        if (im == 1) {
            rPC = 0x38;
            TClock += 13;
        } else {
            uint8_t tmp = readMemory(rI << 8);
            rPC = (tmp << 8) | tmp;
            TClock += 19;
        }
    }
}

void executeNextOpcode() {
    unsigned tmp;
    uint8_t byte, byte2;

    rR++;
#ifdef WAIT_ON_M1
    TClock++;   // WAIT signal for every M1 state
#endif
    const uint8_t opCode0 = readMemory(rPC);
    DBG_DUMP_CORE

    switch (opCode0) {
        // NOP - 4
        case 0x00:
            END_OPCODE(1, 4)

        // LD BC, nn - 10
        case 0x01:
            rC = readMemory(rPC + 1);
            rB = readMemory(rPC + 2);
            END_OPCODE(3, 10)

        // LD (BC), A - 7
        case 0x02:
            writeMemory(rBC, rA);
            END_OPCODE(1, 7)

        // INC BC - 6
        case 0x03: {
            const unsigned tmpBC = rBC + 1;
            rB = tmpBC >> 8;
            rC = tmpBC & 0xFF;
            END_OPCODE(1, 6) }

        // INC r - 4 - SZHPN
        case 0x04: case 0x0C: case 0x14: case 0x1C: case 0x24: case 0x2C: case 0x3C:
            rFlags = (rFlags & FLAG_C) | (regs[opCode0 >> 3] == 0x7F ? FLAG_PV : 0);
            regs[opCode0 >> 3]++;
            rFlags |= GET_FLAG_SZ(regs[opCode0 >> 3]) | ((regs[opCode0 >> 3] & 0x0F) == 0 ? FLAG_H : 0);
            END_OPCODE(1, 4)

        // DEC r - 4 - SZHPN
        case 0x05: case 0x0D: case 0x15: case 0x1D: case 0x25: case 0x2D: case 0x3D:
            rFlags = FLAG_N | (rFlags & FLAG_C) | (regs[opCode0 >> 3] == 0x80 ? FLAG_PV : 0);
            regs[opCode0 >> 3]--;
            rFlags |= GET_FLAG_SZ(regs[opCode0 >> 3]) | ((regs[opCode0 >> 3] & 0x0F) == 15 ? FLAG_H : 0);
            END_OPCODE(1, 4)

        // LD r, n - 7
        case 0x06: case 0x0E: case 0x16: case 0x1E: case 0x26: case 0x2E: case 0x3E:
            regs[opCode0 >> 3] = readMemory(rPC + 1);;
            END_OPCODE(2, 7)

        // RLCA - 4 - HNC
        case 0x07:
            rA = (rA << 1) | (rA >> 7);
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (rA & (FLAG_XX | FLAG_C));
            END_OPCODE(1, 4)

        // EX AF, AF' - 4
        case 0x08: {
            const uint8_t tmpA = rA;
            const uint8_t tmpFlags = rFlags;
            rA = regs2[7];
            regs2[7] = tmpA;
            rFlags = rFlags2;
            rFlags2 = tmpFlags;
            END_OPCODE(1, 4) }

        // ADD HL, BC - 11 - HNC
        case 0x09: {
            const unsigned tmpHL = rHL + rBC;
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (tmpHL > 0xFFFF ? FLAG_C : 0) |
                     ((rHL & 0xFFF) + (rBC & 0xFFF) > 0xFFF ? FLAG_H : 0);
            rH = tmpHL >> 8;
            rL = tmpHL & 0xFF;
            rFlags |= rH & FLAG_XX;
            END_OPCODE(1, 11) }

        // LD A, (BC) - 7
        case 0x0A:
            rA = readMemory(rBC);
            END_OPCODE(1, 7)

        // DEC BC - 6
        case 0x0B: {
            const unsigned tmpBC = rBC - 1;
            rB = tmpBC >> 8;
            rC = tmpBC & 0xFF;
            END_OPCODE(1, 6) }

        // RRCA - 4 - HNC
        case 0x0F:
            rFlags &= FLAG_S | FLAG_Z | FLAG_PV;
            rA = (rA >> 1) | (rA << 7);
            rFlags |= (rA & FLAG_XX) | (rA & 0x80 ? FLAG_C : 0);
            END_OPCODE(1, 4)

        // DJNZ e - 8/13
        case 0x10:
            rB--;
            if (rB == 0) {
                END_OPCODE(2, 8)
            } else {
                END_OPCODE(((int8_t)readMemory(rPC + 1)) + 2, 13)
            }

        // LD DE, nn - 10
        case 0x11:
            rE = readMemory(rPC + 1);
            rD = readMemory(rPC + 2);
            END_OPCODE(3, 10)

        // LD (DE), A - 7
        case 0x12:
            writeMemory(rDE, rA);
            END_OPCODE(1, 7)

        // INC DE - 6
        case 0x13:
            rE++;
            if (!rE) rD++;
            END_OPCODE(1, 6)

        // RLA - 4 - HNC
        case 0x17: {
            const uint8_t tmpA = rA;
            rA = (rA << 1) | (rFlags & FLAG_C);
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (rA & FLAG_XX) | (tmpA & 0x80 ? FLAG_C : 0);
            END_OPCODE(1, 4) }

        // JR e - 12
        case 0x18:
            END_OPCODE(((int8_t)readMemory(rPC + 1)) + 2, 12)

        // ADD HL, DE - 11 - HNC
        case 0x19: {
            const unsigned tmpHL = rHL + rDE;
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (tmpHL > 0xFFFF ? FLAG_C : 0) |
                     ((rHL & 0xFFF) + (rDE & 0xFFF) > 0xFFF ? FLAG_H : 0);
            rH = tmpHL >> 8;
            rL = tmpHL & 0xFF;
            rFlags |= rH & FLAG_XX;
            END_OPCODE(1, 11) }

        // LD A, (DE) - 7
        case 0x1A:
            rA = readMemory(rDE);
            END_OPCODE(1, 7)

        // DEC DE - 6
        case 0x1B: {
            const unsigned tmpDE = rDE - 1;
            rD = tmpDE >> 8;
            rE = tmpDE & 0xFF;
            END_OPCODE(1, 6) }

        // RRA - 4 - HNC
        case 0x1F: {
            const uint8_t tmpA = rA;
            rA = (rA >> 1) | (rFlags << 7);
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (rA & FLAG_XX) | (tmpA & FLAG_C);
            END_OPCODE(1, 4) }

        // JR NZ, e - 7/12
        case 0x20:
            if (rFlags & FLAG_Z) {
                END_OPCODE(2, 7)
            } else {
                END_OPCODE(((int8_t)readMemory(rPC + 1)) + 2, 12)
            }

        // LD HL, nn - 10
        case 0x21:
            rL = readMemory(rPC + 1);
            rH = readMemory(rPC + 2);
            END_OPCODE(3, 10)

        // LD (nn), HL - 16
        case 0x22: {
            const unsigned addr = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
            writeMemory(addr, rL);
            writeMemory(addr + 1, rH);
            END_OPCODE(3, 16) }

        // INC HL - 6
        case 0x23:
            rL++;
            if (!rL) rH++;
            END_OPCODE(1, 6)

        // DAA - 4 - SZHPC
        case 0x27: {
            uint8_t tmpA = rA;
            if ((rFlags & FLAG_H) || ((rA & 0xF) > 0x9))
                tmpA += rFlags & FLAG_N ? -0x6 : 0x6;
            if ((rFlags & FLAG_C) || (rA > 0x99))
                tmpA += rFlags & FLAG_N ? -0x60 : 0x60;
            rFlags = GET_FLAG_SZP(tmpA) | ((rA & 0x10) ^ (tmpA & 0x10)) | (rFlags & FLAG_N) |
                     ((rFlags & FLAG_C) || (rA > 0x99) ? FLAG_C : 0);
            rA = tmpA;
            END_OPCODE(1, 4) }

        // JR Z, e - 7/12
        case 0x28:
            if (rFlags & FLAG_Z) {
                END_OPCODE(((int8_t)readMemory(rPC + 1)) + 2, 12)
            } else {
                END_OPCODE(2, 7)
            }

        // ADD HL, HL - 11 - HNC
        case 0x29: {
            const unsigned tmpHL = rHL + rHL;
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (tmpHL > 0xFFFF ? FLAG_C : 0) |
                     ((rHL & 0xFFF) + (rHL & 0xFFF) > 0xFFF ? FLAG_H : 0);
            rH = tmpHL >> 8;
            rL = tmpHL & 0xFF;
            rFlags |= rH & FLAG_XX;
            END_OPCODE(1, 11) }

        // LD HL, (nn) - 16
        case 0x2A: {
            const unsigned addr = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
            rL = readMemory(addr);
            rH = readMemory(addr + 1);
            END_OPCODE(3, 16) }

        // DEC HL - 6
        case 0x2B: {
            const unsigned tmpHL = rHL - 1;
            rH = tmpHL >> 8;
            rL = tmpHL & 0xFF;
            END_OPCODE(1, 6) }

        // CPL - 4 - HN
        case 0x2F:
            rA = ~rA;
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV | FLAG_C)) | (rA & FLAG_XX) | FLAG_H | FLAG_N;
            END_OPCODE(1, 4)

        // JR NC, e - 7/12
        case 0x30:
            if (rFlags & FLAG_C) {
                END_OPCODE(2, 7)
            } else {
                END_OPCODE(((int8_t)readMemory(rPC + 1)) + 2, 12)
            }

        // LD SP, nn - 10
        case 0x31:
            rSP = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
            END_OPCODE(3, 10)

        // LD (nn), A - 13
        case 0x32:
            writeMemory((readMemory(rPC + 2) << 8) | readMemory(rPC + 1), rA);
            END_OPCODE(3, 13)

        // INC SP - 6
        case 0x33:
            rSP = (rSP + 1) & 0xFFFF;
            END_OPCODE(1, 6)

        // INC (HL) - 11 - SZHPN
        case 0x34: {
            uint8_t mem = readMemory(rHL);
            rFlags = (rFlags & FLAG_C) | (mem == 0x7F ? FLAG_PV : 0);
            mem++;
            rFlags |= GET_FLAG_SZ(mem) | ((mem & 0x0F) == 0 ? FLAG_H : 0);
            writeMemory(rHL, mem);
            END_OPCODE(1, 11) }

        // DEC (HL) - 11 - SZHPN
        case 0x35: {
            uint8_t mem = readMemory(rHL);
            rFlags = FLAG_N | (rFlags & FLAG_C) | (mem == 0x80 ? FLAG_PV : 0);
            mem--;
            rFlags |= GET_FLAG_SZ(mem) | ((mem & 0x0F) == 15 ? FLAG_H : 0);
            writeMemory(rHL, mem);
            END_OPCODE(1, 11) }

        // LD (HL), n - 10
        case 0x36:
            writeMemory(rHL, readMemory(rPC + 1));
            END_OPCODE(2, 10)

        // SCF - 4 - HNC
        case 0x37:
            rFlags &= FLAG_S | FLAG_Z | FLAG_PV | FLAG_XX;
            rFlags |= FLAG_C;
            END_OPCODE(1, 4)

        // JR C, e - 7/12
        case 0x38:
            if (rFlags & FLAG_C) {
                END_OPCODE(((int8_t)readMemory(rPC + 1)) + 2, 12)
            } else {
                END_OPCODE(2, 7)
            }

        // ADD HL, SP - 11 - HNC
        case 0x39: {
            const unsigned tmpHL = rHL + rSP;
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (tmpHL > 0xFFFF ? FLAG_C : 0) |
                     ((rHL & 0xFFF) + (rSP & 0xFFF) > 0xFFF ? FLAG_H : 0);
            rH = tmpHL >> 8;
            rL = tmpHL & 0xFF;
            rFlags |= rH & FLAG_XX;
            END_OPCODE(1, 11) }

        // LD A, (nn) - 13
        case 0x3A:
            rA = readMemory((readMemory(rPC + 2) << 8) | readMemory(rPC + 1));
            END_OPCODE(3, 13)

        // DEC SP - 6
        case 0x3B:
            rSP = (rSP - 1) & 0xFFFF;
            END_OPCODE(1, 6)

        // CCF - 4 - HNC
        case 0x3F:
            rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV | FLAG_C | FLAG_XX)) | (rFlags & FLAG_C ? FLAG_H : 0);
            rFlags ^= FLAG_C;
            END_OPCODE(1, 4)

        // LD r, r' - 4
        case 0x40: case 0x41: case 0x42: case 0x43: case 0x44: case 0x45: case 0x47:
        case 0x48: case 0x49: case 0x4A: case 0x4B: case 0x4C: case 0x4D: case 0x4F:
        case 0x50: case 0x51: case 0x52: case 0x53: case 0x54: case 0x55: case 0x57:
        case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5F:
        case 0x60: case 0x61: case 0x62: case 0x63: case 0x64: case 0x65: case 0x67:
        case 0x68: case 0x69: case 0x6A: case 0x6B: case 0x6C: case 0x6D: case 0x6F:
        case 0x78: case 0x79: case 0x7A: case 0x7B: case 0x7C: case 0x7D: case 0x7F:
            regs[(opCode0 >> 3) & 7] = regs[opCode0 & 7];
            END_OPCODE(1, 4)

        // LD r, (HL) - 7
        case 0x46: case 0x4E: case 0x56: case 0x5E: case 0x66: case 0x6E: case 0x7E:
            regs[(opCode0 >> 3) & 7] = readMemory(rHL);
            END_OPCODE(1, 7)

        // LD (HL), r - 7
        case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: case 0x77:
            writeMemory(rHL, regs[opCode0 & 7]);
            END_OPCODE(1, 7)

        // HALT - 4
        case 0x76:
            halt = 1;
            TClock += 4;
            break;

        // ADD A, r - 4 - SZHPNC
        case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x87:
            rFlags = GET_ADD_FLAG_HVNC(regs[opCode0 & 7]);
            rA += regs[opCode0 & 7];
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(1, 4)

        // ADD A, (HL) - 7 - SZHPNC
        case 0x86: {
            const uint8_t mem = readMemory(rHL);
            rFlags = GET_ADD_FLAG_HVNC(mem);
            rA += mem;
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(1, 7) }

        // ADC A, r - 4 - SZHPNC
        case 0x88: case 0x89: case 0x8A: case 0x8B: case 0x8C: case 0x8D: case 0x8F: {
            const uint8_t tmpFlags = rFlags;
            rFlags = GET_ADC_FLAG_HVNC(regs[opCode0 & 7]);
            rA += regs[opCode0 & 7] + (tmpFlags & FLAG_C);
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(1, 4) }

        // ADC A, (HL) - 7 - SZHPNC
        case 0x8E: {
            const uint8_t tmpFlags = rFlags;
            const uint8_t mem = readMemory(rHL);
            rFlags = GET_ADC_FLAG_HVNC(mem);
            rA += mem + (tmpFlags & FLAG_C);
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(1, 7) }

        // SUB r - 4 - SZHPNC
        case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x97:
            rFlags = GET_SUB_FLAG_HVNC(regs[opCode0 & 7]);
            rA -= regs[opCode0 & 7];
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(1, 4)

        // SUB (HL) - 7 - SZHPNC
        case 0x96: {
            const uint8_t mem = readMemory(rHL);
            rFlags = GET_SUB_FLAG_HVNC(mem);
            rA -= mem;
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(1, 7) }

        // SBC A, r - 4 - SZHPNC
        case 0x98: case 0x99: case 0x9A: case 0x9B: case 0x9C: case 0x9D: case 0x9F: {
            const uint8_t tmpFlags = rFlags;
            rFlags = GET_SBC_FLAG_HVNC(regs[opCode0 & 7]);
            rA -= regs[opCode0 & 7] + (tmpFlags & FLAG_C);
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(1, 4) }

        // SBC A, (HL) - 7 - SZHPNC
        case 0x9E: {
            const uint8_t tmpFlags = rFlags;
            const uint8_t mem = readMemory(rHL);
            rFlags = GET_SBC_FLAG_HVNC(mem);
            rA -= mem + (tmpFlags & FLAG_C);
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(1, 7) }

        // AND r - 4 - SZHPNC
        case 0xA0: case 0xA1: case 0xA2: case 0xA3: case 0xA4: case 0xA5: case 0xA7:
            rA &= regs[opCode0 & 7];
            rFlags = FLAG_H | GET_FLAG_SZP(rA);
            END_OPCODE(1, 4)

        // AND (HL) - 7 - SZHPNC
        case 0xA6:
            rA &= readMemory(rHL);
            rFlags = FLAG_H | GET_FLAG_SZP(rA);
            END_OPCODE(1, 7)

        // XOR r - 4 - SZHPNC
        case 0xA8: case 0xA9: case 0xAA: case 0xAB: case 0xAC: case 0xAD: case 0xAF:
            rA ^= regs[opCode0 & 7];
            rFlags = GET_FLAG_SZP(rA);
            END_OPCODE(1, 4)

        // XOR (HL) - 7 - SZHPNC
        case 0xAE:
            rA ^= readMemory(rHL);
            rFlags = GET_FLAG_SZP(rA);
            END_OPCODE(1, 7)

        // OR r - 4 - SZHPNC
        case 0xB0: case 0xB1: case 0xB2: case 0xB3: case 0xB4: case 0xB5: case 0xB7:
            rA |= regs[opCode0 & 7];
            rFlags = GET_FLAG_SZP(rA);
            END_OPCODE(1, 4)

        // OR (HL) - 7 - SZHPNC
        case 0xB6:
            rA |= readMemory(rHL);
            rFlags = GET_FLAG_SZP(rA);
            END_OPCODE(1, 7)

        // CP r - 7 - SZHPNC
        case 0xB8: case 0xB9: case 0xBA: case 0xBB: case 0xBC: case 0xBD: case 0xBF:
            rFlags = GET_SUB_FLAG_HVNC(regs[opCode0 & 7]) | GET_FLAG_SZ(rA - regs[opCode0 & 7]);
            END_OPCODE(1, 4)

        // CP (HL) - 7 - SZHPNC
        case 0xBE: {
            const uint8_t mem = readMemory(rHL);
            rFlags = GET_SUB_FLAG_HVNC(mem) | GET_FLAG_SZ(rA - mem);
            END_OPCODE(1, 7) }

        // RET NZ - 5/11
        case 0xC0:
            if (rFlags & FLAG_Z) {
                END_OPCODE(1, 5)
            } else {
                rPC = readMemory(rSP++);
                rPC |= readMemory(rSP++) << 8;
                TClock += 11;
                break;
            }

        // POP BC - 10
        case 0xC1:
            rC = readMemory(rSP++);
            rB = readMemory(rSP++);
            END_OPCODE(1, 10)

        // JP NZ, cc - 10
        case 0xC2:
            if (rFlags & FLAG_Z) {
                END_OPCODE(3, 10)
            } else {
                rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
                TClock += 10;
                break;
            }

        // JP nn - 10
        case 0xC3:
            rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
            TClock += 10;
            break;

        // CALL NZ - 10/17
        case 0xC4:
            if (rFlags & FLAG_Z) {
                END_OPCODE(3, 10);
            } else {
                rPC += 3;
                writeMemory(--rSP, rPC >> 8);
                writeMemory(--rSP, rPC & 0xFF);
                rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
                TClock += 17;
                break;
            }

        // PUSH BC - 11
        case 0xC5:
            writeMemory(--rSP, rB);
            writeMemory(--rSP, rC);
            END_OPCODE(1, 11)

        // ADD A, n - 7 - SZHPNC
        case 0xC6: {
            const uint8_t imm = readMemory(rPC + 1);
            rFlags = GET_ADD_FLAG_HVNC(imm);
            rA += imm;
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(2, 7) }

        // RST p - 11
        case 0xC7: case 0xCF: case 0xD7: case 0xDF: case 0xE7: case 0xEF: case 0xF7: case 0xFF:
            rPC++;
            writeMemory(--rSP, rPC >> 8);
            writeMemory(--rSP, rPC & 0xFF);
            rPC = opCode0 & 0x38;
            TClock += 11;
            break;

        // RET Z - 5/11
        case 0xC8:
            if (rFlags & FLAG_Z) {
                rPC = readMemory(rSP++);
                rPC |= readMemory(rSP++) << 8;
                TClock += 11;
                break;
            } else {
                END_OPCODE(1, 5)
            }

        // RET - 10
        case 0xC9:
            rPC = readMemory(rSP++);
            rPC |= readMemory(rSP++) << 8;
            TClock += 10;
            break;

        // JP Z, cc - 10
        case 0xCA:
            if (rFlags & FLAG_Z) {
                rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
                TClock += 10;
                break;
            } else {
                END_OPCODE(3, 10)
            }

        // Prefix CB
        case 0xCB: {
            rR++;
#ifdef WAIT_ON_M1
            TClock++;   // WAIT signal for every M1 state
#endif

            const uint8_t opCode1 = readMemory(rPC + 1);
            switch (opCode1) {

                // RLC r - 8 - SZHPNC
                case 0x00: case 0x01: case 0x02: case 0x03: case 0x04: case 0x05: case 0x07:
                    regs[opCode1 & 7] = (regs[opCode1 & 7] << 1) | (regs[opCode1 & 7] >> 7);
                    rFlags = GET_FLAG_SZP(regs[opCode1 & 7]) | (regs[opCode1 & 7] & FLAG_C);
                    END_OPCODE(2, 8)

                // RLC (HL) - 15 - SZHPNC
                case 0x6: {
                    uint8_t mem = readMemory(rHL);
                    mem = (mem << 1) | (mem >> 7);
                    rFlags = GET_FLAG_SZP(mem) | (mem & FLAG_C);
                    writeMemory(rHL, mem);
                    END_OPCODE(2, 15) }

                // RRC r - 8 - SZHPNC
                case 0x08: case 0x09: case 0x0A: case 0x0B: case 0x0C: case 0x0D: case 0x0F:
                    regs[opCode1 & 7] = (regs[opCode1 & 7] >> 1) | (regs[opCode1 & 7] << 7);
                    rFlags = GET_FLAG_SZP(regs[opCode1 & 7]) | (regs[opCode1 & 7] & 0x80 ? FLAG_C : 0);
                    END_OPCODE(2, 8)

                // RRC (HL) - 15 - SZHPNC
                case 0x0E: {
                    uint8_t mem = readMemory(rHL);
                    mem = (mem >> 1) | (mem << 7);
                    rFlags = GET_FLAG_SZP(mem) | (mem & 0x80 ? FLAG_C : 0);
                    writeMemory(rHL, mem);
                    END_OPCODE(2, 15) }

                // RL r - 8 - SZHPNC
                case 0x10: case 0x11: case 0x12: case 0x13: case 0x14: case 0x15: case 0x17: {
                    const uint8_t reg = regs[opCode1 & 7];
                    regs[opCode1 & 7] = (regs[opCode1 & 7] << 1) | (rFlags & FLAG_C);
                    rFlags = GET_FLAG_SZP(regs[opCode1 & 7]) | (reg >> 7);
                    END_OPCODE(2, 8) }

                // RL (HL) - 15 - SZHPNC
                case 0x16: {
                    byte2 = byte = readMemory(rHL);
                    byte = (byte << 1) | (rFlags & FLAG_C);
                    rFlags = GET_FLAG_SZP(byte) | (byte2 >> 7);
                    writeMemory(rHL, byte);
                    END_OPCODE(2, 15) }

                // RR r - 8 - SZHPNC
                case 0x18: case 0x19: case 0x1A: case 0x1B: case 0x1C: case 0x1D: case 0x1F: {
                    const uint8_t reg = regs[opCode1 & 7];
                    regs[opCode1 & 7] = (regs[opCode1 & 7] >> 1) | (rFlags << 7);
                    rFlags = GET_FLAG_SZP(regs[opCode1 & 7]) | (reg & 1);
                    END_OPCODE(2, 8) }

                // RR (HL) - 15 - SZHPNC
                case 0x1E:
                    byte2 = byte = readMemory(rHL);
                    byte = (byte >> 1) | (rFlags << 7);
                    rFlags = GET_FLAG_SZP(byte) | (byte2 & 1);
                    writeMemory(rHL, byte);
                    END_OPCODE(2, 15)

                // SLA r - 8 - SZHPNC
                case 0x20: case 0x21: case 0x22: case 0x23: case 0x24: case 0x25: case 0x27:
                    rFlags = regs[opCode1 & 7] >> 7;      // Carry flag
                    regs[opCode1 & 7] <<= 1;
                    rFlags |= GET_FLAG_SZP(regs[opCode1 & 7]);
                    END_OPCODE(2, 8)

                // SLA (HL) - 15 - SZHPNC
                case 0x26: {
                    uint8_t mem = readMemory(rHL);
                    rFlags = mem >> 7;
                    mem <<= 1;
                    rFlags |= GET_FLAG_SZP(mem);
                    writeMemory(rHL, mem);
                    END_OPCODE(2, 15) }

                // SRA r - 8 - SZHPNC
                case 0x28: case 0x29: case 0x2A: case 0x2B: case 0x2C: case 0x2D: case 0x2F:
                    rFlags = regs[opCode1 & 7] & FLAG_C;
                    regs[opCode1 & 7] = ((int8_t)regs[opCode1 & 7]) >> 1;
                    rFlags |= GET_FLAG_SZP(regs[opCode1 & 7]);
                    END_OPCODE(2, 8)

                // SRA (HL) - 15 - SZHPNC
                case 0x2E: {
                    uint8_t mem = readMemory(rHL);
                    rFlags = mem & FLAG_C;
                    mem = ((int8_t)mem) >> 1;
                    rFlags |= GET_FLAG_SZP(mem);
                    writeMemory(rHL, mem);
                    END_OPCODE(2, 15) }

                // SLL r - 8 - SZHPNC
                case 0x30: case 0x31: case 0x32: case 0x33: case 0x34: case 0x35: case 0x37:
                    rFlags = regs[opCode1 & 7] >> 7;      // Carry flag
                    regs[opCode1 & 7] <<= 1;
                    regs[opCode1 & 7]++;
                    rFlags |= GET_FLAG_SZP(regs[opCode1 & 7]);
                    END_OPCODE(2, 8)

                // SLL (HL) - 15 - SZHPNC
                case 0x36: {
                    uint8_t mem = readMemory(rHL);
                    rFlags = mem >> 7;
                    mem <<= 1;
                    mem++;
                    rFlags |= GET_FLAG_SZP(mem);
                    writeMemory(rHL, mem);
                    END_OPCODE(2, 15) }

                // SRL r - 8 - SZHPNC
                case 0x38: case 0x39: case 0x3A: case 0x3B: case 0x3C: case 0x3D: case 0x3F:
                    rFlags = regs[opCode1 & 7] & FLAG_C;      // Carry flag
                    regs[opCode1 & 7] >>= 1;
                    rFlags |= GET_FLAG_SZP(regs[opCode1 & 7]);
                    END_OPCODE(2, 8)

                // SRL (HL) - 15 - SZHPNC
                case 0x3E: {
                    uint8_t mem = readMemory(rHL);
                    rFlags = mem & FLAG_C;
                    mem >>= 1;
                    rFlags |= GET_FLAG_SZP(mem);
                    writeMemory(rHL, mem);
                    END_OPCODE(2, 15) }

                // BIT b, r - 8 - ZHN
                case 0x40: case 0x41: case 0x42: case 0x43: case 0x44: case 0x45: case 0x47:
                case 0x48: case 0x49: case 0x4A: case 0x4B: case 0x4C: case 0x4D: case 0x4F:
                case 0x50: case 0x51: case 0x52: case 0x53: case 0x54: case 0x55: case 0x57:
                case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5F:
                case 0x60: case 0x61: case 0x62: case 0x63: case 0x64: case 0x65: case 0x67:
                case 0x68: case 0x69: case 0x6A: case 0x6B: case 0x6C: case 0x6D: case 0x6F:
                case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: case 0x77:
                case 0x78: case 0x79: case 0x7A: case 0x7B: case 0x7C: case 0x7D: case 0x7F:
                    rFlags = GET_FLAG_SZP(regs[opCode1 & 7] & (1 << ((opCode1 >> 3) & 7))) |
                             FLAG_H | (rFlags & FLAG_C);
                    END_OPCODE(2, 8)

                // BIT b, (HL) - 12 - ZHN
                case 0x46: case 0x4E: case 0x56: case 0x5E: case 0x66: case 0x6E: case 0x76: case 0x7E:
                    rFlags = GET_FLAG_SZP((readMemory(rHL)) & (1 << ((opCode1 >> 3) & 7))) |
                             FLAG_H | (rFlags & FLAG_C);
                    END_OPCODE(2, 12)

                // RES b, r - 8
                case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x87:
                case 0x88: case 0x89: case 0x8A: case 0x8B: case 0x8C: case 0x8D: case 0x8F:
                case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x97:
                case 0x98: case 0x99: case 0x9A: case 0x9B: case 0x9C: case 0x9D: case 0x9F:
                case 0xA0: case 0xA1: case 0xA2: case 0xA3: case 0xA4: case 0xA5: case 0xA7:
                case 0xA8: case 0xA9: case 0xAA: case 0xAB: case 0xAC: case 0xAD: case 0xAF:
                case 0xB0: case 0xB1: case 0xB2: case 0xB3: case 0xB4: case 0xB5: case 0xB7:
                case 0xB8: case 0xB9: case 0xBA: case 0xBB: case 0xBC: case 0xBD: case 0xBF:
                    regs[opCode1 & 7] &= ~(1 << ((opCode1 >> 3) & 7));
                    END_OPCODE(2, 8)

                // RES b, (HL) - 15
                case 0x86: case 0x8E: case 0x96: case 0x9E: case 0xA6: case 0xAE: case 0xB6: case 0xBE:
                    writeMemory(rHL, (readMemory(rHL)) & ~(1 << ((opCode1 >> 3) & 7)));
                    END_OPCODE(2, 15)

                // SET b, r - 8
                case 0xC0: case 0xC1: case 0xC2: case 0xC3: case 0xC4: case 0xC5: case 0xC7:
                case 0xC8: case 0xC9: case 0xCA: case 0xCB: case 0xCC: case 0xCD: case 0xCF:
                case 0xD0: case 0xD1: case 0xD2: case 0xD3: case 0xD4: case 0xD5: case 0xD7:
                case 0xD8: case 0xD9: case 0xDA: case 0xDB: case 0xDC: case 0xDD: case 0xDF:
                case 0xE0: case 0xE1: case 0xE2: case 0xE3: case 0xE4: case 0xE5: case 0xE7:
                case 0xE8: case 0xE9: case 0xEA: case 0xEB: case 0xEC: case 0xED: case 0xEF:
                case 0xF0: case 0xF1: case 0xF2: case 0xF3: case 0xF4: case 0xF5: case 0xF7:
                case 0xF8: case 0xF9: case 0xFA: case 0xFB: case 0xFC: case 0xFD: case 0xFF:
                    regs[opCode1 & 7] |= 1 << ((opCode1 >> 3) & 7);
                    END_OPCODE(2, 8)

                // SET b, (HL) - 15
                case 0xC6: case 0xCE: case 0xD6: case 0xDE: case 0xE6: case 0xEE: case 0xF6: case 0xFE:
                    writeMemory(rHL, (readMemory(rHL)) | (1 << ((opCode1 >> 3) & 7)));
                    END_OPCODE(2, 15)

                // Not implemented yet
//                    default:
//                        DBG_PRINT_HISTORY
//                        printf("Opcode CB %02X not implemented!!!\n", opCode1);
//                        exit(1);
            }
            break; }

        // CALL Z - 10/17
        case 0xCC:
            if (rFlags & FLAG_Z) {
                rPC += 3;
                writeMemory(--rSP, rPC >> 8);
                writeMemory(--rSP, rPC & 0xFF);
                rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
                TClock += 17;
                break;
            } else {
                END_OPCODE(3, 10);
            }

        // CALL nn - 17
        case 0xCD:
            rPC += 3;
            writeMemory(--rSP, rPC >> 8);
            writeMemory(--rSP, rPC & 0xFF);
            rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
            TClock += 17;
            break;

        // ADC A, n - 7 - SZHPNC
        case 0xCE: {
            const uint8_t tmpFlags = rFlags;
            const uint8_t imm = readMemory(rPC + 1);
            rFlags = GET_ADC_FLAG_HVNC(imm);
            rA += imm + (tmpFlags & FLAG_C);
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(2, 7) }

        // RET NC - 5/11
        case 0xD0:
            if (rFlags & FLAG_C) {
                END_OPCODE(1, 5)
            } else {
                rPC = readMemory(rSP++);
                rPC |= readMemory(rSP++) << 8;
                TClock += 11;
                break;
            }

        // POP DE - 10
        case 0xD1:
            rE = readMemory(rSP++);
            rD = readMemory(rSP++);
            END_OPCODE(1, 10)

        // JP NC, cc - 10
        case 0xD2:
            if (rFlags & FLAG_C) {
                END_OPCODE(3, 10)
            } else {
                rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
                TClock += 10;
                break;
            }

        // OUT (n), A - 11
        case 0xD3:
            writeIO(readMemory(rPC + 1), rA);
            END_OPCODE(2, 11)

        // CALL NC - 10/17
        case 0xD4:
            if (rFlags & FLAG_C) {
                END_OPCODE(3, 10);
            } else {
                rPC += 3;
                writeMemory(--rSP, rPC >> 8);
                writeMemory(--rSP, rPC & 0xFF);
                rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
                TClock += 17;
                break;
            }

        // PUSH DE - 11
        case 0xD5:
            writeMemory(--rSP, rD);
            writeMemory(--rSP, rE);
            END_OPCODE(1, 11)

        // SUB n - 7 - SZHPNC
        case 0xD6: {
            const uint8_t imm = readMemory(rPC + 1);
            rFlags = GET_SUB_FLAG_HVNC(imm);
            rA -= imm;
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(2, 7) }

        // RET C - 5/11
        case 0xD8:
            if (rFlags & FLAG_C) {
                rPC = readMemory(rSP++);
                rPC |= readMemory(rSP++) << 8;
                TClock += 11;
                break;
            } else {
                END_OPCODE(1, 5)
            }

        // EXX - 4
        case 0xD9:
            for (int i = 0; i < 6; i++) {
                const uint8_t reg = regs[i];
                regs[i] = regs2[i];
                regs2[i] = reg;
            }
            END_OPCODE(1, 4)

        // JP C, cc - 10
        case 0xDA:
            if (rFlags & FLAG_C) {
                rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
                TClock += 10;
                break;
            } else {
                END_OPCODE(3, 10)
            }

        // IN A, (n) - 11
        case 0xDB:
            rA = readIO(readMemory(rPC + 1));
            END_OPCODE(2, 11)

        // CALL C - 10/17
        case 0xDC:
            if (rFlags & FLAG_C) {
                rPC += 3;
                writeMemory(--rSP, rPC >> 8);
                writeMemory(--rSP, rPC & 0xFF);
                rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
                TClock += 17;
                break;
            } else {
                END_OPCODE(3, 10);
            }

        // Prefix DD/FD
        case 0xDD: case 0xFD: {
            rR++;
#ifdef WAIT_ON_M1
            TClock++;   // WAIT signal for every M1 state
#endif

            unsigned index = opCode0 & 0x20 ? rIY : rIX;
            const uint8_t opCode1 = readMemory(rPC + 1);
            switch (opCode1) {

                // ADD Ii, BC - 15 - HPNC
                case 0x09:
                    rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (index + rBC > 0xFFFF ? FLAG_C : 0) |
                             ((index & 0xFFF) + (rBC & 0xFFF) > 0xFFF ? FLAG_H : 0);
                    index = (index + rBC) & 0xFFFF;
                    rFlags |= (index >> 8) & FLAG_XX;
                    END_OPCODE(2, 15)

                // ADD Ii, DE - 15 - HPNC
                case 0x19:
                    rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (index + rDE > 0xFFFF ? FLAG_C : 0) |
                             ((index & 0xFFF) + (rDE & 0xFFF) > 0xFFF ? FLAG_H : 0);
                    index = (index + rDE) & 0xFFFF;
                    rFlags |= (index >> 8) & FLAG_XX;
                    END_OPCODE(2, 15)

                // LD Ii, nn
                case 0x21:
                    index = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    END_OPCODE(4, 14)

                // LD (nn), Ii - 20
                case 0x22: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    writeMemory(addr, index & 0xFF);
                    writeMemory(addr + 1, index >> 8);
                    END_OPCODE(4, 20) }

                // INC Ii - 10
                case 0x23:
                    index = (index + 1) & 0xFFFF;
                    END_OPCODE(2, 10)

                // INC IiH - 8
                case 0x24:
                    rFlags = (rFlags & FLAG_C) | (((index >> 8) & 0xFF) == 0x7F ? FLAG_PV : 0);
                    index = (index + 0x100) & 0xFFFF;
                    rFlags |= GET_FLAG_SZ((index >> 8) & 0xFF) | ((index & 0x0F00) == 0 ? FLAG_H : 0);
                    END_OPCODE(2, 8)

                // DEC IiH - 8
                case 0x25:
                    rFlags = FLAG_N | (rFlags & FLAG_C) | ((index >> 8) == 0x80 ? FLAG_PV : 0);
                    index = (index - 0x100) & 0xFFFF;
                    rFlags |= GET_FLAG_SZ(index >> 8) | (((index >> 8) & 0x0F) == 15 ? FLAG_H : 0);
                    END_OPCODE(2, 8)

                // LD IiH, n - 11
                case 0x26:
                    index = (readMemory(rPC + 2) << 8) | (index & 0xFF);
                    END_OPCODE(3, 11)

                // ADD Ii, Ii - 15 - HPNC
                case 0x29:
                    rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (index + index > 0xFFFF ? FLAG_C : 0) |
                             ((index & 0xFFF) + (index & 0xFFF) > 0xFFF ? FLAG_H : 0);
                    index = (index + index) & 0xFFFF;
                    rFlags |= (index >> 8) & FLAG_XX;
                    END_OPCODE(2, 15)

                // LD Ii, (nn) - 20
                case 0x2A: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    index = ((readMemory(addr + 1)) << 8) | readMemory(addr);
                    END_OPCODE(4, 20) }

                // DEC Ii - 10
                case 0x2B:
                    index = (index - 1) & 0xFFFF;
                    END_OPCODE(2, 10)

                // INC IiL - 8
                case 0x2C:
                    rFlags = (rFlags & FLAG_C) | ((index & 0xFF) == 0x7F ? FLAG_PV : 0);
                    index = (index & 0xFF00) | ((index + 1) & 0xFF);
                    rFlags |= GET_FLAG_SZ(index & 0xFF) | ((index & 0x0F) == 0 ? FLAG_H : 0);
                    END_OPCODE(2, 8)

                // DEC IiL - 8
                case 0x2D:
                    rFlags = FLAG_N | (rFlags & FLAG_C) | ((index & 0xFF) == 0x80 ? FLAG_PV : 0);
                    index = (index & 0xFF00) | (((index & 0xFF) - 1) & 0xFF);
                    rFlags |= GET_FLAG_SZ(index & 0xFF) | ((index & 0x0F) == 15 ? FLAG_H : 0);
                    END_OPCODE(2, 8)

                // LD IiL, n - 11
                case 0x2E:
                    index = (index & 0xFF00) | readMemory(rPC + 2);
                    END_OPCODE(3, 11)

                // INC (Ii+d) - 23 - SZHPN
                case 0x34: {
                    const unsigned addr = index + (int8_t)readMemory(rPC + 2);
                    uint8_t mem = readMemory(addr);
                    rFlags = (rFlags & FLAG_C) | (mem == 0x7F ? FLAG_PV : 0);
                    mem++;
                    rFlags |= GET_FLAG_SZ(mem) | ((mem & 0x0F) == 0 ? FLAG_H : 0);
                    writeMemory(addr, mem);
                    END_OPCODE(3, 23) }

                // DEC (Ii+d) - 23 - SZHPN
                case 0x35: {
                    const unsigned addr = index + (int8_t)readMemory(rPC + 2);
                    uint8_t mem = readMemory(addr);
                    rFlags = FLAG_N | (rFlags & FLAG_C) | (mem == 0x80 ? FLAG_PV : 0);
                    mem--;
                    rFlags |= GET_FLAG_SZ(mem) | ((mem & 0x0F) == 15 ? FLAG_H : 0);
                    writeMemory(addr, mem);
                    END_OPCODE(3, 23) }

                // LD (Ii+d), n - 19
                case 0x36:
                    writeMemory(index + (int8_t)readMemory(rPC + 2), readMemory(rPC + 3));
                    END_OPCODE(4, 19)

                // ADD Ii, SP - 15 - HPNC
                case 0x39:
                    rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_PV)) | (index + rSP > 0xFFFF ? FLAG_C : 0) |
                             ((index & 0xFFF) + (rSP & 0xFFF) > 0xFFF ? FLAG_H : 0);
                    index = (index + rSP) & 0xFFFF;
                    rFlags |= (index >> 8) & FLAG_XX;
                    END_OPCODE(2, 15)

                // LD r, IiH - 8
                case 0x44: case 0x4C: case 0x54: case 0x5C: case 0x7C:
                    regs[(opCode1 >> 3) & 7] = index >> 8;
                    END_OPCODE(2, 8)

                // LD r, IiL - 8
                case 0x45: case 0x4D: case 0x55: case 0x5D: case 0x7D:
                    regs[(opCode1 >> 3) & 7] = index & 0xFF;
                    END_OPCODE(2, 8)

                // LD r, (Ii+d) - 19
                case 0x46: case 0x4E: case 0x56: case 0x5E: case 0x66: case 0x6E: case 0x7E:
                    regs[(opCode1 >> 3) & 7] = readMemory(index + (int8_t)readMemory(rPC + 2));
                    END_OPCODE(3, 19)

                // LD IiH, r - 8
                case 0x60: case 0x61: case 0x62: case 0x63: case 0x67:
                    index = (regs[opCode1 & 7] << 8) | (index & 0xFF);
                    END_OPCODE(2, 8)

                // LD IiH, IiH - 8
                case 0x64:
                    END_OPCODE(2, 8)

                // LD IiH, IiL - 8
                case 0x65:
                    index = ((index & 0xFF) << 8) | (index & 0xFF);
                    END_OPCODE(2, 8)

                // LD IiL, r - 8
                case 0x68: case 0x69: case 0x6A: case 0x6B: case 0x6F:
                    index = (index & 0xFF00) | regs[opCode1 & 7];
                    END_OPCODE(2, 8)

                // LD IiL, IiH - 8
                case 0x6C:
                    index = (index & 0xFF00) | (index >> 8);
                    END_OPCODE(2, 8)

                // LD IiL, IiL - 8
                case 0x6D:
                    END_OPCODE(2, 8)

                // LD (Ii+d), r - 19
                case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: case 0x77:
                    writeMemory(index + (int8_t)readMemory(rPC + 2), regs[opCode1 & 7]);
                    END_OPCODE(3, 19)

                // ADD A, IiH - 8 - SZHPNC
                case 0x84:
                    rFlags = GET_ADD_FLAG_HVNC(index >> 8);
                    rA += index >> 8;
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8)

                // ADD A, IiL - 8 - SZHPNC
                case 0x85:
                    rFlags = GET_ADD_FLAG_HVNC(index & 0xFF);
                    rA += index & 0xFF;
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8)

                // ADD A, (Ii+d) - 19 - SZHPNC
                case 0x86: {
                    const uint8_t mem = readMemory(index + (int8_t)readMemory(rPC + 2));
                    rFlags = GET_ADD_FLAG_HVNC(mem);
                    rA += mem;
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(3, 19) }

                // ADC A, IiH - 8 - SZHPNC
                case 0x8C: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_ADC_FLAG_HVNC(index >> 8);
                    rA += (index >> 8) + (tmpFlags & FLAG_C);
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8) }

                // ADC A, IiL - 8 - SZHPNC
                case 0x8D: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_ADC_FLAG_HVNC(index & 0xFF);
                    rA += (index & 0xFF) + (tmpFlags & FLAG_C);
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8) }

                // ADC A, (Ii+d) - 19 - SZHPNC
                case 0x8E: {
                    const uint8_t tmpFlags = rFlags;
                    const uint8_t addr = readMemory(index + (int8_t)readMemory(rPC + 2));
                    rFlags = GET_ADC_FLAG_HVNC(addr);
                    rA += addr + (tmpFlags & FLAG_C);
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(3, 19) }

                // SUB IiH - 8 - SZHPNC
                case 0x94:
                    rFlags = GET_SUB_FLAG_HVNC(index >> 8);
                    rA -= index >> 8;
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8)

                // SUB IiL - 8 - SZHPNC
                case 0x95:
                    rFlags = GET_SUB_FLAG_HVNC(index & 0xFF);
                    rA -= index & 0xFF;
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8)

                // SUB (Ii+d) - 19 - SZHPNC
                case 0x96: {
                    const uint8_t mem = readMemory(index + (int8_t)readMemory(rPC + 2));
                    rFlags = GET_SUB_FLAG_HVNC(mem);
                    rA -= mem;
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(3, 19) }

                // SBC A, IiH - 8 - SZHPNC
                case 0x9C: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_SBC_FLAG_HVNC(index >> 8);
                    rA -= (index >> 8) + (tmpFlags & FLAG_C);
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8) }

                // SBC A, IiL - 8 - SZHPNC
                case 0x9D: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_SBC_FLAG_HVNC(index & 0xFF);
                    rA -= (index & 0xFF) + (tmpFlags & FLAG_C);
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8) }

                // SBC A, (Ii+d) - 19 - SZHPNC
                case 0x9E: {
                    const uint8_t tmpFlags = rFlags;
                    const uint8_t addr = readMemory(index + (int8_t)readMemory(rPC + 2));
                    rFlags = GET_SBC_FLAG_HVNC(addr);
                    rA -= addr + (tmpFlags & FLAG_C);
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(3, 19) }

                // AND IiH - 8 - SZHPNC
                case 0xA4:
                    rA &= index >> 8;
                    rFlags = FLAG_H | GET_FLAG_SZP(rA);
                    END_OPCODE(2, 8)

                // AND IiL - 8 SZHPNC
                case 0xA5:
                    rA &= index & 0xFF;
                    rFlags = FLAG_H | GET_FLAG_SZP(rA);
                    END_OPCODE(2, 8)

                // AND (Ii+d) - 19 - SZHPNC
                case 0xA6:
                    rA &= readMemory(index + (int8_t)readMemory(rPC + 2));
                    rFlags = FLAG_H | GET_FLAG_SZP(rA);
                    END_OPCODE(3, 19)

                // XOR IiH - 8 - SZHPNC
                case 0xAC:
                    rA ^= index >> 8;
                    rFlags = GET_FLAG_SZP(rA);
                    END_OPCODE(2, 8)

                // XOR IiL - 8 - SZHPNC
                case 0xAD:
                    rA ^= index & 0xFF;
                    rFlags = GET_FLAG_SZP(rA);
                    END_OPCODE(2, 8)

                // XOR (Ii+d) - 19 - SZHPNC
                case 0xAE:
                    rA ^= readMemory(index + (int8_t)readMemory(rPC + 2));
                    rFlags = GET_FLAG_SZP(rA);
                    END_OPCODE(3, 19)

                // OR IiH - 8 - SZHPNC
                case 0xB4:
                    rA |= (index >> 8) & 0xFF;
                    rFlags = GET_FLAG_SZP(rA);
                    END_OPCODE(2, 8)

                // OR IiL - 8 - SZHPNC
                case 0xB5:
                    rA |= index & 0xFF;
                    rFlags = GET_FLAG_SZP(rA);
                    END_OPCODE(2, 8)

                // OR (Ii+d) - 19 - SZHPNC
                case 0xB6:
                    rA |= readMemory(index + (int8_t)readMemory(rPC + 2));
                    rFlags = GET_FLAG_SZP(rA);
                    END_OPCODE(3, 19)

                // CP IiH - 8 - SZHPNC
                case 0xBC: {
                    const uint8_t IiH = index >> 8;
                    rFlags = GET_SUB_FLAG_HVNC(IiH) | GET_FLAG_SZ(rA - IiH);
                    END_OPCODE(2, 8) }

                // CP IiL - 8 - SZHPNC
                case 0xBD: {
                    const uint8_t IiL = index & 0xFF;
                    rFlags = GET_SUB_FLAG_HVNC(IiL) | GET_FLAG_SZ(rA - IiL);
                    END_OPCODE(2, 8) }

                // CP (Ii+d) - 19 - SZHPNC
                case 0xBE: {
                    const uint8_t mem = readMemory(index + (int8_t)readMemory(rPC + 2));
                    rFlags = GET_SUB_FLAG_HVNC(mem) | GET_FLAG_SZ(rA - mem);
                    END_OPCODE(3, 19) }

                // Prefix DD/FD CB
                case 0xCB: {
                    const uint8_t opCode3 = readMemory(rPC + 3);
                    const unsigned addr = index + (int8_t)readMemory(rPC + 2);
                    uint8_t mem = readMemory(addr);

                    switch (opCode3) {

                        // RLC (Ii+d), #r# - 23 - SZHPNC
                        case 0x00: case 0x01: case 0x02: case 0x03: case 0x04: case 0x05: case 0x06: case 0x07: {
                            mem = (mem << 1) | (mem >> 7);
                            rFlags = GET_FLAG_SZP(mem) | (mem & FLAG_C);
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23) }

                        // RRC (Ii+d), #r# - 23 - SZHPNC
                        case 0x08: case 0x09: case 0x0A: case 0x0B: case 0x0C: case 0x0D: case 0x0E: case 0x0F: {
                            mem = (mem >> 1) | (mem << 7);
                            rFlags = GET_FLAG_SZP(mem) | (mem & 0x80 ? FLAG_C : 0);
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23) }

                        // RL (Ii+d), #r# - 23 - SZHPNC
                        case 0x10: case 0x11: case 0x12: case 0x13: case 0x14: case 0x15: case 0x16: case 0x17: {
                            byte2 = mem;
                            mem = (mem << 1) | (rFlags & FLAG_C);
                            rFlags = GET_FLAG_SZP(mem) | (byte2 >> 7);
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23) }

                        // RR (Ii+d), #r# - 23 - SZHPNC
                        case 0x18: case 0x19: case 0x1A: case 0x1B: case 0x1C: case 0x1D: case 0x1E: case 0x1F: {
                            byte2 = mem;
                            mem = (mem >> 1) | (rFlags << 7);
                            rFlags = GET_FLAG_SZP(mem) | (byte2 & 1);
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23) }

                        // SLA (Ii+d), #r# - 23 - SZHPNC
                        case 0x20: case 0x21: case 0x22: case 0x23: case 0x24: case 0x25: case 0x26: case 0x27: {
                            rFlags = mem >> 7;
                            mem <<= 1;
                            rFlags |= GET_FLAG_SZP(mem);
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23) }

                        // SRA (Ii+d), #r# - 23 - SZHPNC
                        case 0x28: case 0x29: case 0x2A: case 0x2B: case 0x2C: case 0x2D: case 0x2E: case 0x2F: {
                            rFlags = mem & FLAG_C;
                            mem = ((int8_t)mem) >> 1;
                            rFlags |= GET_FLAG_SZP(mem);
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23) }

                        // SLL (Ii+d), #r# - 23 - SZHPNC
                        case 0x30: case 0x31: case 0x32: case 0x33: case 0x34: case 0x35: case 0x36: case 0x37: {
                            rFlags = mem >> 7;
                            mem <<= 1;
                            mem++;
                            rFlags |= GET_FLAG_SZP(mem);
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23) }

                        // SRL (Ii+d), #r# - 23 - SZHPNC
                        case 0x38: case 0x39: case 0x3A: case 0x3B: case 0x3C: case 0x3D: case 0x3E: case 0x3F: {
                            rFlags = mem & FLAG_C;
                            mem >>= 1;
                            rFlags |= GET_FLAG_SZP(mem);
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23) }

                        // BIT b, (Ii+d) - 20 - SZHPN
                        case 0x40: case 0x41: case 0x42: case 0x43: case 0x44: case 0x45: case 0x46: case 0x47:
                        case 0x48: case 0x49: case 0x4A: case 0x4B: case 0x4C: case 0x4D: case 0x4E: case 0x4F:
                        case 0x50: case 0x51: case 0x52: case 0x53: case 0x54: case 0x55: case 0x56: case 0x57:
                        case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5E: case 0x5F:
                        case 0x60: case 0x61: case 0x62: case 0x63: case 0x64: case 0x65: case 0x66: case 0x67:
                        case 0x68: case 0x69: case 0x6A: case 0x6B: case 0x6C: case 0x6D: case 0x6E: case 0x6F:
                        case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: case 0x76: case 0x77:
                        case 0x78: case 0x79: case 0x7A: case 0x7B: case 0x7C: case 0x7D: case 0x7E: case 0x7F:
                            mem = mem & (1 << ((opCode3 >> 3) & 7));
                            rFlags = (mem & FLAG_S) | GET_FLAG_Z(mem) | GET_FLAG_P(mem) |
                                     FLAG_H | ((addr >> 8) & FLAG_XX) | (rFlags & FLAG_C);
                            END_OPCODE(4, 20)

                        // RES b, (Ii+d), #r# - 23 -
                        case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87:
                        case 0x88: case 0x89: case 0x8A: case 0x8B: case 0x8C: case 0x8D: case 0x8E: case 0x8F:
                        case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: case 0x97:
                        case 0x98: case 0x99: case 0x9A: case 0x9B: case 0x9C: case 0x9D: case 0x9E: case 0x9F:
                        case 0xA0: case 0xA1: case 0xA2: case 0xA3: case 0xA4: case 0xA5: case 0xA6: case 0xA7:
                        case 0xA8: case 0xA9: case 0xAA: case 0xAB: case 0xAC: case 0xAD: case 0xAE: case 0xAF:
                        case 0xB0: case 0xB1: case 0xB2: case 0xB3: case 0xB4: case 0xB5: case 0xB6: case 0xB7:
                        case 0xB8: case 0xB9: case 0xBA: case 0xBB: case 0xBC: case 0xBD: case 0xBE: case 0xBF:
                            mem &= ~(1 << ((opCode3 >> 3) & 7));
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23)

                        // SET b, (Ii+d), #r# - 23 -
                        case 0xC0: case 0xC1: case 0xC2: case 0xC3: case 0xC4: case 0xC5: case 0xC6: case 0xC7:
                        case 0xC8: case 0xC9: case 0xCA: case 0xCB: case 0xCC: case 0xCD: case 0xCE: case 0xCF:
                        case 0xD0: case 0xD1: case 0xD2: case 0xD3: case 0xD4: case 0xD5: case 0xD6: case 0xD7:
                        case 0xD8: case 0xD9: case 0xDA: case 0xDB: case 0xDC: case 0xDD: case 0xDE: case 0xDF:
                        case 0xE0: case 0xE1: case 0xE2: case 0xE3: case 0xE4: case 0xE5: case 0xE6: case 0xE7:
                        case 0xE8: case 0xE9: case 0xEA: case 0xEB: case 0xEC: case 0xED: case 0xEE: case 0xEF:
                        case 0xF0: case 0xF1: case 0xF2: case 0xF3: case 0xF4: case 0xF5: case 0xF6: case 0xF7:
                        case 0xF8: case 0xF9: case 0xFA: case 0xFB: case 0xFC: case 0xFD: case 0xFE: case 0xFF:
                            mem |= (1 << ((opCode3 >> 3) & 7));
                            writeMemory(addr, mem);
                            if ((opCode3 & 7) != 6)
                                regs[opCode3 & 7] = mem;
                            END_OPCODE(4, 23)

                        // Not implemented yet
//                            default:
//                                DBG_PRINT_HISTORY
//                                printf("Opcode %X CB ** %02X not implemented!!!\n", opCode0, opCode3);
//                                exit(1);
                    }
                    break; }

                // POP Ii - 14
                case 0xE1:
                    index = readMemory(rSP++);
                    index |= (readMemory(rSP++)) << 8;
                    END_OPCODE(2, 14)

                // EX (SP), Ii - 23
                case 0xE3: {
                    const unsigned mem = (readMemory(rSP + 1) << 8) | readMemory(rSP);
                    writeMemory(rSP, index & 0xFF);
                    writeMemory(rSP + 1, index >> 8);
                    index = mem;
                    END_OPCODE(2, 23) }

                // PUSH Ii - 15
                case 0xE5:
                    writeMemory(--rSP, index >> 8);
                    writeMemory(--rSP, index & 0xFF);
                    END_OPCODE(2, 15)

                // JP (Ii) - 8
                case 0xE9:
                    rPC = index;
                    TClock += 8;
                    break;

                // LD SP, Ii - 10
                case 0xF9:
                    rSP = index;
                    END_OPCODE(2, 10)

                // Not implemented yet
                default:
                    DBG_PRINT_HISTORY
                    printf("Opcode %X %02X not implemented!!!\n", opCode0, opCode1);
                    END_OPCODE(2, 8);
//                        exit(1);
            }

            if (opCode0 & 0x20)
                rIY = index;
            else
                rIX = index;
            break; }

        // SBC A, n - 7 - SZHPNC
        case 0xDE: {
            const uint8_t imm = readMemory(rPC + 1);
            const uint8_t tmpFlags = rFlags;
            rFlags = GET_SBC_FLAG_HVNC(imm);
            rA -= imm + (tmpFlags & FLAG_C);
            rFlags |= GET_FLAG_SZ(rA);
            END_OPCODE(2, 7) }

        // RET PO - 5/11
        case 0xE0:
            if (rFlags & FLAG_PV) {
                END_OPCODE(1, 5)
            } else {
                rPC = readMemory(rSP++);
                rPC |= readMemory(rSP++) << 8;
                TClock += 11;
                break;
            }

        // POP HL - 10
        case 0xE1:
            rL = readMemory(rSP++);
            rH = readMemory(rSP++);
            END_OPCODE(1, 10)

        // JP PO, cc - 10
        case 0xE2:
            if (rFlags & FLAG_PV) {
                END_OPCODE(3, 10)
            } else {
                rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
                TClock += 10;
                break;
            }

        // EX (SP), HL - 19
        case 0xE3: {
            const uint8_t tmpL = rL;
            rL = readMemory(rSP);
            writeMemory(rSP, tmpL);
            const uint8_t tmpH = rH;
            rH = readMemory(rSP + 1);
            writeMemory(rSP + 1, tmpH);
            END_OPCODE(1, 19) }

        // CALL PO - 10/17
        case 0xE4:
            if (rFlags & FLAG_PV) {
                END_OPCODE(3, 10);
            } else {
                rPC += 3;
                writeMemory(--rSP, rPC >> 8);
                writeMemory(--rSP, rPC & 0xFF);
                rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
                TClock += 17;
                break;
            }

        // PUSH HL - 11
        case 0xE5:
            writeMemory(--rSP, rH);
            writeMemory(--rSP, rL);
            END_OPCODE(1, 11)

        // AND n - 7 - SZHPNC
        case 0xE6:
            rA &= readMemory(rPC + 1);
            rFlags = FLAG_H | GET_FLAG_SZP(rA);
            END_OPCODE(2, 7)

        // RET PE - 5/11
        case 0xE8:
            if (rFlags & FLAG_PV) {
                rPC = readMemory(rSP++);
                rPC |= readMemory(rSP++) << 8;
                TClock += 11;
                break;
            } else {
                END_OPCODE(1, 5)
            }

        // JP (HL) - 4
        case 0xE9:
            rPC = rHL;
            TClock += 4;
            break;

        // JP PE, cc - 10
        case 0xEA:
            if (rFlags & FLAG_PV) {
                rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
                TClock += 10;
                break;
            } else {
                END_OPCODE(3, 10)
            }

        // EX DE, HL - 4
        case 0xEB: {
            const uint8_t tmpD = rD;
            const uint8_t tmpE = rE;
            rD = rH;
            rE = rL;
            rH = tmpD;
            rL = tmpE;
            END_OPCODE(1, 4) }

        // CALL PE - 10/17
        case 0xEC:
            if (rFlags & FLAG_PV) {
                rPC += 3;
                writeMemory(--rSP, rPC >> 8);
                writeMemory(--rSP, rPC & 0xFF);
                rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
                TClock += 17;
                break;
            } else {
                END_OPCODE(3, 10);
            }

        // Prefix ED
        case 0xED: {
            rR++;
#ifdef WAIT_ON_M1
            TClock++;   // WAIT signal for every M1 state
#endif

            const uint8_t opCode1 = readMemory(rPC + 1);
            switch (opCode1) {

                // IN r, (C) - 12
                case 0x40: case 0x48: case 0x50: case 0x58: case 0x60: case 0x68: case 0x78:
                    regs[(opCode1 >> 3) & 7] = readIO(rC);
                    rFlags = GET_FLAG_SZP(regs[(opCode1 >> 3) & 7]) | (rFlags | FLAG_C);
                    END_OPCODE(2, 12)

                // OUT (C), r - 12
                case 0x41: case 0x49: case 0x51: case 0x59: case 0x61: case 0x69: case 0x79:
                    writeIO(rC, regs[(opCode1 >> 3) & 7]);
                    END_OPCODE(2, 12)

                // SBC HL, BC - 15
                case 0x42: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_SBC16_FLAG_HVNC(rBC);
                    const unsigned tmpHL = rHL - rBC - (tmpFlags & FLAG_C);
                    rH = tmpHL >> 8;
                    rL = tmpHL & 0xFF;
                    rFlags |= (rH & (FLAG_S | FLAG_XX)) | (tmpHL == 0 ? FLAG_Z : 0);
                    END_OPCODE(2, 15) }

                // LD (nn), BC - 20
                case 0x43: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    writeMemory(addr, rC);
                    writeMemory(addr + 1, rB);
                    END_OPCODE(4, 20) }

                // NEG - 8 - SZHPNC
                case 0x44:
                    rFlags = FLAG_N | ((rA & 15) > 0 ? FLAG_H : 0) | (rA != 0 ? FLAG_C : 0);
                    if (rA != 0x80)
                        rA = -rA;
                    else
                        rFlags |= FLAG_PV;
                    rFlags |= GET_FLAG_SZ(rA);
                    END_OPCODE(2, 8)

                // RETN - 14
                case 0x45:
                    IFF1 = IFF2;
                    rPC = readMemory(rSP++);
                    rPC |= readMemory(rSP++) << 8;
                    TClock += 14;
                    break;

                // IM 0 - 8
                case 0x46:
                    printf("Interrupt mode 0 not supported!\n");
                    exit(1);

                // LD I, A - 9
                case 0x47:
                    rI = rA;
                    END_OPCODE(2, 9)

                // ADC HL, BC - 15 - SZHPNC
                case 0x4A: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_ADC16_FLAG_HVNC(rBC);
                    const unsigned tmpHL = rHL + rBC + (tmpFlags & FLAG_C);
                    rH = tmpHL >> 8;
                    rL = tmpHL & 0xFF;
                    rFlags |= (rH & (FLAG_S | FLAG_XX)) | (tmpHL == 0 ? FLAG_Z : 0);
                    END_OPCODE(2, 15) }

                // LD BC, (nn) - 20
                case 0x4B: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    rC = readMemory(addr);
                    rB = readMemory(addr + 1);
                    END_OPCODE(4, 20) }

                // RETI - 14
                case 0x4D:
                    rPC = readMemory(rSP++);
                    rPC |= readMemory(rSP++) << 8;
                    TClock += 14;
                    break;

                // LD R, A - 9
                case 0x4F:
                    rR = rA;
                    rRhigh = rA & 0x80;
                    END_OPCODE(2, 9);

                // SBC HL, DE - 15
                case 0x52: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_SBC16_FLAG_HVNC(rDE);
                    const unsigned tmpHL = rHL - rDE - (tmpFlags & FLAG_C);
                    rH = tmpHL >> 8;
                    rL = tmpHL & 0xFF;
                    rFlags |= (rH & (FLAG_S | FLAG_XX)) | (tmpHL == 0 ? FLAG_Z : 0);
                    END_OPCODE(2, 15) }

                // LD (nn), DE - 20
                case 0x53: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    writeMemory(addr, rE);
                    writeMemory(addr + 1, rD);
                    END_OPCODE(4, 20) }

                // IM 1 - 8
                case 0x56:
                    im = 1;
                    END_OPCODE(2, 8)

                // LD A, I, - 9 - SZHPN
                case 0x57:
                    rA = rI;
                    rFlags = GET_FLAG_SZ(rA) | (IFF2 ? FLAG_PV : 0) | (rFlags & FLAG_C);
                    END_OPCODE(2, 9)

                // ADC HL, DE - 15 - SZHPNC
                case 0x5A: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_ADC16_FLAG_HVNC(rDE);
                    const unsigned tmpHL = rHL + rDE + (tmpFlags & FLAG_C);
                    rH = tmpHL >> 8;
                    rL = tmpHL & 0xFF;
                    rFlags |= (rH & (FLAG_S | FLAG_XX)) | (tmpHL == 0 ? FLAG_Z : 0);
                    END_OPCODE(2, 15) }

                // LD DE, (nn) - 20
                case 0x5B: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    rE = readMemory(addr);
                    rD = readMemory(addr + 1);
                    END_OPCODE(4, 20) }

                // IM 2 - 8
                case 0x5E:
                    im = 2;
                    END_OPCODE(2, 8)

                // LD A, R - 9 - SZHPN
                case 0x5F:
                    rA = (rR & 0x7F) | rRhigh;
                    rFlags = GET_FLAG_SZ(rA) | (IFF2 ? FLAG_PV : 0) | (rFlags & FLAG_C);
                    END_OPCODE(2, 9)

                // SBC HL, HL - 15
                case 0x62: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_SBC16_FLAG_HVNC(rHL);
                    const unsigned tmpHL = rHL - rHL - (tmpFlags & FLAG_C);
                    rH = tmpHL >> 8;
                    rL = tmpHL & 0xFF;
                    rFlags |= (rH & (FLAG_S | FLAG_XX)) | (tmpHL == 0 ? FLAG_Z : 0);
                    END_OPCODE(2, 15) }

                // LD (nn), HL - 20
                case 0x63: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    writeMemory(addr, rL);
                    writeMemory(addr + 1, rH);
                    END_OPCODE(4, 20) }

                // RRD - 18 - SZHPN
                case 0x67: {
                    const uint8_t mem = readMemory(rHL);
                    byte = (mem >> 4) | (rA << 4);
                    rA = (rA & 0xF0) | (mem & 0xF);
                    writeMemory(rHL, byte);
                    rFlags = GET_FLAG_SZP(rA) | (rFlags & FLAG_C);
                    END_OPCODE(2, 18) }

                // ADC HL, HL - 15 - SZHPNC
                case 0x6A: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_ADC16_FLAG_HVNC(rHL);
                    const unsigned tmpHL = rHL + rHL + (tmpFlags & FLAG_C);
                    rH = tmpHL >> 8;
                    rL = tmpHL & 0xFF;
                    rFlags |= (rH & (FLAG_S | FLAG_XX)) | (tmpHL == 0 ? FLAG_Z : 0);
                    END_OPCODE(2, 15) }

                // LD HL, (nn) - 20
                case 0x6B: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    rL = readMemory(addr);
                    rH = readMemory(addr + 1);
                    END_OPCODE(4, 20) }

                // RLD - 18 - SZHPN
                case 0x6F: {
                    const uint8_t mem = readMemory(rHL);
                    byte = (mem << 4) | (rA & 0xF);
                    rA = (rA & 0xF0) | (mem >> 4);
                    writeMemory(rHL, byte);
                    rFlags = GET_FLAG_SZP(rA) | (rFlags & FLAG_C);
                    END_OPCODE(2, 18) }

                // SBC HL, SP - 15
                case 0x72: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_SBC16_FLAG_HVNC(rSP);
                    const unsigned tmpHL = rHL - rSP - (tmpFlags & FLAG_C);
                    rH = tmpHL >> 8;
                    rL = tmpHL & 0xFF;
                    rFlags |= (rH & (FLAG_S | FLAG_XX)) | (tmpHL == 0 ? FLAG_Z : 0);
                    END_OPCODE(2, 15) }

                // LD (nn), SP - 20
                case 0x73: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    writeMemory(addr, rSP & 0xFF);
                    writeMemory(addr + 1, rSP >> 8);
                    END_OPCODE(4, 20) }

                // ADC HL, SP - 15 - SZHPNC
                case 0x7A: {
                    const uint8_t tmpFlags = rFlags;
                    rFlags = GET_ADC16_FLAG_HVNC(rSP);
                    const unsigned tmpHL = rHL + rSP + (tmpFlags & FLAG_C);
                    rH = tmpHL >> 8;
                    rL = tmpHL & 0xFF;
                    rFlags |= (rH & (FLAG_S | FLAG_XX)) | (tmpHL == 0 ? FLAG_Z : 0);
                    END_OPCODE(2, 15) }

                // LD SP, (nn) - 20
                case 0x7B: {
                    const unsigned addr = (readMemory(rPC + 3) << 8) | readMemory(rPC + 2);
                    rSP = ((readMemory(addr + 1)) << 8) | readMemory(addr);
                    END_OPCODE(4, 20) }

                // LDI - 16 - HPN
                case 0xA0: {
                    const uint8_t mem = readMemory(rHL);
                    writeMemory(rDE, mem);
                    rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_C)) | ((mem + rA) & 0x08) | ((mem + rA) & 0x02 ? 0x20 : 0);
                    rE++;
                    if (!rE) rD++;
                    rL++;
                    if (!rL) rH++;
                    const unsigned tmpBC = rBC - 1;
                    if (tmpBC)
                        rFlags |= FLAG_PV;
                    rB = tmpBC >> 8;
                    rC = tmpBC & 0xFF;
                    END_OPCODE(2, 16) }

                // CPI - 16 - SZHPN
                case 0xA1: {
                    const uint8_t mem = readMemory(rHL);
                    rFlags = FLAG_N | GET_SUB_FLAG_H(mem) | GET_FLAG_SZ(rA - mem) | (rFlags & FLAG_C);
                    rL++;
                    if (!rL) rH++;
                    const unsigned tmpBC = rBC - 1;
                    if (tmpBC)
                        rFlags |= FLAG_PV;
                    rB = tmpBC >> 8;
                    rC = tmpBC & 0xFF;
                    END_OPCODE(2, 16) }

                // INI - 16 - ZN
                case 0xA2:
                    writeMemory(rHL, readIO(rC));
                    rL++;
                    if (!rL) rH++;
                    rB--;
                    rFlags = (rFlags & FLAG_C) | (rB == 0 ? FLAG_Z : 0) | FLAG_N;
                    END_OPCODE(2, 16)

                // OUTI - 16 - SZHPNC
                case 0xA3:
                    writeIO(rC, readMemory(rHL));
                    rL++;
                    if (!rL) rH++;
                    rB--;
                    rFlags = (rB == 0 ? FLAG_Z : 0) | FLAG_N | (rFlags & FLAG_C);
                    END_OPCODE(2, 16)

                // LDD - 16 - HPN
                case 0xA8: {
                    const uint8_t mem = readMemory(rHL);
                    writeMemory(rDE, mem);
                    rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_C)) | ((mem + rA) & 0x08) | ((mem + rA) & 0x02 ? 0x20 : 0);
                    tmp = rDE - 1;
                    rD = tmp >> 8;
                    rE = tmp & 0xFF;
                    tmp = rHL - 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    tmp = rBC - 1;
                    if (tmp)
                        rFlags |= FLAG_PV;
                    rB = tmp >> 8;
                    rC = tmp & 0xFF;
                    END_OPCODE(2, 16) }

                // CPD - 16 - SZHPN
                case 0xA9: {
                    const uint8_t mem = readMemory(rHL);
                    rFlags = FLAG_N | GET_SUB_FLAG_H(mem) | GET_FLAG_SZ(rA - mem) | (rFlags & FLAG_C);
                    tmp = rHL - 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    tmp = rBC - 1;
                    if (tmp)
                        rFlags |= FLAG_PV;
                    rB = tmp >> 8;
                    rC = tmp & 0xFF;
                    END_OPCODE(2, 16) }

                // IND - 16 - ZN
                case 0xAA:
                    writeMemory(rHL, readIO(rC));
                    tmp = rHL - 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    rB--;
                    rFlags = (rFlags & FLAG_C) | (rB == 0 ? FLAG_Z : 0) | FLAG_N;
                    END_OPCODE(2, 16)

                // OUTD - 16 - ZN
                case 0xAB:
                    writeIO(rC, readMemory(rHL));
                    tmp = rHL - 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    rB--;
                    rFlags = (rB == 0 ? FLAG_Z : 0) | FLAG_N | (rFlags & FLAG_C);
                    END_OPCODE(2, 16)

                // LDIR - 16/21 - HPN
                case 0xB0: {
                    const uint8_t mem = readMemory(rHL);
                    writeMemory(rDE, mem);
                    rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_C)) | ((mem + rA) & 0x08) | ((mem + rA) & 0x02 ? 0x20 : 0);
                    tmp = rDE + 1;
                    rD = tmp >> 8;
                    rE = tmp & 0xFF;
                    tmp = rHL + 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    tmp = rBC - 1;
                    rB = tmp >> 8;
                    rC = tmp & 0xFF;
                    if (tmp == 0) {
                        END_OPCODE(2, 16)
                    } else {
                        rFlags |= FLAG_PV;
                        TClock += 21;
                        break;
                    } }

                // CPIR - 16/21 - SZHPN
                case 0xB1: {
                    const uint8_t mem = readMemory(rHL);
                    rFlags = FLAG_N | GET_SUB_FLAG_H(mem) | GET_FLAG_SZ(rA - mem) | (rFlags & FLAG_C);
                    tmp = rHL + 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    tmp = rBC - 1;
                    rB = tmp >> 8;
                    rC = tmp & 0xFF;
                    if (tmp != 0)
                        rFlags |= FLAG_PV;
                    if (tmp == 0 || rA == mem) {
                        END_OPCODE(2, 16)
                    } else {
                        TClock += 21;
                        break;
                    } }

                // INIR - 16/21 - ZN
                case 0xB2:
                    writeMemory(rHL, readIO(rC));
                    tmp = rHL + 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    rB--;
                    rFlags = FLAG_N | (rFlags & FLAG_C);
                    if (rB == 0) {
                        rFlags |= FLAG_Z;
                        END_OPCODE(2, 16)
                    } else {
                        TClock += 21;
                        break;
                    }

                // OTIR - 16/21 - ZN
                case 0xB3:
                    writeIO(rC, readMemory(rHL));
                    tmp = rHL + 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    rB--;
                    rFlags = FLAG_N | (rFlags & FLAG_C);
                    if (rB == 0) {
                        rFlags |= FLAG_Z;
                        END_OPCODE(2, 16)
                    } else {
                        TClock += 21;
                        break;
                    }

                // LDDR - 16/21 - HPN
                case 0xB8: {
                    const uint8_t mem = readMemory(rHL);
                    writeMemory(rDE, mem);
                    rFlags = (rFlags & (FLAG_S | FLAG_Z | FLAG_C)) | ((mem + rA) & 0x08) | ((mem + rA) & 0x02 ? 0x20 : 0);
                    tmp = rDE - 1;
                    rD = tmp >> 8;
                    rE = tmp & 0xFF;
                    tmp = rHL - 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    tmp = rBC - 1;
                    rB = tmp >> 8;
                    rC = tmp & 0xFF;
                    if (tmp == 0) {
                        END_OPCODE(2, 16)
                    } else {
                        rFlags |= FLAG_PV;
                        TClock += 21;
                        break;
                    } }

                // CPDR - 16/21 - SZHPN
                case 0xB9: {
                    const uint8_t mem = readMemory(rHL);
                    rFlags = FLAG_N | GET_SUB_FLAG_H(mem) | GET_FLAG_SZ(rA - mem) | (rFlags & FLAG_C);
                    tmp = rHL - 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    tmp = rBC - 1;
                    rB = tmp >> 8;
                    rC = tmp & 0xFF;
                    if (tmp != 0)
                        rFlags |= FLAG_PV;
                    if (tmp == 0 || rA == mem) {
                        END_OPCODE(2, 16)
                    } else {
                        TClock += 21;
                        break;
                    } }

                // INDR - 16/21 - ZN
                case 0xBA:
                    writeMemory(rHL, readIO(rC));
                    tmp = rHL - 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    rB--;
                    rFlags = FLAG_N | (rFlags & FLAG_C);
                    if (rB == 0) {
                        rFlags |= FLAG_Z;
                        END_OPCODE(2, 16)
                    } else {
                        TClock += 21;
                        break;
                    }

                // OTDR - 16/21 - ZN
                case 0xBB:
                    writeIO(rC, readMemory(rHL));
                    tmp = rHL - 1;
                    rH = tmp >> 8;
                    rL = tmp & 0xFF;
                    rB--;
                    rFlags = FLAG_N | (rFlags & FLAG_C);
                    if (rB == 0) {
                        rFlags |= FLAG_Z;
                        END_OPCODE(2, 16)
                    } else {
                        TClock += 21;
                        break;
                    }

                // Not implemented yet
                default:
                    DBG_PRINT_HISTORY
                    printf("Opcode ED %02X not implemented!!!\n", opCode1);
                    exit(1);
            }
            break; }

        // XOR n - 7 - SZHPNC
        case 0xEE:
            rA ^= readMemory(rPC + 1);
            rFlags = GET_FLAG_SZP(rA);
            END_OPCODE(2, 7)

        // RET P - 5/11
        case 0xF0:
            if (rFlags & FLAG_S) {
                END_OPCODE(1, 5)
            } else {
                rPC = readMemory(rSP++);
                rPC |= readMemory(rSP++) << 8;
                TClock += 11;
                break;
            }

        // POP AF - 10 - SZHPNC
        case 0xF1:
            rFlags = readMemory(rSP++);
            rA = readMemory(rSP++);
            END_OPCODE(1, 10)

        // JP P, cc - 10
        case 0xF2:
            if (rFlags & FLAG_S) {
                END_OPCODE(3, 10)
            } else {
                rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
                TClock += 10;
                break;
            }

        // DI - 4
        case 0xF3:
            IFF1 = IFF2 = 0;
            END_OPCODE(1, 4)

        // CALL P - 10/17
        case 0xF4:
            if (rFlags & FLAG_S) {
                END_OPCODE(3, 10);
            } else {
                rPC += 3;
                writeMemory(--rSP, rPC >> 8);
                writeMemory(--rSP, rPC & 0xFF);
                rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
                TClock += 17;
                break;
            }

        // PUSH AF - 11
        case 0xF5:
            writeMemory(--rSP, rA);
            writeMemory(--rSP, rFlags & ~0x028);
            END_OPCODE(1, 11)

        // OR n - 7 - SZHPNC
        case 0xF6:
            rA |= readMemory(rPC + 1);
            rFlags = GET_FLAG_SZP(rA);
            END_OPCODE(2, 7)

        // RET M - 5/11
        case 0xF8:
            if (rFlags & FLAG_S) {
                rPC = readMemory(rSP++);
                rPC |= readMemory(rSP++) << 8;
                TClock += 11;
                break;
            } else {
                END_OPCODE(1, 5)
            }

        // LD SP, HL - 6
        case 0xF9:
            rSP = rHL;
            END_OPCODE(1, 6)

        // JP M, cc - 10
        case 0xFA:
            if (rFlags & FLAG_S) {
                rPC = (readMemory(rPC + 2) << 8) | readMemory(rPC + 1);
                TClock += 10;
                break;
            } else {
                END_OPCODE(3, 10)
            }

        // EI - 4
        case 0xFB:
            IFF1 = IFF2 = 1;
            rPC++;
            TClock += 4;
            executeNextOpcode();
            break;

        // CALL M - 10/17
        case 0xFC:
            if (rFlags & FLAG_S) {
                rPC += 3;
                writeMemory(--rSP, rPC >> 8);
                writeMemory(--rSP, rPC & 0xFF);
                rPC = (readMemory(rPC + 2 - 3) << 8) | readMemory(rPC + 1 - 3);
                TClock += 17;
                break;
            } else {
                END_OPCODE(3, 10);
            }

        // CP n - 7 - SZHPNC
        case 0xFE: {
            const uint8_t imm = readMemory(rPC + 1);
            rFlags = GET_SUB_FLAG_HVNC(imm) | GET_FLAG_SZ(rA - imm);
            END_OPCODE(2, 7) }

        // Not implemented yet
        default:
            DBG_PRINT_HISTORY
            printf("Opcode %02X not implemented!!!\n", opCode0);
            exit(1);
    }
}
