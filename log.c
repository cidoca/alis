#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include "cpu.h"
#include "vdp.h"
#include "memory.h"

char o_s[32];
int rh_pos = 0;

struct REGS {
    int rIXx;
    int rIYx;
    int rPCx;
    int rSPx;

    uint8_t B;
    uint8_t C;
    uint8_t D;
    uint8_t E;
    uint8_t H;
    uint8_t L;
    uint8_t Flag;
    uint8_t rAcc;

    uint8_t rRx;
    uint8_t rIx;

    uint8_t opcode[4];
} rh[10];

#define REGS_SIZE (sizeof(rh) / sizeof(struct REGS))

void update_o_s(int index);

void printOpcodeWithRegisters(int p) {
    static int t0 = 0, t2;

    t2 = TClock - t0;
    if (t2 <= 0)
        t2 += 228;
    t0 = TClock;

    update_o_s(p);
    printf("%04X: %-30s AF:%02X%02X BC:%02X%02X DE:%02X%02X HL:%02X%02X IX:%04X IY:%04X SP:%04X %s %03d/%d %d\n",
                rh[p].rPCx, o_s, rh[p].rAcc, rh[p].Flag & ~0x28, rh[p].B, rh[p].C, rh[p].D, rh[p].E, rh[p].H,
                rh[p].L, rh[p].rIXx, rh[p].rIYx, rh[p].rSPx, IFF1 ? "EI" : "DI", TClock, VDPscanLine, t2);
//    sprintf(tmp, "%04X: %d\n", rh[p].rPCx, t2);
}

void printHistory() {
    int p = rh_pos, c = REGS_SIZE;

    while (c-- > 0) {
        printOpcodeWithRegisters(p);
        if (++p >= REGS_SIZE)
            p = 0;
    }
}

int dumping = 0;
void dumpOpcode() {
    rh[rh_pos].rIXx = rIX;
    rh[rh_pos].rIYx = rIY;
    rh[rh_pos].rPCx = rPC;
    rh[rh_pos].rSPx = rSP;
    memcpy(&rh[rh_pos].B, regs, 8);
    rh[rh_pos].Flag = rFlags;
    rh[rh_pos].rRx = rR;
    rh[rh_pos].rIx = 0xFF;
    rh[rh_pos].opcode[0] = readMemory(rPC);
    rh[rh_pos].opcode[1] = readMemory(rPC + 1);
    rh[rh_pos].opcode[2] = readMemory(rPC + 2);
    rh[rh_pos].opcode[3] = readMemory(rPC + 3);

//    if (rPC == 0xDE01)
//       dumping = 1;
//        printf("#### PORRRAAAA #####\n");

    if (dumping)
//    if ((rPC >= 0x4000 && rPC < 0x8000 && (PPIportA & 0x0C) == 0x04) ||
//        (rPC >= 0x8000 && rPC < 0xC000 && (PPIportA & 0x30) == 0x20))
        printOpcodeWithRegisters(rh_pos);
    if (++rh_pos >= REGS_SIZE)
        rh_pos = 0;

    if (rSP > 0xFFFF || rPC > 0xFFFF || rIX > 0xFFFF || rIY > 0xFFFF) {
        printHistory();
        printf("Pointer overflow!!!\n");
        exit(1);
    }
}

char *uob(int p, int n) {
    char *b = o_s;

    for (int i = 0; i < 4; i++)
        if (i < n)
            b += sprintf(b, "%02X ", rh[p].opcode[i]);
        else
            b += sprintf(b, "   ");

    return b;
}

#define o0 (rh[p].opcode[0])
#define o1 (rh[p].opcode[1])
#define o2 (rh[p].opcode[2])
#define o3 (rh[p].opcode[3])

const char *pair_dd[] = {"BC", "DE", "HL", "SP"};
const char *pair_qq[] = {"BC", "DE", "HL", "AF"};
const char *reg[] = {"B", "C", "D", "E", "H", "L", "(HL)", "A"};
const char *jump[] = {"NZ", "Z", "NC", "C", "PO", "PE", "P", "M"};
#define dd(b) (pair_dd[(b >> 4) & 3])
#define qq(b) (pair_qq[(b >> 4) & 3])
#define r(b) (reg[(b >> 3) & 7])
#define r2(b) (reg[b & 7])
#define cc(b) (jump[(b >> 3) & 7])
#define cc2(b) (jump[(b >> 3) & 3])
#define nn ((o2 << 8) + o1)
#define nn2 ((o3 << 8) + o2)

void update_o_s(int p) {
    int cPCx = rh[p].rPCx;
    sprintf(o_s, "%02X %02X %02X %02X ?????", o0, o1, o2, o3);

    switch (o0) {
        case 0x00:
            sprintf(uob(p, 1), "NOP");
            break;

        case 0x01: case 0x11: case 0x21: case 0x31:
            sprintf(uob(p, 3), "LD %s, %04Xh", dd(o0), nn);
            break;

        case 0x02:
            sprintf(uob(p, 1), "LD (BC), A");
            break;

        case 0x03: case 0x13: case 0x23: case 0x33:
            sprintf(uob(p, 1), "INC %s", dd(o0));
            break;

        case 0x04: case 0x0C: case 0x14: case 0x1C: case 0x24: case 0x2C: case 0x34: case 0x3C:
            sprintf(uob(p, 1), "INC %s", r(o0));
            break;

        case 0x05: case 0x0D: case 0x15: case 0x1D: case 0x25: case 0x2D: case 0x35: case 0x3D:
            sprintf(uob(p, 1), "DEC %s", r(o0));
            break;

        case 0x06: case 0x0E: case 0x16: case 0x1E: case 0x26: case 0x2E: case 0x36: case 0x3E:
            sprintf(uob(p, 2), "LD %s, %02Xh", r(o0), o1);
            break;

        case 0x07:
            sprintf(uob(p, 1), "RLCA");
            break;

        case 0x08:
            sprintf(uob(p, 1), "EX AF, AF'");
            break;

        case 0x09: case 0x19: case 0x29: case 0x39:
            sprintf(uob(p, 1), "ADD HL, %s", dd(o0));
            break;

        case 0x0A:
            sprintf(uob(p, 1), "LD A, (BC)");
            break;

        case 0x0B: case 0x1B: case 0x2B: case 0x3B:
            sprintf(uob(p, 1), "DEC %s", dd(o0));
            break;

        case 0x0F:
            sprintf(uob(p, 1), "RRCA");
            break;

        case 0x10:
            sprintf(uob(p, 2), "DJNZ %04Xh", cPCx + 2 + (int8_t)o1);
            break;

        case 0x12:
            sprintf(uob(p, 1), "LD (DE), A");
            break;

        case 0x17:
            sprintf(uob(p, 1), "RLA");
            break;

        case 0x18:
            sprintf(uob(p, 2), "JR %04Xh", cPCx + 2 + (int8_t)o1);
            break;

        case 0x1A:
            sprintf(uob(p, 1), "LD A, (DE)");
            break;

        case 0x1F:
            sprintf(uob(p, 1), "RRA");
            break;

        case 0x20: case 0x28: case 0x30: case 0x38:
            sprintf(uob(p, 2), "JR %s, %04Xh", cc2(o0), cPCx + 2 + (int8_t)o1);
            break;

        case 0x22:
            sprintf(uob(p, 3), "LD (%04Xh), HL", nn);
            break;

        case 0x27:
            sprintf(uob(p, 1), "DAA");
            break;

        case 0x2A:
            sprintf(uob(p, 3), "LD HL, (%04Xh)", nn);
            break;

        case 0x2F:
            sprintf(uob(p, 1), "CPL");
            break;

        case 0x32:
            sprintf(uob(p, 3), "LD (%04Xh), A", nn);
            break;

        case 0x37:
            sprintf(uob(p, 1), "SCF");
            break;

        case 0x3A:
            sprintf(uob(p, 3), "LD A, (%04Xh)", nn);
            break;

        case 0x3F:
            sprintf(uob(p, 1), "CCF");
            break;

        case 0x40: case 0x41: case 0x42: case 0x43: case 0x44: case 0x45: case 0x46: case 0x47:
        case 0x48: case 0x49: case 0x4A: case 0x4B: case 0x4C: case 0x4D: case 0x4E: case 0x4F:
        case 0x50: case 0x51: case 0x52: case 0x53: case 0x54: case 0x55: case 0x56: case 0x57:
        case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5E: case 0x5F:
        case 0x60: case 0x61: case 0x62: case 0x63: case 0x64: case 0x65: case 0x66: case 0x67:
        case 0x68: case 0x69: case 0x6A: case 0x6B: case 0x6C: case 0x6D: case 0x6E: case 0x6F:
        case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75:            case 0x77:
        case 0x78: case 0x79: case 0x7A: case 0x7B: case 0x7C: case 0x7D: case 0x7E: case 0x7F:
            sprintf(uob(p, 1), "LD %s, %s", r(o0), r2(o0));
            break;

        case 0x76:
            sprintf(uob(p, 1), "HALT");
            break;

        case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87:
            sprintf(uob(p, 1), "ADD A, %s", r2(o0));
            break;

        case 0x88: case 0x89: case 0x8A: case 0x8B: case 0x8C: case 0x8D: case 0x8E: case 0x8F:
            sprintf(uob(p, 1), "ADC A, %s", r2(o0));
            break;

        case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: case 0x97:
            sprintf(uob(p, 1), "SUB %s", r2(o0));
            break;

        case 0x98: case 0x99: case 0x9A: case 0x9B: case 0x9C: case 0x9D: case 0x9E: case 0x9F:
            sprintf(uob(p, 1), "SBC A, %s", r2(o0));
            break;

        case 0xA0: case 0xA1: case 0xA2: case 0xA3: case 0xA4: case 0xA5: case 0xA6: case 0xA7:
            sprintf(uob(p, 1), "AND %s", r2(o0));
            break;

        case 0xA8: case 0xA9: case 0xAA: case 0xAB: case 0xAC: case 0xAD: case 0xAE: case 0xAF:
            sprintf(uob(p, 1), "XOR %s", r2(o0));
            break;

        case 0xB0: case 0xB1: case 0xB2: case 0xB3: case 0xB4: case 0xB5: case 0xB6: case 0xB7:
            sprintf(uob(p, 1), "OR %s", r2(o0));
            break;

        case 0xB8: case 0xB9: case 0xBA: case 0xBB: case 0xBC: case 0xBD: case 0xBE: case 0xBF:
            sprintf(uob(p, 1), "CP %s", r2(o0));
            break;

        case 0xC0: case 0xC8: case 0xD0: case 0xD8: case 0xE0: case 0xE8: case 0xF0: case 0xF8:
            sprintf(uob(p, 1), "RET %s", cc(o0));
            break;

        case 0xC1: case 0xD1: case 0xE1: case 0xF1:
            sprintf(uob(p, 1), "POP %s", qq(o0));
            break;

        case 0xC2: case 0xCA: case 0xD2: case 0xDA: case 0xE2: case 0xEA: case 0xF2: case 0xFA:
            sprintf(uob(p, 3), "JP %s, %04Xh", cc(o0), nn);
            break;

        case 0xC3:
            sprintf(uob(p, 3), "JP %04Xh", nn);
            break;

        case 0xC4: case 0xCC: case 0xD4: case 0xDC: case 0xE4: case 0xEC: case 0xF4: case 0xFC:
            sprintf(uob(p, 3), "CALL %s, %04Xh", cc(o0), nn);
            break;

        case 0xC5: case 0xD5: case 0xE5: case 0xF5:
            sprintf(uob(p, 1), "PUSH %s", qq(o0));
            break;

        case 0xC6:
            sprintf(uob(p, 2), "ADD A, %02Xh", o1);
            break;

        case 0xC7: case 0xCF: case 0xD7: case 0xDF: case 0xE7: case 0xEF: case 0xF7: case 0xFF:
            sprintf(uob(p, 1), "RST %02Xh", ((o0 >> 3) & 7) * 8);
            break;

        case 0xC9:
            sprintf(uob(p, 1), "RET");
            break;

        case 0xCB:
            if (o1 >= 0xC0)
                sprintf(uob(p, 2), "SET %d, %s", (o1 >> 3) & 7, r2(o1));
            else if (o1 >= 0x80)
                sprintf(uob(p, 2), "RES %d, %s", (o1 >> 3) & 7, r2(o1));
            else if (o1 >= 0x40)
                sprintf(uob(p, 2), "BIT %d, %s", (o1 >> 3) & 7, r2(o1));
            else if (o1 >= 0x38)
                sprintf(uob(p, 2), "SRL %s", r2(o1));
            else if (o1 >= 0x30)
                sprintf(uob(p, 2), "SLL %s", r2(o1));
            else if (o1 >= 0x28)
                sprintf(uob(p, 2), "SRA %s", r2(o1));
            else if (o1 >= 0x20)
                sprintf(uob(p, 2), "SLA %s", r2(o1));
            else if (o1 >= 0x18)
                sprintf(uob(p, 2), "RR %s", r2(o1));
            else if (o1 >= 0x10)
                sprintf(uob(p, 2), "RL %s", r2(o1));
            else if (o1 >= 0x08)
                sprintf(uob(p, 2), "RRC %s", r2(o1));
            else
                sprintf(uob(p, 2), "RLC %s", r2(o1));
            break;

        case 0xCD:
            sprintf(uob(p, 3), "CALL %04Xh", nn);
            break;

        case 0xCE:
            sprintf(uob(p, 2), "ADC A, %02Xh", o1);
            break;

        case 0xD3:
            sprintf(uob(p, 2), "OUT (%02Xh), A", o1);
            break;

        case 0xD6:
            sprintf(uob(p, 2), "SUB %02Xh", o1);
            break;

        case 0xD9:
            sprintf(uob(p, 1), "EXX");
            break;

        case 0xDB:
            sprintf(uob(p, 2), "IN A, (%02Xh)", o1);
            break;

        case 0xDD: case 0xFD: {
            char *index = o0 & 0x20 ? "IY" : "IX";
            switch (o1) {
                case 0x09: case 0x19: case 0x39:
                    sprintf(uob(p, 2), "ADD %s, %s", index, dd(o1));
                    break;

                case 0x21:
                    sprintf(uob(p, 4), "LD %s, %04Xh", index, nn2);
                    break;

                case 0x22:
                    sprintf(uob(p, 4), "LD (%04Xh), %s", nn2, index);
                    break;

                case 0x23:
                    sprintf(uob(p, 2), "INC %s", index);
                    break;

                case 0x24:
                    sprintf(uob(p, 2), "INC %sH", index);
                    break;

                case 0x25:
                    sprintf(uob(p, 2), "DEC %sH", index);
                    break;

                case 0x26:
                    sprintf(uob(p, 3), "LD %sH, %02Xh", index, o2);
                    break;

                case 0x29:
                    sprintf(uob(p, 2), "ADD %s, %s", index, index);
                    break;

                case 0x2A:
                    sprintf(uob(p, 4), "LD %s, (%04Xh)", index, nn2);
                    break;

                case 0x2B:
                    sprintf(uob(p, 2), "DEC %s", index);
                    break;

                case 0x2C:
                    sprintf(uob(p, 2), "INC %sL", index);
                    break;

                case 0x2D:
                    sprintf(uob(p, 2), "DEC %sL", index);
                    break;

                case 0x2E:
                    sprintf(uob(p, 3), "LD %sL, %02Xh", index, o2);
                    break;

                case 0x34:
                    sprintf(uob(p, 3), "INC (%s+%02Xh)", index, o2);
                    break;

                case 0x35:
                    sprintf(uob(p, 3), "DEC (%s+%02Xh)", index, o2);
                    break;

                case 0x36:
                    sprintf(uob(p, 4), "LD (%s+%02Xh), %02Xh", index, o2, o3);
                    break;

                case 0x44: case 0x4C: case 0x54: case 0x5C: case 0x7C:
                    sprintf(uob(p, 2), "LD %s, %sH", r(o1), index);
                    break;

                case 0x45: case 0x4D: case 0x55: case 0x5D: case 0x7D:
                    sprintf(uob(p, 2), "LD %s, %sL", r(o1), index);
                    break;

                case 0x46: case 0x4E: case 0x56: case 0x5E: case 0x66: case 0x6E: case 0x7E:
                    sprintf(uob(p, 3), "LD %s, (%s+%02Xh)", r(o1), index, o2);
                    break;

                case 0x60: case 0x61: case 0x62: case 0x63: case 0x67:
                    sprintf(uob(p, 2), "LD %sH, %s", index, r2(o1));
                    break;

                case 0x64:
                    sprintf(uob(p, 2), "LD %sH, %sH", index, index);
                    break;

                case 0x65:
                    sprintf(uob(p, 2), "LD %sH, %sL", index, index);
                    break;

                case 0x68: case 0x69: case 0x6A: case 0x6B: case 0x6F:
                    sprintf(uob(p, 2), "LD %sL, %s", index, r2(o1));
                    break;

                case 0x6C:
                    sprintf(uob(p, 2), "LD %sL, %sH", index, index);
                    break;

                case 0x6D:
                    sprintf(uob(p, 2), "LD %sL, %sL", index, index);
                    break;

                case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: case 0x77:
                    sprintf(uob(p, 3), "LD (%s+%02Xh), %s", index, o2, r2(o1));
                    break;

                case 0x84:
                    sprintf(uob(p, 2), "ADD A, %sH", index);
                    break;

                case 0x85:
                    sprintf(uob(p, 2), "ADD A, %sL", index);
                    break;

                case 0x86:
                    sprintf(uob(p, 3), "ADD A, (%s+%02Xh)", index, o2);
                    break;

                case 0x8C:
                    sprintf(uob(p, 2), "ADC A, %sH", index);
                    break;

                case 0x8D:
                    sprintf(uob(p, 2), "ADC A, %sL", index);
                    break;

                case 0x8E:
                    sprintf(uob(p, 3), "ADC A, (%s+%02Xh)", index, o2);
                    break;

                case 0x94:
                    sprintf(uob(p, 2), "SUB %sH", index);
                    break;

                case 0x95:
                    sprintf(uob(p, 2), "SUB %sL", index);
                    break;

                case 0x96:
                    sprintf(uob(p, 3), "SUB (%s+%02Xh)", index, o2);
                    break;

                case 0x9C:
                    sprintf(uob(p, 2), "SBC %sH", index);
                    break;

                case 0x9D:
                    sprintf(uob(p, 2), "SBC %sL", index);
                    break;

                case 0x9E:
                    sprintf(uob(p, 3), "SBC A, (%s+%02Xh)", index, o2);
                    break;

                case 0xA4:
                    sprintf(uob(p, 2), "AND %sH", index);
                    break;

                case 0xA5:
                    sprintf(uob(p, 2), "AND %sL", index);
                    break;

                case 0xA6:
                    sprintf(uob(p, 3), "AND (%s+%02Xh)", index, o2);
                    break;

                case 0xAC:
                    sprintf(uob(p, 2), "XOR %sH", index);
                    break;

                case 0xAD:
                    sprintf(uob(p, 2), "XOR %sL", index);
                    break;

                case 0xAE:
                    sprintf(uob(p, 3), "XOR (%s+%02Xh)", index, o2);
                    break;

                case 0xB4:
                    sprintf(uob(p, 2), "OR %sH", index);
                    break;

                case 0xB5:
                    sprintf(uob(p, 2), "OR %sL", index);
                    break;

                case 0xB6:
                    sprintf(uob(p, 3), "OR (%s+%02Xh)", index, o2);
                    break;

                case 0xBC:
                    sprintf(uob(p, 2), "CP %sH", index);
                    break;

                case 0xBD:
                    sprintf(uob(p, 2), "CP %sL", index);
                    break;

                case 0xBE:
                    sprintf(uob(p, 3), "CP (%s+%02Xh)", index, o2);
                    break;

                case 0xCB:
                    switch (o3) {
                        case 0x00: case 0x01: case 0x02: case 0x03: case 0x04: case 0x05: case 0x07:
                            sprintf(uob(p, 4), "RLC (%s+%02Xh), %s", index, o2, r2(o3));
                            break;

                        case 0x06:
                            sprintf(uob(p, 4), "RLC (%s+%02Xh)", index, o2);
                            break;

                        case 0x08: case 0x09: case 0x0A: case 0x0B: case 0x0C: case 0x0D: case 0x0F:
                            sprintf(uob(p, 4), "RRC (%s+%02Xh), %s", index, o2, r2(o3));
                            break;

                        case 0x0E:
                            sprintf(uob(p, 4), "RRC (%s+%02Xh)", index, o2);
                            break;

                        case 0x10: case 0x11: case 0x12: case 0x13: case 0x14: case 0x15: case 0x17:
                            sprintf(uob(p, 4), "RL (%s+%02Xh), %s", index, o2, r2(o3));
                            break;

                        case 0x16:
                            sprintf(uob(p, 4), "RL (%s+%02Xh)", index, o2);
                            break;

                        case 0x18: case 0x19: case 0x1A: case 0x1B: case 0x1C: case 0x1D: case 0x1F:
                            sprintf(uob(p, 4), "RR (%s+%02Xh), %s", index, o2, r2(o3));
                            break;

                        case 0x1E:
                            sprintf(uob(p, 4), "RR (%s+%02Xh)", index, o2);
                            break;

                        case 0x20: case 0x21: case 0x22: case 0x23: case 0x24: case 0x25: case 0x27:
                            sprintf(uob(p, 4), "SLA (%s+%02Xh), %s", index, o2, r2(o3));
                            break;

                        case 0x26:
                            sprintf(uob(p, 4), "SLA (%s+%02Xh)", index, o2);
                            break;

                        case 0x28: case 0x29: case 0x2A: case 0x2B: case 0x2C: case 0x2D: case 0x2F:
                            sprintf(uob(p, 4), "SRA (%s+%02Xh), %s", index, o2, r2(o3));
                            break;

                        case 0x2E:
                            sprintf(uob(p, 4), "SRA (%s+%02Xh)", index, o2);
                            break;

                        case 0x30: case 0x31: case 0x32: case 0x33: case 0x34: case 0x35: case 0x37:
                            sprintf(uob(p, 4), "SLL (%s+%02Xh), %s", index, o2, r2(o3));
                            break;

                        case 0x36:
                            sprintf(uob(p, 4), "SLL (%s+%02Xh)", index, o2);
                            break;

                        case 0x38: case 0x39: case 0x3A: case 0x3B: case 0x3C: case 0x3D: case 0x3F:
                            sprintf(uob(p, 4), "SRL (%s+%02Xh), %s", index, o2, r2(o3));
                            break;

                        case 0x3E:
                            sprintf(uob(p, 4), "SRL (%s+%02Xh)", index, o2);
                            break;

                        case 0x40: case 0x41: case 0x42: case 0x43: case 0x44: case 0x45: case 0x46: case 0x47:
                        case 0x48: case 0x49: case 0x4A: case 0x4B: case 0x4C: case 0x4D: case 0x4E: case 0x4F:
                        case 0x50: case 0x51: case 0x52: case 0x53: case 0x54: case 0x55: case 0x56: case 0x57:
                        case 0x58: case 0x59: case 0x5A: case 0x5B: case 0x5C: case 0x5D: case 0x5E: case 0x5F:
                        case 0x60: case 0x61: case 0x62: case 0x63: case 0x64: case 0x65: case 0x66: case 0x67:
                        case 0x68: case 0x69: case 0x6A: case 0x6B: case 0x6C: case 0x6D: case 0x6E: case 0x6F:
                        case 0x70: case 0x71: case 0x72: case 0x73: case 0x74: case 0x75: case 0x76: case 0x77:
                        case 0x78: case 0x79: case 0x7A: case 0x7B: case 0x7C: case 0x7D: case 0x7E: case 0x7F:
                            sprintf(uob(p, 4), "BIT %d, (%s+%02Xh)", (o3 >> 3) & 7, index, o2);
                            break;

                        case 0x80: case 0x81: case 0x82: case 0x83: case 0x84: case 0x85: case 0x86: case 0x87:
                        case 0x88: case 0x89: case 0x8A: case 0x8B: case 0x8C: case 0x8D: case 0x8E: case 0x8F:
                        case 0x90: case 0x91: case 0x92: case 0x93: case 0x94: case 0x95: case 0x96: case 0x97:
                        case 0x98: case 0x99: case 0x9A: case 0x9B: case 0x9C: case 0x9D: case 0x9E: case 0x9F:
                        case 0xA0: case 0xA1: case 0xA2: case 0xA3: case 0xA4: case 0xA5: case 0xA6: case 0xA7:
                        case 0xA8: case 0xA9: case 0xAA: case 0xAB: case 0xAC: case 0xAD: case 0xAE: case 0xAF:
                        case 0xB0: case 0xB1: case 0xB2: case 0xB3: case 0xB4: case 0xB5: case 0xB6: case 0xB7:
                        case 0xB8: case 0xB9: case 0xBA: case 0xBB: case 0xBC: case 0xBD: case 0xBE: case 0xBF:
                            sprintf(uob(p, 4), "RES %d, (%s+%02Xh)", (o3 >> 3) & 7, index, o2);
                            break;

                        case 0xC0: case 0xC1: case 0xC2: case 0xC3: case 0xC4: case 0xC5: case 0xC6: case 0xC7:
                        case 0xC8: case 0xC9: case 0xCA: case 0xCB: case 0xCC: case 0xCD: case 0xCE: case 0xCF:
                        case 0xD0: case 0xD1: case 0xD2: case 0xD3: case 0xD4: case 0xD5: case 0xD6: case 0xD7:
                        case 0xD8: case 0xD9: case 0xDA: case 0xDB: case 0xDC: case 0xDD: case 0xDE: case 0xDF:
                        case 0xE0: case 0xE1: case 0xE2: case 0xE3: case 0xE4: case 0xE5: case 0xE6: case 0xE7:
                        case 0xE8: case 0xE9: case 0xEA: case 0xEB: case 0xEC: case 0xED: case 0xEE: case 0xEF:
                        case 0xF0: case 0xF1: case 0xF2: case 0xF3: case 0xF4: case 0xF5: case 0xF6: case 0xF7:
                        case 0xF8: case 0xF9: case 0xFA: case 0xFB: case 0xFC: case 0xFD: case 0xFE: case 0xFF:
                            sprintf(uob(p, 4), "SET %d, (%s+%02Xh)", (o3 >> 3) & 7, index, o2);
                            break;
                    }
                    break;

                case 0xE1:
                    sprintf(uob(p, 2), "POP %s", index);
                    break;

                case 0xE3:
                    sprintf(uob(p, 2), "SP (SP), %s", index);
                    break;

                case 0xE5:
                    sprintf(uob(p, 2), "PUSH %s", index);
                    break;

                case 0xE9:
                    sprintf(uob(p, 2), "JP (%s)", index);
                    break;

                case 0xF9:
                    sprintf(uob(p, 2), "LD SP, %s", index);
                    break;
            }
            break; }

        case 0xDE:
            sprintf(uob(p, 2), "SBC A, %02Xh", o1);
            break;

        case 0xE3:
            sprintf(uob(p, 1), "EX (SP), HL");
            break;

        case 0xE6:
            sprintf(uob(p, 2), "AND %02Xh", o1);
            break;

        case 0xE9:
            sprintf(uob(p, 1), "JP (HL)");
            break;

        case 0xEB:
            sprintf(uob(p, 1), "EX DE, HL");
            break;

        case 0xEE:
            sprintf(uob(p, 2), "XOR %02Xh", o1);
            break;

        case 0xED:
            switch (o1) {
                case 0x40: case 0x48: case 0x50: case 0x58: case 0x60: case 0x68: case 0x78:
                    sprintf(uob(p, 2), "IN %s, (C)", r(o1));
                    break;

                case 0x41: case 0x49: case 0x51: case 0x59: case 0x61: case 0x69: case 0x79:
                    sprintf(uob(p, 2), "OUT (C), %s", r(o1));
                    break;

                case 0x42: case 0x52: case 0x62: case 0x72:
                    sprintf(uob(p, 2), "SBC HL, %s", dd(o1));
                    break;

                case 0x43: case 0x53: case 0x63: case 0x73:
                    sprintf(uob(p, 4), "LD (%04Xh), %s", nn2, dd(o1));
                    break;

                case 0x44:
                    sprintf(uob(p, 2), "NEG");
                    break;

                case 0x45:
                    sprintf(uob(p, 2), "RETN");
                    break;

                case 0x46:
                    sprintf(uob(p, 2), "IM 0");
                    break;

                case 0x47:
                    sprintf(uob(p, 2), "LD I, A");
                    break;

                case 0x4A: case 0x5A: case 0x6A: case 0x7A:
                    sprintf(uob(p, 2), "ADC HL, %s", dd(o1));
                    break;

                case 0x4B: case 0x5B: case 0x6B: case 0x7B:
                    sprintf(uob(p, 4), "LD %s, (%04Xh)", dd(o1), nn2);
                    break;

                case 0x4D:
                    sprintf(uob(p, 2), "RETI");
                    break;

                case 0x4F:
                    sprintf(uob(p, 2), "LD R, A");
                    break;

                case 0x56:
                    sprintf(uob(p, 2), "IM 1");
                    break;

                case 0x57:
                    sprintf(uob(p, 2), "LD A, I");
                    break;

                case 0x5E:
                    sprintf(uob(p, 2), "IM 2");
                    break;

                case 0x5F:
                    sprintf(uob(p, 2), "LD A, R");
                    break;

                case 0x67:
                    sprintf(uob(p, 2), "RRD");
                    break;

                case 0x6F:
                    sprintf(uob(p, 2), "RLD");
                    break;

                case 0xA0:
                    sprintf(uob(p, 2), "LDI");
                    break;

                case 0xA1:
                    sprintf(uob(p, 2), "CPI");
                    break;

                case 0xA2:
                    sprintf(uob(p, 2), "INI");
                    break;

                case 0xA3:
                    sprintf(uob(p, 2), "OUTI");
                    break;

                case 0xA8:
                    sprintf(uob(p, 2), "LDD");
                    break;

                case 0xA9:
                    sprintf(uob(p, 2), "CPD");
                    break;

                case 0xAA:
                    sprintf(uob(p, 2), "IND");
                    break;

                case 0xAB:
                    sprintf(uob(p, 2), "OUTD");
                    break;

                case 0xB0:
                    sprintf(uob(p, 2), "LDIR");
                    break;

                case 0xB1:
                    sprintf(uob(p, 2), "CPIR");
                    break;

                case 0xB2:
                    sprintf(uob(p, 2), "INIR");
                    break;

                case 0xB3:
                    sprintf(uob(p, 2), "OTIR");
                    break;

                case 0xB8:
                    sprintf(uob(p, 2), "LDDR");
                    break;

                case 0xB9:
                    sprintf(uob(p, 2), "CPDR");
                    break;

                case 0xBA:
                    sprintf(uob(p, 2), "INDR");
                    break;

                case 0xBB:
                    sprintf(uob(p, 2), "OTDR");
                    break;
            }
            break;

        case 0xF3:
            sprintf(uob(p, 1), "DI");
            break;

        case 0xF6:
            sprintf(uob(p, 2), "OR %02Xh", o1);
            break;

        case 0xF9:
            sprintf(uob(p, 1), "LD SP, HL");
            break;

        case 0xFB:
            sprintf(uob(p, 1), "EI");
            break;

        case 0xFE:
            sprintf(uob(p, 2), "CP %02Xh", o1);
            break;
    }
}
