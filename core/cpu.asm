; Alis, A SEGA Master System emulator
; Copyright (C) 2002-2020 Cidorvan Leite

; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.

; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with this program.  If not, see [http://www.gnu.org/licenses/].


EXTERN ?OpCodeErr1@@YAXHH@Z
EXTERN ?OpCodeErr2@@YAXHHH@Z
EXTERN ?OpCodeErr3@@YAXHHHH@Z

%INCLUDE "data.inc"
%INCLUDE "banks.inc"
%INCLUDE "io.inc"

SECTION .text

; * Reset CPU
; *************
GLOBAL reset_CPU
reset_CPU:
        xor eax, eax
        mov [Flag], eax
        mov [rE], eax
        mov [Flag2], eax
        mov [rE2], eax
        mov [rR], ax
        mov [rIX], eax
        mov [rIY], eax
        mov [rPCx], eax
        mov DWORD [rSPx], 0D000h

        mov [TClock], eax
        mov BYTE [Halt], 0
        mov BYTE [NMI], 0

        ret

; * Executes one line
; *********************
GLOBAL TraceLine
TraceLine:
        inc BYTE [rR]
        mov esi, [rPCx]
        call read_mem
        movzx edx, BYTE [rsi]
        jmp QWORD [Opcode+edx*8]

TLF:    cmp BYTE [TClock], 228
        jb TraceLine
        ret

; * NMI Interruption (pause button)
; ***********************************
GLOBAL int_NMI
int_NMI:
        ; Save interruption mask
        mov BYTE [NMI], 1
        mov al, [IFF1]
        mov [IFF2], al
        mov BYTE [IFF1], 0

        ; Checks CPU state
        test BYTE [Halt], 1
        jz NMI0
        mov BYTE [Halt], 0
        inc DWORD [rPCx]

        ; push PC
NMI0:   sub DWORD [rSPx], 2
        mov esi, DWORD [rSPx]
        call read_mem
        mov eax, DWORD [rPCx]
        mov [rsi], ax

        ; Jump to interruption address
        inc BYTE [rR]
        mov DWORD [rPCx], 66h
        add BYTE [TClock], 11

        ret

; * Z80 Interruption
; ********************
GLOBAL int_Z80
int_Z80:
        ; Checks if the interruption is enabled
        cmp BYTE [IFF1], 0
        je IZ80

        ; Reset interruption mask
        mov BYTE [IFF1], 0
        mov BYTE [IFF2], 0

        ; Checks CPU state
        test BYTE [Halt], 1
        jz Z80
        mov BYTE [Halt], 0
        inc DWORD [rPCx]

        ; push PC
Z80:    sub DWORD [rSPx], 2
        mov esi, DWORD [rSPx]
        call read_mem
        mov eax, DWORD [rPCx]
        mov [rsi], ax

        ; Jump to interruption address
        inc BYTE [rR]
        mov DWORD [rPCx], 38h
        add BYTE [TClock], 13
IZ80:   ret

; * Opcode not implemented (one byte)
; *************************************
GLOBAL _NIMP1
_NIMP1:
        ;pusha
        ;push edx
        ;push DWORD [rPCx]
        ;call ?OpCodeErr1@@YAXHH@Z
        ;add esp, 8
        ;popa
        jmp TLF

; * Opcode not implemented (two bytes)
; **************************************
GLOBAL _NIMP2
_NIMP2:
        ;pusha
        ;push edx
        ;movzx eax, BYTE [rsi]
        ;push eax
        ;push DWORD [rPCx]
        ;call ?OpCodeErr2@@YAXHHH@Z
        ;add esp, 12
        ;popa
        jmp TLF

; * Opcode not implemented (three bytes)
; ****************************************
GLOBAL _NIMP3
_NIMP3:
        ;pusha
        ;push edx
        ;movzx eax, BYTE [rsi+1]
        ;push eax
        ;movzx eax, BYTE [rsi]
        ;push eax
        ;push DWORD [rPCx]
        ;call ?OpCodeErr3@@YAXHHHH@Z
        ;add esp, 16
        ;popa
        jmp TLF

; * Opcode not listed
; **********************
GLOBAL _NOLIST
_NOLIST:
        inc BYTE [rR]
        add DWORD [rPCx], 2
        add BYTE [TClock], 8
        jmp TLF


; *****************************************************************************
; *** Macros
; *****************************************************************************

; * Load register pair rr with imm
; **********************************
%MACRO __LDrrn 2
        movzx eax, WORD [rsi+1]
        mov %1, %2
        add DWORD [rPCx], 3
        add BYTE [TClock], 10
        jmp TLF
%ENDMACRO

; * Load register r with value n
; ********************************
%MACRO __LDrn 1
        mov al, [rsi+1]
        mov %1, al
        add DWORD [rPCx], 2
        add BYTE [TClock], 7
        jmp TLF
%ENDMACRO

; * Increment register r
; ************************
%MACRO __INCr 2
        and BYTE [Flag], 1
        inc %1
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 11010000b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Decrement register m
; ************************
%MACRO __DECr 2
        and BYTE [Flag], 1
        or BYTE [Flag], 2
        dec %1
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 11010000b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Increment register pair ss
; ******************************
%MACRO __INCss 1
        inc %1
        inc DWORD [rPCx]
        add BYTE [TClock], 6
        jmp TLF
%ENDMACRO

; * Decrement register pair ss
; ******************************
%MACRO __DECss 1
        dec WORD %1
        inc DWORD [rPCx]
        add BYTE [TClock], 6
        jmp TLF
%ENDMACRO

; * Add register pair rr to HL
; ******************************
%MACRO __ADDHLrr 1
        and BYTE [Flag], 11000100b
        mov ax, WORD %1
        add BYTE [rL], al
        adc BYTE [rH], ah
        lahf
        and ah, 10001b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], 11
        jmp TLF
%ENDMACRO

; * Load register r with register r' or location (HL)
; *****************************************************
%MACRO __LDrr 3
        mov al, %2
        mov %1, al
        inc DWORD [rPCx]
        add BYTE [TClock], %3
        jmp TLF
%ENDMACRO

; * Load register r with location (HL)
; **************************************
%MACRO __LDr_HL 1
        movzx esi, WORD [rL]
        call read_mem
        __LDrr %1, [rsi], 7
%ENDMACRO

; * Load location (HL) with register r
; **************************************
%MACRO __LD_HL_r 1
        mov al, %1
        movzx esi, WORD [rL]
        call write_mem
        mov [rsi], al
        inc DWORD [rPCx]
        add BYTE [TClock], 7
        jmp TLF
%ENDMACRO

; * Add operand s to accumulator
; ********************************
%MACRO __ADDAs 2
        mov BYTE [Flag], 0
        mov al, %1
        add BYTE [rAcc], al
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 11010001b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Add operand s to accumulator with carry
; *******************************************
%MACRO __ADCAs 2
        mov bl, BYTE [Flag]
        mov BYTE [Flag], 0
        mov al, %1
        shr bl, 1
        adc BYTE [rAcc], al
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 11010001b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Subtract operand s from accumulator
; ***************************************
%MACRO __SUBs 2
        mov BYTE [Flag], 2
        mov al, %1
        sub BYTE [rAcc], al
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 11010001b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Subtract operand s from accumulator with carry
; **************************************************
%MACRO __SBCAs 2
        mov bl, BYTE [Flag]
        mov BYTE [Flag], 2
        mov al, %1
        shr bl, 1
        sbb BYTE [rAcc], al
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 11010001b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Logical AND of operand s to accumulator
; *******************************************
%MACRO __ANDs 2
        mov BYTE [Flag], 10h
        mov al, %1
        and BYTE [rAcc], al
        lahf
        and ah, 11000100b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Exclusive OR operand s and accumulator
; ******************************************
%MACRO __XORs 2
        mov al, %1
        xor BYTE [rAcc], al
        lahf
        and ah, 11000100b
        mov BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Logical OR of operand s and accumulator
; *******************************************
%MACRO __ORs 2
        mov al, %1
        or BYTE [rAcc], al
        lahf
        and ah, 11000100b
        mov BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Compare operand s with accumulator
; **************************************
%MACRO __CPs 2
        mov BYTE [Flag], 2
        mov al, BYTE [rAcc]
        sub al, %1
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 11010001b
        or BYTE [Flag], ah
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Load register pair rr with top of stack
; *******************************************
%MACRO __POPrr 1
        mov esi, DWORD [rSPx]
        add DWORD [rSPx], 2
        call read_mem
        mov ax, [rsi]
        mov WORD %1, ax
        inc DWORD [rPCx]
        add BYTE [TClock], 10
        jmp TLF
%ENDMACRO

; * Jump to location nn if condition cc is true
; ***********************************************
%MACRO __JPccnn 2
        test BYTE [Flag], %2
        j%1 %%A
        movzx eax, WORD [rsi+1]
        mov DWORD [rPCx], eax
        jmp %%B
%%A:    add DWORD [rPCx], 3
%%B:    add BYTE [TClock], 10
        jmp TLF
%ENDMACRO

; * Jump relative to PC+e if condition cc is true
; *************************************************
%MACRO __JRccn 2
        test BYTE [Flag], %2
        j%1 %%A
        movsx eax, BYTE [rsi+1]
        add DWORD [rPCx], eax
        add BYTE [TClock], 12
        jmp %%B
%%A:    add BYTE [TClock], 7
%%B:    add DWORD [rPCx], 2
        jmp TLF
%ENDMACRO

; * Call subroutine at location nn if condition cc is true
; **********************************************************
%MACRO __CALLccnn 2
        test BYTE [Flag], %2
        j%1 %%A
        mov eax, DWORD [rPCx]
        add eax, 3
        movzx edx, WORD [rsi+1]
        mov DWORD [rPCx], edx
        sub DWORD [rSPx], 2
        mov esi, DWORD [rSPx]
        call write_mem
        mov [rsi], ax
        add BYTE [TClock], 17
        jmp TLF
%%A:    add DWORD [rPCx], 3
        add BYTE [TClock], 10
        jmp TLF
%ENDMACRO

; * Return from subroutine if condition cc is true
; **************************************************
%MACRO __RETcc 2
        test BYTE [Flag], %2
        j%1 %%A
        mov esi, DWORD [rSPx]
        add DWORD [rSPx], 2
        call read_mem
        movzx eax, WORD [rsi]
        mov DWORD [rPCx], eax
        add BYTE [TClock], 11
        jmp TLF
%%A:    add BYTE [TClock], 5
%%B:    inc DWORD [rPCx]
        jmp TLF
%ENDMACRO

; * Load register pair qq onto stack
; ************************************
%MACRO __PUSHqq 1
        movzx eax, WORD %1
        sub DWORD [rSPx], 2
        mov esi, DWORD [rSPx]
        call write_mem
        mov [rsi], ax
        inc DWORD [rPCx]
        add BYTE [TClock], 11
        jmp TLF
%ENDMACRO

; * Restart to location p
; *************************
%MACRO __RSTp 1
        mov eax, DWORD [rPCx]
        inc eax
        sub DWORD [rSPx], 2
        mov esi, DWORD [rSPx]
        call write_mem
        mov [rsi], ax
        mov DWORD [rPCx], %1
        add BYTE [TClock], 11
        jmp TLF
%ENDMACRO

; * Exchange the location (SP) and register r
; *********************************************
%MACRO __EX_SP_r 2
        mov esi, DWORD [rSPx]
        call read_mem
        mov ax, [rsi]
        mov bx, WORD %1
        mov [rsi], bx
        mov WORD %1, ax
        inc DWORD [rPCx]
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO


; *****************************************************************************
; *** Opcodes
; *****************************************************************************

; * NOP - 00 - 4 Clk - No operation
; ***********************************
GLOBAL _NOP
_NOP:
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * LD dd, n - (01,11,21,31) n n - 10 Clk - Load register pair dd with imm
; **************************************************************************
GLOBAL _LDBCN, _LDDEN, _LDHLN, _LDSPN
_LDBCN: __LDrrn WORD [rC], ax
_LDDEN: __LDrrn WORD [rE], ax
_LDHLN: __LDrrn WORD [rL], ax
_LDSPN: __LDrrn DWORD [rSPx], eax

; * LD (BC), A - 02 - 7 Clk - Load location (BC) with accumulator
; *****************************************************************
GLOBAL _LD_BC_A
_LD_BC_A:
        mov al, BYTE [rAcc]
        movzx esi, WORD [rC]
        call write_mem
        mov [rsi], al
        inc DWORD [rPCx]
        add BYTE [TClock], 7
        jmp TLF

; * INC dd - (03,13,23,33) - 6 Clk - Increment register pair dd
; ***************************************************************
GLOBAL _INCBC, _INCDE, _INCHL, _INCSP
_INCBC: __INCss WORD [rC]
_INCDE: __INCss WORD [rE]
_INCHL: __INCss WORD [rL]
_INCSP: __INCss DWORD [rSPx]

; * INC r - (04,0C,14,1C,24,2C,34,3C) - 4/11 Clk - Increment operand r
; **********************************************************************
GLOBAL _INCB, _INCC, _INCD, _INCE, _INCH, _INCL, _INC_HL, _INCA
_INCB:  __INCr BYTE [rB], 4
_INCC:  __INCr BYTE [rC], 4
_INCD:  __INCr BYTE [rD], 4
_INCE:  __INCr BYTE [rE], 4
_INCH:  __INCr BYTE [rH], 4
_INCL:  __INCr BYTE [rL], 4
_INC_HL:
        and BYTE [Flag], 1
        movzx esi, WORD [rL]
        mov edi, esi
        call read_mem
        mov al, [rsi]
        inc al
        lahf
        jno INCHL
        or BYTE [Flag], 4
INCHL:  and ah, 11010000b
        or BYTE [Flag], ah
        mov esi, edi
        call write_mem
        mov [rsi], al
        inc DWORD [rPCx]
        add BYTE [TClock], 11
        jmp TLF
_INCA:  __INCr BYTE [rAcc], 4

; * DEC r - (05,0D,15,1D,25,2D,35,3D) - 4/11 Clk - Decrement operand r
; **********************************************************************
GLOBAL _DECB, _DECC, _DECD, _DECE, _DECH, _DECL, _DEC_HL, _DECA
_DECB:  __DECr BYTE [rB], 4
_DECC:  __DECr BYTE [rC], 4
_DECD:  __DECr BYTE [rD], 4
_DECE:  __DECr BYTE [rE], 4
_DECH:  __DECr BYTE [rH], 4
_DECL:  __DECr BYTE [rL], 4
_DEC_HL:
        and BYTE [Flag], 1
        or BYTE [Flag], 2
        movzx esi, WORD [rL]
        mov edi, esi
        call read_mem
        mov al, [rsi]
        dec al
        lahf
        jno DECHL
        or BYTE [Flag], 4
DECHL:  and ah, 11010000b
        or BYTE [Flag], ah
        mov esi, edi
        call write_mem
        mov [rsi], al
        inc DWORD [rPCx]
        add BYTE [TClock], 11
        jmp TLF
_DECA:  __DECr BYTE [rAcc], 4

; * LD r, n - (06,0E,16,1E,26,2E,3E) n - 7 Clk - Load register r with value n
; *****************************************************************************
GLOBAL _LDBN, _LDCN, _LDDN, _LDEN, _LDHN, _LDLN, _LDAN
_LDBN:  __LDrn BYTE [rB]
_LDCN:  __LDrn BYTE [rC]
_LDDN:  __LDrn BYTE [rD]
_LDEN:  __LDrn BYTE [rE]
_LDHN:  __LDrn BYTE [rH]
_LDLN:  __LDrn BYTE [rL]
_LDAN:  __LDrn BYTE [rAcc]

; * RLCA - 07 - 4 Clk - Rotate left circular accumulator
; ********************************************************
GLOBAL _RLCA
_RLCA:
        and BYTE [Flag], 11000100b
        rol BYTE [rAcc], 1
        jnc RLCA0
        or BYTE [Flag], 1
RLCA0:  inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * EX AF, AF' - 08 - 04 Clk - Exchange the contents of AF and AF'
; ******************************************************************
GLOBAL _EXAFAF
_EXAFAF:
        rol DWORD [Flag], 16
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * ADD HL, dd - (09,19,29,39) - 11 Clk - Add register pair dd to HL
; ********************************************************************
GLOBAL _ADDHLBC, _ADDHLDE, _ADDHLHL, _ADDHLSP
_ADDHLBC:__ADDHLrr BYTE [rC]
_ADDHLDE:__ADDHLrr BYTE [rE]
_ADDHLHL:__ADDHLrr BYTE [rL]
_ADDHLSP:__ADDHLrr DWORD [rSPx]

; * LD A, (BC) - 0A - 7 Clk - Load accumulator with location (BC)
; *****************************************************************
GLOBAL _LDA_BC
_LDA_BC:
        movzx esi, WORD [rC]
        call read_mem
        mov al, [rsi]
        mov BYTE [rAcc], al
        inc DWORD [rPCx]
        add BYTE [TClock], 7
        jmp TLF

; * DEC dd - (0B,1B,2B,3B) - 6 Clk - Decrement register pair dd
; ***************************************************************
GLOBAL _DECBC, _DECDE, _DECHL, _DECSP
_DECBC: __DECss BYTE [rC]
_DECDE: __DECss BYTE [rE]
_DECHL: __DECss BYTE [rL]
_DECSP: __DECss DWORD [rSPx]

; * RRCA - 0F - 4 Clk - Rotate right circular accumulator
; *********************************************************
GLOBAL _RRCA
_RRCA:
        and BYTE [Flag], 11000100b
        ror BYTE [rAcc], 1
        jnc RRCA0
        or BYTE [Flag], 1
RRCA0:  inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * DJNZ e - 10 e - 8/13 Clk - Decrement B and jump relative if B<>0
; ********************************************************************
GLOBAL _DJNZ
_DJNZ:
        dec BYTE [rB]
        jz DJNZ0
        movsx eax, BYTE [rsi+1]
        add DWORD [rPCx], eax
        add BYTE [TClock], 13
        jmp DJNZ1
DJNZ0:  add BYTE [TClock], 8
DJNZ1:  add DWORD [rPCx], 2
        jmp TLF

; * LD (DE), A - 12 - 7 Clk - Load location (DE) with accumulator
; *****************************************************************
GLOBAL _LD_DE_A
_LD_DE_A:
        mov al, BYTE [rAcc]
        movzx esi, WORD [rE]
        call write_mem
        mov [rsi], al
        inc DWORD [rPCx]
        add BYTE [TClock], 7
        jmp TLF

; * RLA - 17 - 4 Clk - Rotate left accumulator through carry
; ************************************************************
GLOBAL _RLA
_RLA:
        mov al, BYTE [Flag]
        and BYTE [Flag], 11000100b
        shr al, 1
        rcl BYTE [rAcc], 1
        jnc RLA0
        or BYTE [Flag], 1
RLA0:   inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * JR e - 18 e - 12 Clk - Unconditional jump relative to PC+e
; **************************************************************
GLOBAL _JRE
_JRE:
        movsx eax, BYTE [rsi+1]
        add DWORD [rPCx], eax
        add DWORD [rPCx], 2
        add BYTE [TClock], 12
        jmp TLF

; * LD A, (DE) - 1A - 7 Clk - Load accumulator with location (DE)
; *****************************************************************
GLOBAL _LDA_DE
_LDA_DE:
        movzx esi, WORD [rE]
        call read_mem
        mov al, [rsi]
        mov BYTE [rAcc], al
        inc DWORD [rPCx]
        add BYTE [TClock], 7
        jmp TLF

; * RRA - 1F - 4 Clk - Rotate right accumulator through carry
; *************************************************************
GLOBAL _RRA
_RRA:
        mov al, BYTE [Flag]
        and BYTE [Flag], 11000100b
        shr al, 1
        rcr BYTE [rAcc], 1
        jnc RRA0
        or BYTE [Flag], 1
RRA0:   inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * JR cc, e - (20/28/30/38) e - 7/12 Clk - Jump relative to PC+e if cc is true
; *******************************************************************************
GLOBAL _JRNZE, _JRZE, _JRNCE, _JRCE
_JRNZE: __JRccn nz, 40h
_JRZE:  __JRccn z, 40h
_JRNCE: __JRccn nz, 1h
_JRCE:  __JRccn z, 1h

; * LD (n), HL - 22 n n - 20 Clk - Load location (nn) with HL
; *************************************************************
GLOBAL _LD_N_HL
_LD_N_HL:
        movzx esi, WORD [rsi+1]
        cmp esi, 0FFFCh
        jae LDNHL0
        mov ax, WORD [rL]
        call write_mem
        mov [rsi], ax
        jmp LDNHL1
LDNHL0: mov edi, esi
        mov al, BYTE [rL]
        call write_mem
        mov [rsi], al
        mov esi, edi
        inc esi
        mov al, BYTE [rH]
        call write_mem
        mov [rsi], al
LDNHL1: add DWORD [rPCx], 3
        add BYTE [TClock], 20
        jmp TLF

; * DAA - 27 - 4 Clk - Decimal adjust accumulator
; *************************************************
GLOBAL _DAA
_DAA:
        mov al, BYTE [rAcc]
        mov ah, BYTE [Flag]
        and BYTE [Flag], 2
        test ah, 2
        jnz DAA0
        sahf
        ;daa
        jmp DAA1
DAA0:   sahf
        ;das
DAA1:   lahf
        and ah, 11010101b
        or BYTE [Flag], ah
        mov BYTE [rAcc], al
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * LD HL, (nn) - 2A n n - 16 Clk - Load HL with location (nn)
; **************************************************************
GLOBAL _LDHL_N2
_LDHL_N2:
        movzx esi, WORD [rsi+1]
        call read_mem
        mov ax, [rsi]
        mov WORD [rL], ax
        add DWORD [rPCx], 3
        add BYTE [TClock], 16
        jmp TLF

; * CPL - 2F - 4 Clk - Complement accumulator (1's complement)
; **************************************************************
GLOBAL __CPL
__CPL:
        not BYTE [rAcc]
        or BYTE [Flag], 10010b
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * LD (nn), A - 32 n n - 13 Clk - Load location (nn) with accumulator
; **********************************************************************
GLOBAL _LD_N_A
_LD_N_A:
        mov al, BYTE [rAcc]
        movzx esi, WORD [rsi+1]
        call write_mem
        mov [rsi], al
        add DWORD [rPCx], 3
        add BYTE [TClock], 13
        jmp TLF

; * LD (HL), n - 36 n - 10 Clk - Load location (HL) with imm
; ************************************************************
GLOBAL _LD_HL_N
_LD_HL_N:
        mov al, [rsi+1]
        movzx esi, WORD [rL]
        call write_mem
        mov [rsi], al
        add DWORD [rPCx], 2
        add BYTE [TClock], 10
        jmp TLF

; * SCF - 37 - 4 Clk - Set carry flag (C=1)
; *******************************************
GLOBAL _SCF
_SCF:
        and BYTE [Flag], 11000100b
        or BYTE [Flag], 1
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * LD A, (n) - 3A n n - 13 Clk - Load accumulator with location nn
; *******************************************************************
GLOBAL _LDA_N
_LDA_N:
        movzx esi, WORD [rsi+1]
        call read_mem
        mov al, [rsi]
        mov BYTE [rAcc], al
        add DWORD [rPCx], 3
        add BYTE [TClock], 13
        jmp TLF

; * CCF - 3F - 4 Clk - Complement carry flag
; ********************************************
GLOBAL _CCF
_CCF:
        mov al, BYTE [Flag]
        and al, 1
        shl al, 4
        and BYTE [Flag], 11000101b
        xor BYTE [Flag], 1
        or BYTE [Flag], al
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * LD B, r - (40,41,42,43,44,45,46,47) - 4/7 Clk - Load register B with operand r
; **********************************************************************************
GLOBAL _LDBB, _LDBC, _LDBD, _LDBE, _LDBH, _LDBL, _LDB_HL, _LDBA
_LDBB:  __LDrr BYTE [rB], BYTE [rB], 4
_LDBC:  __LDrr BYTE [rB], BYTE [rC], 4
_LDBD:  __LDrr BYTE [rB], BYTE [rD], 4
_LDBE:  __LDrr BYTE [rB], BYTE [rE], 4
_LDBH:  __LDrr BYTE [rB], BYTE [rH], 4
_LDBL:  __LDrr BYTE [rB], BYTE [rL], 4
_LDB_HL:__LDr_HL BYTE [rB]
_LDBA:  __LDrr BYTE [rB], BYTE [rAcc], 4

; * LD C, r - (48,49,4A,4B,4C,4D,4E,4F) - 4/7 Clk - Load register C with operand r
; **********************************************************************************
GLOBAL _LDCB, _LDCC, _LDCD, _LDCE, _LDCH, _LDCL, _LDC_HL, _LDCA
_LDCB:  __LDrr BYTE [rC], BYTE [rB], 4
_LDCC:  __LDrr BYTE [rC], BYTE [rC], 4
_LDCD:  __LDrr BYTE [rC], BYTE [rD], 4
_LDCE:  __LDrr BYTE [rC], BYTE [rE], 4
_LDCH:  __LDrr BYTE [rC], BYTE [rH], 4
_LDCL:  __LDrr BYTE [rC], BYTE [rL], 4
_LDC_HL:__LDr_HL BYTE [rC]
_LDCA:  __LDrr BYTE [rC], BYTE [rAcc], 4

; * LD D, r - (50,51,52,53,54,55,56,57) - 4/7 Clk - Load register D with operand r
; **********************************************************************************
GLOBAL _LDDB, _LDDC, _LDDD, _LDDE, _LDDH, _LDDL, _LDD_HL, _LDDA
_LDDB:  __LDrr BYTE [rD], BYTE [rB], 4
_LDDC:  __LDrr BYTE [rD], BYTE [rC], 4
_LDDD:  __LDrr BYTE [rD], BYTE [rD], 4
_LDDE:  __LDrr BYTE [rD], BYTE [rE], 4
_LDDH:  __LDrr BYTE [rD], BYTE [rH], 4
_LDDL:  __LDrr BYTE [rD], BYTE [rL], 4
_LDD_HL:__LDr_HL BYTE [rD]
_LDDA:  __LDrr BYTE [rD], BYTE [rAcc], 4

; * LD E, r - (58,59,5A,5B,5C,5D,5E,5F) - 4/7 Clk - Load register E with operand r
; **********************************************************************************
GLOBAL _LDEB, _LDEC, _LDED, _LDEE, _LDEH, _LDEL, _LDE_HL, _LDEA
_LDEB:  __LDrr BYTE [rE], BYTE [rB], 4
_LDEC:  __LDrr BYTE [rE], BYTE [rC], 4
_LDED:  __LDrr BYTE [rE], BYTE [rD], 4
_LDEE:  __LDrr BYTE [rE], BYTE [rE], 4
_LDEH:  __LDrr BYTE [rE], BYTE [rH], 4
_LDEL:  __LDrr BYTE [rE], BYTE [rL], 4
_LDE_HL:__LDr_HL BYTE [rE]
_LDEA:  __LDrr BYTE [rE], BYTE [rAcc], 4

; * LD H, r - (60,62,63,64,65,66,67) - 4/7 Clk - Load register H with operand r
; *******************************************************************************
GLOBAL _LDHB, _LDHC, _LDHD, _LDHE, _LDHH, _LDHL, _LDH_HL, _LDHA
_LDHB:  __LDrr BYTE [rH], BYTE [rB], 4
_LDHC:  __LDrr BYTE [rH], BYTE [rC], 4
_LDHD:  __LDrr BYTE [rH], BYTE [rD], 4
_LDHE:  __LDrr BYTE [rH], BYTE [rE], 4
_LDHH:  __LDrr BYTE [rH], BYTE [rH], 4
_LDHL:  __LDrr BYTE [rH], BYTE [rL], 4
_LDH_HL:__LDr_HL BYTE [rH]
_LDHA:  __LDrr BYTE [rH], BYTE [rAcc], 4

; * LD L, r - (68,69,6A,6B,6C,6D,6E,6F) - 4/7 Clk - Load register L with operand r
; **********************************************************************************
GLOBAL _LDLB, _LDLC, _LDLD, _LDLE, _LDLH, _LDLL, _LDL_HL, _LDLA
_LDLB:  __LDrr BYTE [rL], BYTE [rB], 4
_LDLC:  __LDrr BYTE [rL], BYTE [rC], 4
_LDLD:  __LDrr BYTE [rL], BYTE [rD], 4
_LDLE:  __LDrr BYTE [rL], BYTE [rE], 4
_LDLH:  __LDrr BYTE [rL], BYTE [rH], 4
_LDLL:  __LDrr BYTE [rL], BYTE [rL], 4
_LDL_HL:__LDr_HL BYTE [rL]
_LDLA:  __LDrr BYTE [rL], BYTE [rAcc], 4

; * LD (HL), r - (70,71,72,73,74,75,77) - 7 Clk - Load location (HL) with register r
; ************************************************************************************
GLOBAL _LD_HL_B, _LD_HL_C, _LD_HL_D, _LD_HL_E, _LD_HL_H, _LD_HL_L, _LD_HL_A
_LD_HL_B:__LD_HL_r BYTE [rB]
_LD_HL_C:__LD_HL_r BYTE [rC]
_LD_HL_D:__LD_HL_r BYTE [rD]
_LD_HL_E:__LD_HL_r BYTE [rE]
_LD_HL_H:__LD_HL_r BYTE [rH]
_LD_HL_L:__LD_HL_r BYTE [rL]
_LD_HL_A:__LD_HL_r BYTE [rAcc]

; * HALT - 76 - 4 Clk - BYTE [Halt] computer and wait for interrupt
; ************************************************************
GLOBAL _HALT
_HALT:
        mov BYTE [Halt], 1
        add BYTE [TClock], 4
        jmp TLF

; * LD A, r - (78,79,7A,7B,7C,7D,7E,7F) - 4/7 Clk - Load register A with operand r
; **********************************************************************************
GLOBAL _LDAB, _LDAC, _LDAD, _LDAE, _LDAH, _LDAL, _LDA_HL, _LDAA
_LDAB:  __LDrr BYTE [rAcc], BYTE [rB], 4
_LDAC:  __LDrr BYTE [rAcc], BYTE [rC], 4
_LDAD:  __LDrr BYTE [rAcc], BYTE [rD], 4
_LDAE:  __LDrr BYTE [rAcc], BYTE [rE], 4
_LDAH:  __LDrr BYTE [rAcc], BYTE [rH], 4
_LDAL:  __LDrr BYTE [rAcc], BYTE [rL], 4
_LDA_HL:__LDr_HL BYTE [rAcc]
_LDAA:  __LDrr BYTE [rAcc], BYTE [rAcc], 4

; * ADD A, s - (80-87,C6) - 4/7 Clk - Add operand s to accumulator
; ******************************************************************
GLOBAL _ADDAB, _ADDAC, _ADDAD, _ADDAE, _ADDAH, _ADDAL, _ADDA_HL, _ADDAA, _ADDAN
_ADDAB: __ADDAs BYTE [rB], 4
_ADDAC: __ADDAs BYTE [rC], 4
_ADDAD: __ADDAs BYTE [rD], 4
_ADDAE: __ADDAs BYTE [rE], 4
_ADDAH: __ADDAs BYTE [rH], 4
_ADDAL: __ADDAs BYTE [rL], 4
_ADDA_HL:movzx esi, WORD [rL]
        call read_mem
        __ADDAs [rsi], 7
_ADDAA: __ADDAs BYTE [rAcc], 4
_ADDAN: inc DWORD [rPCx]
        __ADDAs [rsi+1], 7

; * ADC A, s - (88-8F,CE) - 4/7 Clk - Add operand s to accumulator with carry
; *****************************************************************************
GLOBAL _ADCAB, _ADCAC, _ADCAD, _ADCAE, _ADCAH, _ADCAL, _ADCA_HL, _ADCAA, _ADCAN
_ADCAB: __ADCAs BYTE [rB], 4
_ADCAC: __ADCAs BYTE [rC], 4
_ADCAD: __ADCAs BYTE [rD], 4
_ADCAE: __ADCAs BYTE [rE], 4
_ADCAH: __ADCAs BYTE [rH], 4
_ADCAL: __ADCAs BYTE [rL], 4
_ADCA_HL:movzx esi, WORD [rL]
        call read_mem
        __ADCAs [rsi], 7
_ADCAA: __ADCAs BYTE [rAcc], 4
_ADCAN: inc DWORD [rPCx]
        __ADCAs [rsi+1], 7

; * SUB s - (90-97,D6) - 4/7 Clk - Subtract operand s from accumulator
; **********************************************************************
GLOBAL _SUBB, _SUBC, _SUBD, _SUBE, _SUBH, _SUBL, _SUB_HL, _SUBA, _SUBN
_SUBB:  __SUBs BYTE [rB], 4
_SUBC:  __SUBs BYTE [rC], 4
_SUBD:  __SUBs BYTE [rD], 4
_SUBE:  __SUBs BYTE [rE], 4
_SUBH:  __SUBs BYTE [rH], 4
_SUBL:  __SUBs BYTE [rL], 4
_SUB_HL:movzx esi, WORD [rL]
        call read_mem
        __SUBs [rsi], 7
_SUBA:  __SUBs BYTE [rAcc], 4
_SUBN:  inc DWORD [rPCx]
        __SUBs [rsi+1], 7

; * SBC A,s - (98-9F,DE) - 4/7 Clk - Subtract operand s from accumulator with carry
; ***********************************************************************************
GLOBAL _SBCAB, _SBCAC, _SBCAD, _SBCAE, _SBCAH, _SBCAL, _SBCA_HL, _SBCAA, _SBCAN
_SBCAB: __SBCAs BYTE [rB], 4
_SBCAC: __SBCAs BYTE [rC], 4
_SBCAD: __SBCAs BYTE [rD], 4
_SBCAE: __SBCAs BYTE [rE], 4
_SBCAH: __SBCAs BYTE [rH], 4
_SBCAL: __SBCAs BYTE [rL], 4
_SBCA_HL:movzx esi, WORD [rL]
        call read_mem
        __SBCAs [rsi], 7
_SBCAA: __SBCAs BYTE [rAcc], 4
_SBCAN: inc DWORD [rPCx]
        __SBCAs [rsi+1], 7

; * AND s - (A0-A7,E6) - 4/7 Clk - Logical AND of operand s to accumulator
; **************************************************************************
GLOBAL _ANDB, _ANDC, _ANDD, _ANDE, _ANDH, _ANDL, _AND_HL, _ANDA, _ANDN
_ANDB:  __ANDs BYTE [rB], 4
_ANDC:  __ANDs BYTE [rC], 4
_ANDD:  __ANDs BYTE [rD], 4
_ANDE:  __ANDs BYTE [rE], 4
_ANDH:  __ANDs BYTE [rH], 4
_ANDL:  __ANDs BYTE [rL], 4
_AND_HL:movzx esi, WORD [rL]
        call read_mem
        __ANDs [rsi], 7
_ANDA:  __ANDs BYTE [rAcc], 4
_ANDN:  inc DWORD [rPCx]
        __ANDs [rsi+1], 7

; * XOR s - (A8-AF,EE) - 4/7 Clk - Exclusive OR operand s and accumulator
; *************************************************************************
GLOBAL _XORB, _XORC, _XORD, _XORE, _XORH, _XORL, _XOR_HL, _XORA, _XORN
_XORB:  __XORs BYTE [rB], 4
_XORC:  __XORs BYTE [rC], 4
_XORD:  __XORs BYTE [rD], 4
_XORE:  __XORs BYTE [rE], 4
_XORH:  __XORs BYTE [rH], 4 
_XORL:  __XORs BYTE [rL], 4
_XOR_HL:movzx esi, WORD [rL]
        call read_mem
        __XORs [rsi], 7
_XORA:  __XORs BYTE [rAcc], 4
_XORN:  inc DWORD [rPCx]
        __XORs [rsi+1], 7

; * OR s - (B0-B7,F6) - 4/7 Clk - Logical OR of operand s and accumulator
; *************************************************************************
GLOBAL _ORB, _ORC, _ORD, _ORE, _ORH, _ORL, _OR_HL, _ORA, _ORN
_ORB:   __ORs BYTE [rB], 4
_ORC:   __ORs BYTE [rC], 4
_ORD:   __ORs BYTE [rD], 4
_ORE:   __ORs BYTE [rE], 4
_ORH:   __ORs BYTE [rH], 4
_ORL:   __ORs BYTE [rL], 4
_OR_HL: movzx esi, WORD [rL]
        call read_mem
        __ORs [rsi], 7
_ORA:   __ORs BYTE [rAcc], 4
_ORN:   inc DWORD [rPCx]
        __ORs [rsi+1], 7

; * CP s - (B8-BF,FE) - 4/7 Clk - Compare operand s with accumulator
; ********************************************************************
GLOBAL _CPB, _CPC, _CPD2, _CPE, _CPH, _CPL, _CP_HL, _CPA, _CPN
_CPB:   __CPs BYTE [rB], 4
_CPC:   __CPs BYTE [rC], 4
_CPD2:  __CPs BYTE [rD], 4
_CPE:   __CPs BYTE [rE], 4
_CPH:   __CPs BYTE [rH], 4
_CPL:   __CPs BYTE [rL], 4
_CP_HL: movzx esi, WORD [rL]
        call read_mem
        __CPs [rsi], 7
_CPA:   __CPs BYTE [rAcc], 4
_CPN:   inc DWORD [rPCx]
        __CPs [rsi+1], 7

; * RET cc - (C0,C8,D0,D8,E0,E8,F0,F8) - 5/11 Clk - Return from subroutine if condition cc is true
; **************************************************************************************************
GLOBAL _RETNZ, _RETZ, _RETNC, _RETC, _RETPO, _RETPE, _RETP, _RETM
_RETNZ: __RETcc nz, 40h
_RETZ:  __RETcc z, 40h
_RETNC: __RETcc nz, 1h
_RETC:  __RETcc z, 1h
_RETPO: __RETcc nz, 4h
_RETPE: __RETcc z, 4h
_RETP:  __RETcc nz, 80h
_RETM:  __RETcc z, 80h

; * POP dd - (C1,D1,E1,F1) - 10 Clk - Load register pair dd with top of stack
; *****************************************************************************
GLOBAL _POPBC, _POPDE, _POPHL, _POPAF
_POPBC: __POPrr BYTE [rC]
_POPDE: __POPrr BYTE [rE]
_POPHL: __POPrr BYTE [rL]
_POPAF: __POPrr BYTE [Flag]

; * JP cc, n - (C2,CA,D2,DA,E2,EA,F2,FA) n n - 10 Clk - Jump to location nn if condition cc is true
; ***************************************************************************************************
GLOBAL _JPNZN, _JPZN, _JPNCN, _JPCN, _JPPON, _JPPEN, _JPPN, _JPMN
_JPNZN: __JPccnn nz, 40h
_JPZN:  __JPccnn z, 40h
_JPNCN: __JPccnn nz, 1h
_JPCN:  __JPccnn z, 1h
_JPPON: __JPccnn nz, 4h
_JPPEN: __JPccnn z, 4h
_JPPN:  __JPccnn nz, 80h
_JPMN:  __JPccnn z, 80h

; * JP n - C3 n n - 10 Clk - Jump
; *********************************
GLOBAL _JPN
_JPN:
        movzx eax, WORD [rsi+1]
        mov DWORD [rPCx], eax
        add BYTE [TClock], 10
        jmp TLF

; * CALL cc, nn - (C4,CC,D4,DC,E4,EC,F4,FC) - 10/17 Clk - Call subroutine at location nn if condition CC is true
; ****************************************************************************************************************
GLOBAL _CALLNZN, _CALLZN, _CALLNCN, _CALLCN, _CALLPON, _CALLPEN, _CALLPN, _CALLMN
_CALLNZN:__CALLccnn nz, 40h
_CALLZN: __CALLccnn z, 40h
_CALLNCN:__CALLccnn nz, 1h
_CALLCN: __CALLccnn z, 1h
_CALLPON:__CALLccnn nz, 4h
_CALLPEN:__CALLccnn z, 4h
_CALLPN: __CALLccnn nz, 80h
_CALLMN: __CALLccnn z, 80h

; * PUSH qq - (C5,D5,E5,F5) - 11 Clk - Load register pair dd onto stack
; ***********************************************************************
GLOBAL _PUSHBC, _PUSHDE, _PUSHHL, _PUSHAF
_PUSHBC:__PUSHqq BYTE [rC]
_PUSHDE:__PUSHqq BYTE [rE]
_PUSHHL:__PUSHqq BYTE [rL]
_PUSHAF:__PUSHqq BYTE [Flag]

; * RST p - (C7,CF,D7,DF,E7,EF,D7,DF) - 11 Clk - Restart to location p
; **********************************************************************
GLOBAL _RST0, _RST8, _RST10, _RST18, _RST20, _RST28, _RST30, _RST38
_RST0:  __RSTp 0h
_RST8:  __RSTp 8h
_RST10: __RSTp 10h
_RST18: __RSTp 18h
_RST20: __RSTp 20h
_RST28: __RSTp 28h
_RST30: __RSTp 30h
_RST38: __RSTp 38h

; * RET - C9 - 10 Clk - Return from subroutine
; **********************************************
GLOBAL _RET
_RET:
        mov esi, DWORD [rSPx]
        add DWORD [rSPx], 2
        call read_mem
        movzx eax, WORD [rsi]
        mov DWORD [rPCx], eax
        add BYTE [TClock], 10
        jmp TLF

; * Prefixo CB
; **************
GLOBAL _CB
_CB:
        inc BYTE [rR]
        movzx edx, BYTE [rsi+1]
        jmp QWORD [OpcodeCB+edx*8]

; * CALL n - CD n n - 17 Clk - Call subroutine
; **********************************************
GLOBAL _CALLN
_CALLN:
        movzx edx, WORD [rsi+1]
        mov eax, DWORD [rPCx]
        add eax, 3
        sub DWORD [rSPx], 2
        mov esi, DWORD [rSPx]
        call write_mem
        mov [rsi], ax
        mov DWORD [rPCx], edx
        add BYTE [TClock], 17
        jmp TLF

; * OUT (n), A - D3 n - 11 Clk - Load output port (n) with accumulator
; **********************************************************************
GLOBAL _OUTNA
_OUTNA:
        mov al, BYTE [rAcc]
        movzx edx, BYTE [rsi+1]
        call QWORD [write_io+edx*8]
        add DWORD [rPCx], 2
        add BYTE [TClock], 11
        jmp TLF

; * EXX - D9 - 04 Clk - Exchange the contents of BC,DE,HL with BC',DE',HL'
; **************************************************************************
GLOBAL _EXX
_EXX:
        rol DWORD [rC], 16
        rol DWORD [rE], 16
        rol DWORD [rL], 16
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * Prefixo DD
; **************
GLOBAL _DD
_DD:
        inc BYTE [rR]
        movzx edx, BYTE [rsi+1]
        jmp QWORD [OpcodeDD+edx*8]

; * IN A, (n) - DB n - 11 Clk - Load the accumulator with input from device n
; *****************************************************************************
GLOBAL _INA_N
_INA_N:
        movzx edx, BYTE [rsi+1]
        call QWORD [read_io+edx*8]
        mov BYTE [rAcc], al
        add DWORD [rPCx], 2
        add BYTE [TClock], 11
        jmp TLF

; * EX (SP), HL - E3 - 19 Clk - Exchange the location (SP) and HL
; *****************************************************************
GLOBAL _EX_SP_HL
_EX_SP_HL:
        __EX_SP_r WORD [rL], 19

; * JP (HL) - E9 - 4 Clk - Unconditional jump to location (HL)
; **************************************************************
GLOBAL _JP_HL
_JP_HL:
        movzx eax, WORD [rL]
        mov DWORD [rPCx], eax
        add BYTE [TClock], 4
        jmp TLF

; * EX DE, HL - EB - 4 Clk - Exchange the contents of DE and HL
; ***************************************************************
GLOBAL _EXDEHL
_EXDEHL:
        mov ax, WORD [rE]
        mov bx, WORD [rL]
        mov WORD [rE], bx
        mov WORD [rL], ax
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * Prefixo ED
; **************
GLOBAL _ED
_ED:
        inc BYTE [rR]
        movzx edx, BYTE [rsi+1]
        jmp QWORD [OpcodeED+edx*8]

; * DI - F3 - 4 Clk - Disable interrupts
; ****************************************
GLOBAL _DI
_DI:
        mov BYTE [IFF1], 0
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TLF

; * LD SP, HL - F9 - 20 Clk - Load SP with HL
; *********************************************
GLOBAL _LDSPHL
_LDSPHL:
        movzx eax, WORD [rL]
        mov DWORD [rSPx], eax
        inc DWORD [rPCx]
        add BYTE [TClock], 20
        jmp TLF

; * EI - FB - 4 Clk - Enable interrupts
; ***************************************
GLOBAL _EI
_EI:
        mov BYTE [IFF1], 1
        mov BYTE [IFF2], 1
        inc DWORD [rPCx]
        add BYTE [TClock], 4
        jmp TraceLine       ; Força a próxima instrução ser executada

; * Prefixo FD
; **************
GLOBAL _FD
_FD:
        inc BYTE [rR]
        movzx edx, BYTE [rsi+1]
        jmp QWORD [OpcodeFD+edx*8]


; ***************************************************************************************
; * Macros
; ***************************************************************************************

; * Rotate operand m left circular
; **********************************
%MACRO __RLCr 3
        rol %1, 1
        setc BYTE [Flag]
        mov al, %1
        or al, al
        lahf
        and ah, 11000100b
        or BYTE [Flag], ah
        add DWORD [rPCx], %3
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Rotate operand m right circular
; ***********************************
%MACRO __RRCr 3
        ror %1, 1
        setc BYTE [Flag]
        mov al, %1
        or al, al
        lahf
        and ah, 11000100b
        or BYTE [Flag], ah
        add DWORD [rPCx], %3
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Rotate left through operand m
; *********************************
%MACRO __RLr 3
        shr BYTE [Flag], 1
        rcl %1, 1
        setc BYTE [Flag]
        mov al, %1
        or al, al
        lahf
        and ah, 11000100b
        or BYTE [Flag], ah
        add DWORD [rPCx], %3
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Rotate right through operand m
; **********************************
%MACRO __RRr 3
        shr BYTE [Flag], 1
        rcr %1, 1
        setc BYTE [Flag]
        mov al, %1
        or al, al
        lahf
        and ah, 11000100b
        or BYTE [Flag], ah
        add DWORD [rPCx], %3
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Load output port (C) with register r
; ****************************************
%MACRO __OUT_C_r 1
        mov al, %1
        movzx edx, BYTE [rC]
        call QWORD [write_io+edx*8]
        add DWORD [rPCx], 2
        add BYTE [TClock], 12
        jmp TLF
%ENDMACRO

; * Load register %1 with location (I$+d)
; ****************************************
%MACRO __LDrId 2
        movsx esi, BYTE [rsi+2]
        add esi, %2
        and esi, 0FFFFh
        call read_mem
        mov al, [rsi]
        mov %1, al
        add DWORD [rPCx], 3
        add BYTE [TClock], 19
        jmp TLF
%ENDMACRO

; * Load location (I$+d) with register r
; ****************************************
%MACRO __LDIdr 3
        mov al, %2
        movsx esi, BYTE [rsi+2]
        add esi, %1
        and esi, 0FFFFh
        call write_mem
        mov [rsi], al
        add DWORD [rPCx], %3
        add BYTE [TClock], 19
        jmp TLF
%ENDMACRO

; * Set bit b of register %2
; ***************************
%MACRO __SETbr 4
        or %2, %1
        add DWORD [rPCx], %4
        add BYTE [TClock], %3
        jmp TLF
%ENDMACRO

; * Set bit b of location (HL)
; ******************************
%MACRO __SETb_HL 1
        movzx esi, WORD [rL]
        mov edi, esi
        call read_mem
        mov al, [rsi]
        or al, %1
        mov esi, edi
        call write_mem
        mov [rsi], al
        add DWORD [rPCx], 2
        add BYTE [TClock], 15
        jmp TLF
%ENDMACRO

; * Set bit b of location (I$+d)
; ********************************
%MACRO __SETb_Id 2
        movsx esi, BYTE [rsi+2]
        add esi, %2
        and esi, 0FFFFh
        call read_mem
        __SETbr %1, BYTE [rsi], 23, 4
%ENDMACRO

; * Reset bit b of register r
; *****************************
%MACRO __RESbr 4
        and %2, ~%1
        add DWORD [rPCx], %4
        add BYTE [TClock], %3
        jmp TLF
%ENDMACRO

; * Reset bit b of location (HL)
; ********************************
%MACRO __RESb_HL 1
        movzx esi, WORD [rL]
        mov edi, esi
        call read_mem
        mov al, [rsi]
        and al, ~%1
        mov esi, edi
        call write_mem
        mov [rsi], al
        add DWORD [rPCx], 2
        add BYTE [TClock], 15
        jmp TLF
%ENDMACRO

; * Reset bit b of location (I$+d)
; **********************************
%MACRO __RESb_Id 2
        movsx esi, BYTE [rsi+2]
        add esi, %2
        and esi, 0FFFFh
        call read_mem
        __RESbr %1, BYTE [rsi], 23, 4
%ENDMACRO

; * Test bit b of register r
; ****************************
%MACRO __BITbr 4
        and BYTE [Flag], 1
        or BYTE [Flag], 10h
        test %2, %1
        lahf
        and ah, 11000100b
        or BYTE [Flag], ah
        add DWORD [rPCx], %4
        add BYTE [TClock], %3
        jmp TLF
%ENDMACRO

; * Test bit b of location (HL)
; *******************************
%MACRO __BITb_HL 1
        movzx esi, WORD [rL]
        call read_mem
        __BITbr %1, BYTE [rsi], 12, 2
%ENDMACRO

; * Test bit b of location (I$+d)
; *******************************
%MACRO __BITb_Id 2
        movsx esi, BYTE [rsi+2]
        add esi, %2
        and esi, 0FFFFh
        call read_mem
        __BITbr %1, BYTE [rsi], 20, 4
%ENDMACRO

; * Shift operand m right logical
; *********************************
%MACRO __SRLr 3
        shr %1, 1
        lahf
        and ah, 11000101b
        mov BYTE [Flag], ah
        add DWORD [rPCx], %3
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Load register pair dd with location (nn)
; ********************************************
%MACRO __LDdd_n 1
        movzx esi, WORD [rsi+2]
        mov edi, esi
        call read_mem
        mov al, [rsi]
        mov BYTE [%1], al
        mov esi, edi
        inc esi
        call read_mem
        mov al, [rsi]
        mov BYTE [%1+1], al
        add DWORD [rPCx], 4
        add BYTE [TClock], 20
        jmp TLF
%ENDMACRO

; * Load location (nn) with register pair dd
; ********************************************
%MACRO __LD_nn_dd 2
        movzx esi, WORD [rsi+2]
        cmp esi, 0FFFCh
        jae %%A
        mov %2, [%1]
        call write_mem
        mov [rsi], ax
        jmp %%B
%%A:    mov edi, esi
        mov al, BYTE [%1]
        call write_mem
        mov [rsi], al
        mov esi, edi
        inc esi
        mov al, BYTE [%1+1]
        call write_mem
        mov [rsi], al
%%B:    add DWORD [rPCx], 4
        add BYTE [TClock], 20
        jmp TLF
%ENDMACRO

; * Set interrupt mode m
; ************************
%MACRO __IM 1
        mov BYTE [IM], %1
        add DWORD [rPCx], 2
        add BYTE [TClock], 8
        jmp TLF
%ENDMACRO

; * Add register pair PP to IX
; ******************************
%MACRO __ADDIpp 2
        and BYTE [Flag], 11000100b
        mov ax, WORD [%2]
        add BYTE [%1], al
        adc BYTE [%1+1], ah
        lahf
        and ah, 10001b
        or BYTE [Flag], ah
%%A:    add DWORD [rPCx], 2
        add BYTE [TClock], 15
        jmp TLF
%ENDMACRO

; * Load the register r with input from device (C)
; **************************************************
%MACRO __INr_C 1
        and BYTE [Flag], 1
        movzx edx, BYTE [rC]
        call QWORD [read_io+edx*8]
        mov %1, al
        or al, al
        lahf
        and ah, 11000100b
        or BYTE [Flag], ah
        add DWORD [rPCx], 2
        add BYTE [TClock], 12
        jmp TLF
%ENDMACRO

; * Increment I$
; ****************
%MACRO __INCI 1
        inc %1
        add DWORD [rPCx], 2
        add BYTE [TClock], 10
        jmp TLF
%ENDMACRO

; * Decrement I$
; ****************
%MACRO __DECI 1
        dec %1
        add DWORD [rPCx], 2
        add BYTE [TClock], 10
        jmp TLF
%ENDMACRO

; * Add with carry register pair ss to HL
; *****************************************
%MACRO __ADCHLss 1
        mov ax, WORD %1
        mov bl, BYTE [Flag]
        mov BYTE [Flag], 0
        shr bl, 1
        adc BYTE [rL], al
        adc BYTE [rH], ah
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 10010001b
        or BYTE [Flag], ah
        cmp WORD [rL], 0
        jne %%B
        or BYTE [Flag], 40h
%%B:    add DWORD [rPCx], 2
        add BYTE [TClock], 15
        jmp TLF
%ENDMACRO

; * Subtract register pair %1 from HL with carry
; ************************************************
%MACRO __SBCHLss 1
        mov ax, WORD %1
        mov bl, BYTE [Flag]
        mov BYTE [Flag], 2
        shr bl, 1
        sbb BYTE [rL], al
        sbb BYTE [rH], ah
        lahf
        jno %%A
        or BYTE [Flag], 4
%%A:    and ah, 10010001b
        or BYTE [Flag], ah
        cmp WORD [rL], 0
        jne %%B
        or BYTE [Flag], 40h
%%B:    add DWORD [rPCx], 2
        add BYTE [TClock], 15
        jmp TLF
%ENDMACRO

; * Shift operand m left arithmetic
; ***********************************
%MACRO __SLAm 3
        shl %1, 1
        lahf
        and ah, 11000101b
        mov BYTE [Flag], ah
        add DWORD [rPCx], %3
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Shift operand %1 left logic
; ******************************
%MACRO __SLLm 3
        mov BYTE [Flag], 0
        shl %1, 1
        jnc %%A
        or BYTE [Flag], 1
%%A:    or %1, 1
        lahf
        and ah, 11000100b
        or BYTE [Flag], ah
        add DWORD [rPCx], %3
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Shift operand %1 right arithmetic
; ************************************
%MACRO __SRAm 3
        sar %1, 1
        lahf
        and ah, 11000101b
        mov BYTE [Flag], ah
        add DWORD [rPCx], %3 
        add BYTE [TClock], %2
        jmp TLF
%ENDMACRO

; * Carrega a parte low/high do registro de índice
; **************************************************
%MACRO __LDIr 2
        mov al, %2
        mov %1, al
        add DWORD [rPCx], 2
        add BYTE [TClock], 8
        jmp TLF
%ENDMACRO

; * Carrega a parte low/high do registro de índice com um valor imediato
; ************************************************************************
%MACRO __LDIn 1
        mov al, [rsi+2]
        mov %1, al
        add DWORD [rPCx], 3
        add BYTE [TClock], 11
        jmp TLF
%ENDMACRO


; ***************************************************************************************
; * Prefix CB
; ***************************************************************************************

; * RLC r - CB (00-07) - 8/15 Clk - Rotate operand r left circular
; ******************************************************************
GLOBAL _RLCB, _RLCC, _RLCD, _RLCE, _RLCH, _RLCL, _RLC_HL, _RLCA2
_RLCB:  __RLCr BYTE [rB], 8, 2
_RLCC:  __RLCr BYTE [rC], 8, 2
_RLCD:  __RLCr BYTE [rD], 8, 2
_RLCE:  __RLCr BYTE [rE], 8, 2
_RLCH:  __RLCr BYTE [rH], 8, 2
_RLCL:  __RLCr BYTE [rL], 8, 2
_RLC_HL:movzx esi, WORD [rL]
        call read_mem
        __RLCr BYTE [rsi], 15, 2
_RLCA2: __RLCr BYTE [rAcc], 8, 2

; * RRC r - CB (08-0F) - 8/15 Clk - Rotate operand r right circular
; *******************************************************************
GLOBAL _RRCB, _RRCC, _RRCD, _RRCE, _RRCH, _RRCL, _RRC_HL, _RRCA2
_RRCB:  __RRCr BYTE [rB], 8, 2
_RRCC:  __RRCr BYTE [rC], 8, 2
_RRCD:  __RRCr BYTE [rD], 8, 2
_RRCE:  __RRCr BYTE [rE], 8, 2
_RRCH:  __RRCr BYTE [rH], 8, 2
_RRCL:  __RRCr BYTE [rL], 8, 2
_RRC_HL:movzx esi, WORD [rL]
        call read_mem
        __RRCr BYTE [rsi], 15, 2
_RRCA2: __RRCr BYTE [rAcc], 8, 2

; * RL r - CB (10-17) - 8/15 Clk - Rotate left through operand m
; ****************************************************************
GLOBAL _RLB, _RLC, _RLD2, _RLE, _RLH, _RLL, _RL_HL, _RLA2
_RLB:   __RLr BYTE [rB], 8, 2
_RLC:   __RLr BYTE [rC], 8, 2
_RLD2:  __RLr BYTE [rD], 8, 2
_RLE:   __RLr BYTE [rE], 8, 2
_RLH:   __RLr BYTE [rH], 8, 2
_RLL:   __RLr BYTE [rL], 8, 2
_RL_HL:movzx esi, WORD [rL]
        call read_mem
        __RLr BYTE [rsi], 15, 2
_RLA2:  __RLr BYTE [rAcc], 8, 2

; * RR r - CB (18-1F) - 8/15 Clk - Rotate right through operand m
; *****************************************************************
GLOBAL _RRB, _RRC, _RRD2, _RRE, _RRH, _RRL, _RR_HL, _RRA2
_RRB:   __RRr BYTE [rB], 8, 2
_RRC:   __RRr BYTE [rC], 8, 2
_RRD2:  __RRr BYTE [rD], 8, 2
_RRE:   __RRr BYTE [rE], 8, 2
_RRH:   __RRr BYTE [rH], 8, 2
_RRL:   __RRr BYTE [rL], 8, 2
_RR_HL:movzx esi, WORD [rL]
        call read_mem
        __RRr BYTE [rsi], 15, 2
_RRA2:  __RRr BYTE [rAcc], 8, 2

; * SLA m - CB (20-27) - 8/15 Clk - Shift operand m left arithmetic
; *******************************************************************
GLOBAL _SLAB, _SLAC, _SLAD, _SLAE, _SLAH, _SLAL, _SLA_HL, _SLAA
_SLAB:  __SLAm BYTE [rB], 8, 2
_SLAC:  __SLAm BYTE [rC], 8, 2
_SLAD:  __SLAm BYTE [rD], 8, 2
_SLAE:  __SLAm BYTE [rE], 8, 2
_SLAH:  __SLAm BYTE [rH], 8, 2
_SLAL:  __SLAm BYTE [rL], 8, 2
_SLA_HL:movzx esi, WORD [rL]
        call read_mem
        __SLAm BYTE [rsi], 15, 2
_SLAA:  __SLAm BYTE [rAcc], 8, 2

; * SRA m - CB (28-2F) - 8/15 Clk - Shift operand m right arithmetic
; ********************************************************************
GLOBAL _SRAB, _SRAC, _SRAD, _SRAE, _SRAH, _SRAL, _SRA_HL, _SRAA
_SRAB:  __SRAm BYTE [rB], 8, 2
_SRAC:  __SRAm BYTE [rC], 8, 2
_SRAD:  __SRAm BYTE [rD], 8, 2
_SRAE:  __SRAm BYTE [rE], 8, 2
_SRAH:  __SRAm BYTE [rH], 8, 2
_SRAL:  __SRAm BYTE [rL], 8, 2
_SRA_HL:movzx esi, WORD [rL]
        call read_mem
        __SRAm BYTE [rsi], 15, 2
_SRAA:  __SRAm BYTE [rAcc], 8, 2

; * SLL m - CB (30-37) - 8/15 Clk - Shift operand m left logic
; **************************************************************
GLOBAL _SLLB, _SLLC, _SLLD, _SLLE, _SLLH, _SLLL, _SLL_HL, _SLLA
_SLLB:  __SLLm BYTE [rB], 8, 2
_SLLC:  __SLLm BYTE [rC], 8, 2
_SLLD:  __SLLm BYTE [rD], 8, 2
_SLLE:  __SLLm BYTE [rE], 8, 2
_SLLH:  __SLLm BYTE [rH], 8, 2
_SLLL:  __SLLm BYTE [rL], 8, 2
_SLL_HL:movzx esi, WORD [rL]
        call read_mem
        __SLLm BYTE [rsi], 15, 2
_SLLA:  __SLLm BYTE [rAcc], 8, 2

; * SRL r - CB (38-3F) - 8/15 Clk - Shift operand r right logical
; *************************************************-***************
GLOBAL _SRLB, _SRLC, _SRLD, _SRLE, _SRLH, _SRLL, _SRL_HL, _SRLA
_SRLB:  __SRLr BYTE [rB], 8, 2
_SRLC:  __SRLr BYTE [rC], 8, 2
_SRLD:  __SRLr BYTE [rD], 8, 2
_SRLE:  __SRLr BYTE [rE], 8, 2
_SRLH:  __SRLr BYTE [rH], 8, 2
_SRLL:  __SRLr BYTE [rL], 8, 2
_SRL_HL:movzx esi, WORD [rL]
        call read_mem
        __SRLr BYTE [rsi], 15, 2
_SRLA:  __SRLr BYTE [rAcc], 8, 2

; * BIT 0, r - CB (40-47) - 8/12 Clk - Test bit 0 of operand r
; **************************************************************
GLOBAL _BIT0B, _BIT0C, _BIT0D, _BIT0E, _BIT0H, _BIT0L, _BIT0_HL, _BIT0A
_BIT0B: __BITbr 1h, BYTE [rB], 8, 2
_BIT0C: __BITbr 1h, BYTE [rC], 8, 2
_BIT0D: __BITbr 1h, BYTE [rD], 8, 2
_BIT0E: __BITbr 1h, BYTE [rE], 8, 2
_BIT0H: __BITbr 1h, BYTE [rH], 8, 2
_BIT0L: __BITbr 1h, BYTE [rL], 8, 2
_BIT0_HL:__BITb_HL 1h
_BIT0A: __BITbr 1h, BYTE [rAcc], 8, 2

; * BIT 1, r - CB (48-4F) - 8/12 Clk - Test bit 1 of operand r
; **************************************************************
GLOBAL _BIT1B, _BIT1C, _BIT1D, _BIT1E, _BIT1H, _BIT1L, _BIT1_HL, _BIT1A
_BIT1B: __BITbr 2h, BYTE [rB], 8, 2
_BIT1C: __BITbr 2h, BYTE [rC], 8, 2
_BIT1D: __BITbr 2h, BYTE [rD], 8, 2
_BIT1E: __BITbr 2h, BYTE [rE], 8, 2
_BIT1H: __BITbr 2h, BYTE [rH], 8, 2
_BIT1L: __BITbr 2h, BYTE [rL], 8, 2
_BIT1_HL:__BITb_HL 2h
_BIT1A: __BITbr 2h, BYTE [rAcc], 8, 2

; * BIT 2, r - CB (50-57) - 8/12 Clk - Test bit 2 of operand r
; **************************************************************
GLOBAL _BIT2B, _BIT2C, _BIT2D, _BIT2E, _BIT2H, _BIT2L, _BIT2_HL, _BIT2A
_BIT2B: __BITbr 4h, BYTE [rB], 8, 2
_BIT2C: __BITbr 4h, BYTE [rC], 8, 2
_BIT2D: __BITbr 4h, BYTE [rD], 8, 2
_BIT2E: __BITbr 4h, BYTE [rE], 8, 2
_BIT2H: __BITbr 4h, BYTE [rH], 8, 2
_BIT2L: __BITbr 4h, BYTE [rL], 8, 2
_BIT2_HL:__BITb_HL 4h
_BIT2A: __BITbr 4h, BYTE [rAcc], 8, 2

; * BIT 3, r - CB (58-5F) - 8/12 Clk - Test bit 3 of operand r
; **************************************************************
GLOBAL _BIT3B, _BIT3C, _BIT3D, _BIT3E, _BIT3H, _BIT3L, _BIT3_HL, _BIT3A
_BIT3B: __BITbr 8h, BYTE [rB], 8, 2
_BIT3C: __BITbr 8h, BYTE [rC], 8, 2
_BIT3D: __BITbr 8h, BYTE [rD], 8, 2
_BIT3E: __BITbr 8h, BYTE [rE], 8, 2
_BIT3H: __BITbr 8h, BYTE [rH], 8, 2
_BIT3L: __BITbr 8h, BYTE [rL], 8, 2
_BIT3_HL:__BITb_HL 8h
_BIT3A: __BITbr 8h, BYTE [rAcc], 8, 2

; * BIT 4, r - CB (60-67) - 8/12 Clk - Test bit 4 of operand r
; **************************************************************
GLOBAL _BIT4B, _BIT4C, _BIT4D, _BIT4E, _BIT4H, _BIT4L, _BIT4_HL, _BIT4A
_BIT4B: __BITbr 10h, BYTE [rB], 8, 2
_BIT4C: __BITbr 10h, BYTE [rC], 8, 2
_BIT4D: __BITbr 10h, BYTE [rD], 8, 2
_BIT4E: __BITbr 10h, BYTE [rE], 8, 2
_BIT4H: __BITbr 10h, BYTE [rH], 8, 2
_BIT4L: __BITbr 10h, BYTE [rL], 8, 2
_BIT4_HL:__BITb_HL 10h
_BIT4A: __BITbr 10h, BYTE [rAcc], 8, 2

; * BIT 5, r - CB (68-6F) - 8/12 Clk - Test bit 5 of operand r
; **************************************************************
GLOBAL _BIT5B, _BIT5C, _BIT5D, _BIT5E, _BIT5H, _BIT5L, _BIT5_HL, _BIT5A
_BIT5B: __BITbr 20h, BYTE [rB], 8, 2
_BIT5C: __BITbr 20h, BYTE [rC], 8, 2
_BIT5D: __BITbr 20h, BYTE [rD], 8, 2
_BIT5E: __BITbr 20h, BYTE [rE], 8, 2
_BIT5H: __BITbr 20h, BYTE [rH], 8, 2
_BIT5L: __BITbr 20h, BYTE [rL], 8, 2
_BIT5_HL:__BITb_HL 20h
_BIT5A: __BITbr 20h, BYTE [rAcc], 8, 2

; * BIT 6, r - CB (70-77) - 8/12 Clk - Test bit 6 of operand r
; **************************************************************
GLOBAL _BIT6B, _BIT6C, _BIT6D, _BIT6E, _BIT6H, _BIT6L, _BIT6_HL, _BIT6A
_BIT6B: __BITbr 40h, BYTE [rB], 8, 2
_BIT6C: __BITbr 40h, BYTE [rC], 8, 2
_BIT6D: __BITbr 40h, BYTE [rD], 8, 2
_BIT6E: __BITbr 40h, BYTE [rE], 8, 2
_BIT6H: __BITbr 40h, BYTE [rH], 8, 2
_BIT6L: __BITbr 40h, BYTE [rL], 8, 2
_BIT6_HL:__BITb_HL 40h
_BIT6A: __BITbr 40h, BYTE [rAcc], 8, 2

; * BIT 7, r - CB (78-7F) - 8/12 Clk - Test bit 7 of operand r
; **************************************************************
GLOBAL _BIT7B, _BIT7C, _BIT7D, _BIT7E, _BIT7H, _BIT7L, _BIT7_HL, _BIT7A
_BIT7B: __BITbr 80h, BYTE [rB], 8, 2
_BIT7C: __BITbr 80h, BYTE [rC], 8, 2
_BIT7D: __BITbr 80h, BYTE [rD], 8, 2
_BIT7E: __BITbr 80h, BYTE [rE], 8, 2
_BIT7H: __BITbr 80h, BYTE [rH], 8, 2
_BIT7L: __BITbr 80h, BYTE [rL], 8, 2
_BIT7_HL:__BITb_HL 80h
_BIT7A: __BITbr 80h, BYTE [rAcc], 8, 2

; * RES 0, r - CB (80-87) - 8/15 Clk - Reset bit 0 of operand r
; ***************************************************************
GLOBAL _RES0B, _RES0C, _RES0D, _RES0E, _RES0H, _RES0L, _RES0_HL, _RES0A
_RES0B: __RESbr 1h, BYTE [rB], 8, 2
_RES0C: __RESbr 1h, BYTE [rC], 8, 2
_RES0D: __RESbr 1h, BYTE [rD], 8, 2
_RES0E: __RESbr 1h, BYTE [rE], 8, 2
_RES0H: __RESbr 1h, BYTE [rH], 8, 2
_RES0L: __RESbr 1h, BYTE [rL], 8, 2
_RES0_HL:__RESb_HL 1h
_RES0A: __RESbr 1h, BYTE [rAcc], 8, 2

; * RES 1, r - CB (88-8f) - 8/15 Clk - Reset bit 1 of operand r
; ***************************************************************
GLOBAL _RES1B, _RES1C, _RES1D, _RES1E, _RES1H, _RES1L, _RES1_HL, _RES1A
_RES1B: __RESbr 2h, BYTE [rB], 8, 2
_RES1C: __RESbr 2h, BYTE [rC], 8, 2
_RES1D: __RESbr 2h, BYTE [rD], 8, 2
_RES1E: __RESbr 2h, BYTE [rE], 8, 2
_RES1H: __RESbr 2h, BYTE [rH], 8, 2
_RES1L: __RESbr 2h, BYTE [rL], 8, 2
_RES1_HL:__RESb_HL 2h
_RES1A: __RESbr 2h, BYTE [rAcc], 8, 2

; * RES 2, r - CB (90-97) - 8/15 Clk - Reset bit 2 of operand r
; ***************************************************************
GLOBAL _RES2B, _RES2C, _RES2D, _RES2E, _RES2H, _RES2L, _RES2_HL, _RES2A
_RES2B: __RESbr 4h, BYTE [rB], 8, 2
_RES2C: __RESbr 4h, BYTE [rC], 8, 2
_RES2D: __RESbr 4h, BYTE [rD], 8, 2
_RES2E: __RESbr 4h, BYTE [rE], 8, 2
_RES2H: __RESbr 4h, BYTE [rH], 8, 2
_RES2L: __RESbr 4h, BYTE [rL], 8, 2
_RES2_HL:__RESb_HL 4h
_RES2A: __RESbr 4h, BYTE [rAcc], 8, 2

; * RES 3, r - CB (98-9F) - 8/15 Clk - Reset bit 3 of operand r
; ***************************************************************
GLOBAL _RES3B, _RES3C, _RES3D, _RES3E, _RES3H, _RES3L, _RES3_HL, _RES3A
_RES3B: __RESbr 8h, BYTE [rB], 8, 2
_RES3C: __RESbr 8h, BYTE [rC], 8, 2
_RES3D: __RESbr 8h, BYTE [rD], 8, 2
_RES3E: __RESbr 8h, BYTE [rE], 8, 2
_RES3H: __RESbr 8h, BYTE [rH], 8, 2
_RES3L: __RESbr 8h, BYTE [rL], 8, 2
_RES3_HL:__RESb_HL 8h
_RES3A: __RESbr 8h, BYTE [rAcc], 8, 2

; * RES 4, r - CB (A0-A7) - 8/15 Clk - Reset bit 4 of operand r
; ***************************************************************
GLOBAL _RES4B, _RES4C, _RES4D, _RES4E, _RES4H, _RES4L, _RES4_HL, _RES4A
_RES4B: __RESbr 10h, BYTE [rB], 8, 2
_RES4C: __RESbr 10h, BYTE [rC], 8, 2
_RES4D: __RESbr 10h, BYTE [rD], 8, 2
_RES4E: __RESbr 10h, BYTE [rE], 8, 2
_RES4H: __RESbr 10h, BYTE [rH], 8, 2
_RES4L: __RESbr 10h, BYTE [rL], 8, 2
_RES4_HL:__RESb_HL 10h
_RES4A: __RESbr 10h, BYTE [rAcc], 8, 2

; * RES 5, r - CB (A8-AF) - 8/15 Clk - Reset bit 5 of operand r
; ***************************************************************
GLOBAL _RES5B, _RES5C, _RES5D, _RES5E, _RES5H, _RES5L, _RES5_HL, _RES5A
_RES5B: __RESbr 20h, BYTE [rB], 8, 2
_RES5C: __RESbr 20h, BYTE [rC], 8, 2
_RES5D: __RESbr 20h, BYTE [rD], 8, 2
_RES5E: __RESbr 20h, BYTE [rE], 8, 2
_RES5H: __RESbr 20h, BYTE [rH], 8, 2
_RES5L: __RESbr 20h, BYTE [rL], 8, 2
_RES5_HL:__RESb_HL 20h
_RES5A: __RESbr 20h, BYTE [rAcc], 8, 2

; * RES 6, r - CB (B0-B7) - 8/15 Clk - Reset bit 6 of operand r
; ***************************************************************
GLOBAL _RES6B, _RES6C, _RES6D, _RES6E, _RES6H, _RES6L, _RES6_HL, _RES6A
_RES6B: __RESbr 40h, BYTE [rB], 8, 2
_RES6C: __RESbr 40h, BYTE [rC], 8, 2
_RES6D: __RESbr 40h, BYTE [rD], 8, 2
_RES6E: __RESbr 40h, BYTE [rE], 8, 2
_RES6H: __RESbr 40h, BYTE [rH], 8, 2
_RES6L: __RESbr 40h, BYTE [rL], 8, 2
_RES6_HL:__RESb_HL 40h
_RES6A: __RESbr 40h, BYTE [rAcc], 8, 2

; * RES 7, r - CB (B8-BF) - 8/15 Clk - Reset bit 7 of operand r
; ***************************************************************
GLOBAL _RES7B, _RES7C, _RES7D, _RES7E, _RES7H, _RES7L, _RES7_HL, _RES7A
_RES7B: __RESbr 80h, BYTE [rB], 8, 2
_RES7C: __RESbr 80h, BYTE [rC], 8, 2
_RES7D: __RESbr 80h, BYTE [rD], 8, 2
_RES7E: __RESbr 80h, BYTE [rE], 8, 2
_RES7H: __RESbr 80h, BYTE [rH], 8, 2
_RES7L: __RESbr 80h, BYTE [rL], 8, 2
_RES7_HL:__RESb_HL 80h
_RES7A: __RESbr 80h, BYTE [rAcc], 8, 2

; * SET 0, r - CB (C0-C7) - 8/15 Clk - Set bit 0 of operand r
; *************************************************************
GLOBAL _SET0B, _SET0C, _SET0D, _SET0E, _SET0H, _SET0L, _SET0_HL, _SET0A
_SET0B: __SETbr 1h, BYTE [rB], 8, 2
_SET0C: __SETbr 1h, BYTE [rC], 8, 2
_SET0D: __SETbr 1h, BYTE [rD], 8, 2
_SET0E: __SETbr 1h, BYTE [rE], 8, 2
_SET0H: __SETbr 1h, BYTE [rH], 8, 2
_SET0L: __SETbr 1h, BYTE [rL], 8, 2
_SET0_HL:__SETb_HL 1h
_SET0A: __SETbr 1h, BYTE [rAcc], 8, 2

; * SET 1, r - CB (C8-CF) - 8/15 Clk - Set bit 1 of operand r
; *************************************************************
GLOBAL _SET1B, _SET1C, _SET1D, _SET1E, _SET1H, _SET1L, _SET1_HL, _SET1A
_SET1B: __SETbr 2h, BYTE [rB], 8, 2
_SET1C: __SETbr 2h, BYTE [rC], 8, 2
_SET1D: __SETbr 2h, BYTE [rD], 8, 2
_SET1E: __SETbr 2h, BYTE [rE], 8, 2
_SET1H: __SETbr 2h, BYTE [rH], 8, 2
_SET1L: __SETbr 2h, BYTE [rL], 8, 2
_SET1_HL:__SETb_HL 2h
_SET1A: __SETbr 2h, BYTE [rAcc], 8, 2

; * SET 2, r - CB (D0-D7) - 8/15 Clk - Set bit 2 of operand r
; *************************************************************
GLOBAL _SET2B, _SET2C, _SET2D, _SET2E, _SET2H, _SET2L, _SET2_HL, _SET2A
_SET2B: __SETbr 4h, BYTE [rB], 8, 2
_SET2C: __SETbr 4h, BYTE [rC], 8, 2
_SET2D: __SETbr 4h, BYTE [rD], 8, 2
_SET2E: __SETbr 4h, BYTE [rE], 8, 2
_SET2H: __SETbr 4h, BYTE [rH], 8, 2
_SET2L: __SETbr 4h, BYTE [rL], 8, 2
_SET2_HL:__SETb_HL 4h
_SET2A: __SETbr 4h, BYTE [rAcc], 8, 2

; * SET 3, r - CB (D8-DF) - 8/15 Clk - Set bit 3 of operand r
; *************************************************************
GLOBAL _SET3B, _SET3C, _SET3D, _SET3E, _SET3H, _SET3L, _SET3_HL, _SET3A
_SET3B: __SETbr 8h, BYTE [rB], 8, 2
_SET3C: __SETbr 8h, BYTE [rC], 8, 2
_SET3D: __SETbr 8h, BYTE [rD], 8, 2
_SET3E: __SETbr 8h, BYTE [rE], 8, 2
_SET3H: __SETbr 8h, BYTE [rH], 8, 2
_SET3L: __SETbr 8h, BYTE [rL], 8, 2
_SET3_HL:__SETb_HL 8h
_SET3A: __SETbr 8h, BYTE [rAcc], 8, 2

; * SET 4, r - CB (E0-E7) - 8/15 Clk - Set bit 4 of operand r
; *************************************************************
GLOBAL _SET4B, _SET4C, _SET4D, _SET4E, _SET4H, _SET4L, _SET4_HL, _SET4A
_SET4B: __SETbr 10h, BYTE [rB], 8, 2
_SET4C: __SETbr 10h, BYTE [rC], 8, 2
_SET4D: __SETbr 10h, BYTE [rD], 8, 2
_SET4E: __SETbr 10h, BYTE [rE], 8, 2
_SET4H: __SETbr 10h, BYTE [rH], 8, 2
_SET4L: __SETbr 10h, BYTE [rL], 8, 2
_SET4_HL:__SETb_HL 10h
_SET4A: __SETbr 10h, BYTE [rAcc], 8, 2

; * SET 5, r - CB (E8-EF) - 8/15 Clk - Set bit 5 of operand r
; *************************************************************
GLOBAL _SET5B, _SET5C, _SET5D, _SET5E, _SET5H, _SET5L, _SET5_HL, _SET5A
_SET5B: __SETbr 20h, BYTE [rB], 8, 2
_SET5C: __SETbr 20h, BYTE [rC], 8, 2
_SET5D: __SETbr 20h, BYTE [rD], 8, 2
_SET5E: __SETbr 20h, BYTE [rE], 8, 2
_SET5H: __SETbr 20h, BYTE [rH], 8, 2
_SET5L: __SETbr 20h, BYTE [rL], 8, 2
_SET5_HL:__SETb_HL 20h
_SET5A: __SETbr 20h, BYTE [rAcc], 8, 2

; * SET 6, r - CB (F0-F7) - 8/15 Clk - Set bit 6 of operand r
; *************************************************************
GLOBAL _SET6B, _SET6C, _SET6D, _SET6E, _SET6H, _SET6L, _SET6_HL, _SET6A
_SET6B: __SETbr 40h, BYTE [rB], 8, 2
_SET6C: __SETbr 40h, BYTE [rC], 8, 2
_SET6D: __SETbr 40h, BYTE [rD], 8, 2
_SET6E: __SETbr 40h, BYTE [rE], 8, 2
_SET6H: __SETbr 40h, BYTE [rH], 8, 2
_SET6L: __SETbr 40h, BYTE [rL], 8, 2
_SET6_HL:__SETb_HL 40h
_SET6A: __SETbr 40h, BYTE [rAcc], 8, 2

; * SET 7, r - CB (F8-FF) - 8/15 Clk - Set bit 7 of operand r
; *************************************************************
GLOBAL _SET7B, _SET7C, _SET7D, _SET7E, _SET7H, _SET7L, _SET7_HL, _SET7A
_SET7B: __SETbr 80h, BYTE [rB], 8, 2
_SET7C: __SETbr 80h, BYTE [rC], 8, 2
_SET7D: __SETbr 80h, BYTE [rD], 8, 2
_SET7E: __SETbr 80h, BYTE [rE], 8, 2
_SET7H: __SETbr 80h, BYTE [rH], 8, 2
_SET7L: __SETbr 80h, BYTE [rL], 8, 2
_SET7_HL:__SETb_HL 80h
_SET7A: __SETbr 80h, BYTE [rAcc], 8, 2


; ***************************************************************************************
; * Prefix DD
; ***************************************************************************************

; * ADD IX, pp - DD (09, 19,29,39) - 15 Clk - Add register pair pp to IX
; ************************************************************************
GLOBAL _ADDIXBC, _ADDIXDE, _ADDIXIX, _ADDIXSP
_ADDIXBC:__ADDIpp rIX, rC
_ADDIXDE:__ADDIpp rIX, rE
_ADDIXIX:__ADDIpp rIX, rIX
_ADDIXSP:__ADDIpp rIX, rSPx

; * LD IX, nn - DD 21 n n - 14 Clk - Load IX with value nn
; **********************************************************
GLOBAL _LDIXN
_LDIXN:
        movzx eax, WORD [rsi+2]
        mov DWORD [rIX], eax
        add DWORD [rPCx], 4
        add BYTE [TClock], 14
        jmp TLF

; * LD (nn), IX - DD 22 n n - 20 Clk - Load location (nn) with IX
; *****************************************************************
GLOBAL _LD_N_IX
_LD_N_IX:
        mov eax, DWORD [rIX]
        movzx esi, WORD [rsi+2]
        call write_mem
        mov [rsi], ax
        add DWORD [rPCx], 4
        add BYTE [TClock], 20
        jmp TLF

; * INC IX - DD 23 - 10 Clk - Increment IX
; ******************************************
GLOBAL _INCIX
_INCIX:
        __INCI WORD [rIX]

; * INC IXH - DD 24 - 8 Clk - Incrementa parte do registrador de índice
; ***********************************************************************
GLOBAL _INCIXH
_INCIXH:
        inc DWORD [rPCx]
        __INCr BYTE [rIX+1], 8

; * DEC IXH - DD 25 - 8 Clk - Decrementa parte do registrador de índice
; ***********************************************************************
GLOBAL _DECIXH
_DECIXH:
        inc DWORD [rPCx]
        __DECr BYTE [rIX+1], 8

; * LD IXH, n - DD 26 n - 11 Clk - Carrega a parte high do registro de índice com um valor imediato
; ***************************************************************************************************
GLOBAL _LDIXHN
_LDIXHN:
        __LDIn BYTE [rIX+1]

; * LD IX, (nn) - DD 2A n n - 20 Clk - Load IX with location (nn)
; *****************************************************************
GLOBAL _LDIX_N
_LDIX_N:
        movzx esi, WORD [rsi+2]
        call read_mem
        mov ax, [rsi]
        mov WORD [rIX], ax
        add DWORD [rPCx], 4
        add BYTE [TClock], 20
        jmp TLF

; * DEC IX - DD 2B - 10 Clk - Decrement IX
; ******************************************
GLOBAL _DECIX
_DECIX:
        __DECI WORD [rIX]

; * INC IXL - DD 2C - 8 Clk - Incrementa parte do registrador de índice
; ***********************************************************************
GLOBAL _INCIXL
_INCIXL:
        inc DWORD [rPCx]
        __INCr BYTE [rIX], 8

; * DEC IXL - DD 2D - 8 Clk - Decrementa parte do registrador de índice
; ***********************************************************************
GLOBAL _DECIXL
_DECIXL:
        inc DWORD [rPCx]
        __DECr BYTE [rIX], 8

; * LD IXL, n - DD 2E n - 11 Clk - Carrega a parte low do registro de índice com um valor imediato
; **************************************************************************************************
GLOBAL _LDIXLN
_LDIXLN:
        __LDIn BYTE [rIX]

; * INC (IX+d) - DD 34 - 23 Clk - Increment operand s
; *****************************************************
GLOBAL _INC_IXd
_INC_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __INCr BYTE [rsi], 23

; * DEC (IX+d) - DD 35 - 23 Clk - Decrement operand s
; *****************************************************
GLOBAL _DEC_IXd
_DEC_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __DECr BYTE [rsi], 23

; * LD r, IXH - DD (44,4C,54,5C,7C) - Carrega registrador com a parte high do registro de índice
; ******************************************************************************************************
GLOBAL _LDB_IXH, _LDC_IXH, _LDD_IXH, _LDE_IXH, _LDA_IXH
_LDB_IXH:__LDIr BYTE [rB], BYTE [rIX+1]
_LDC_IXH:__LDIr BYTE [rC], BYTE [rIX+1]
_LDD_IXH:__LDIr BYTE [rD], BYTE [rIX+1]
_LDE_IXH:__LDIr BYTE [rE], BYTE [rIX+1]
_LDA_IXH:__LDIr BYTE [rAcc], BYTE [rIX+1]

; * LD r, IXL - DD (45,4D,55,5D,7D) - Carrega registrador com a parte low do registro de índice
; *****************************************************************************************************
GLOBAL _LDB_IXL, _LDC_IXL, _LDD_IXL, _LDE_IXL, _LDA_IXL
_LDB_IXL:__LDIr BYTE [rB], BYTE [rIX]
_LDC_IXL:__LDIr BYTE [rC], BYTE [rIX]
_LDD_IXL:__LDIr BYTE [rD], BYTE [rIX]
_LDE_IXL:__LDIr BYTE [rE], BYTE [rIX]
_LDA_IXL:__LDIr BYTE [rAcc], BYTE [rIX]

; * LD r, (IX+d) - DD (46,4E,56,5E,66,6E,7E) d - 19 Clk - Load register r with location (IY+d)
; **********************************************************************************************
GLOBAL _LDB_IXD, _LDC_IXD, _LDD_IXD, _LDE_IXD, _LDH_IXD, _LDL_IXD, _LDA_IXD
_LDB_IXD:__LDrId BYTE [rB], DWORD [rIX]
_LDC_IXD:__LDrId BYTE [rC], DWORD [rIX]
_LDD_IXD:__LDrId BYTE [rD], DWORD [rIX]
_LDE_IXD:__LDrId BYTE [rE], DWORD [rIX]
_LDH_IXD:__LDrId BYTE [rH], DWORD [rIX]
_LDL_IXD:__LDrId BYTE [rL], DWORD [rIX]
_LDA_IXD:__LDrId BYTE [rAcc], DWORD [rIX]

; * LD IXH, r - DD (60-67) - 8 Clk - Carrega a parte high do registro de índice
; *******************************************************************************
GLOBAL _LD_IXH_B, _LD_IXH_C, _LD_IXH_D, _LD_IXH_E, _LD_IXH_H, _LD_IXH_L, _LD_IXH_A
_LD_IXH_B:__LDIr BYTE [rIX+1], BYTE [rB]
_LD_IXH_C:__LDIr BYTE [rIX+1], BYTE [rC]
_LD_IXH_D:__LDIr BYTE [rIX+1], BYTE [rD]
_LD_IXH_E:__LDIr BYTE [rIX+1], BYTE [rE]
_LD_IXH_H:__LDIr BYTE [rIX+1], BYTE [rIX+1]
_LD_IXH_L:__LDIr BYTE [rIX+1], BYTE [rIX]
_LD_IXH_A:__LDIr BYTE [rIX+1], BYTE [rAcc]

; * LD IXL, r - DD (68-6F) - 8 Clk - Carrega a parte low do registro de índice
; ******************************************************************************
GLOBAL _LD_IXL_B, _LD_IXL_C, _LD_IXL_D, _LD_IXL_E, _LD_IXL_H, _LD_IXL_L, _LD_IXL_A
_LD_IXL_B:__LDIr BYTE [rIX], BYTE [rB]
_LD_IXL_C:__LDIr BYTE [rIX], BYTE [rC]
_LD_IXL_D:__LDIr BYTE [rIX], BYTE [rD]
_LD_IXL_E:__LDIr BYTE [rIX], BYTE [rE]
_LD_IXL_H:__LDIr BYTE [rIX], BYTE [rIX+1]
_LD_IXL_L:__LDIr BYTE [rIX], BYTE [rIX]
_LD_IXL_A:__LDIr BYTE [rIX], BYTE [rAcc]

; * LD (IX+d), r - DD (70-77,36) d - 19 Clk - Load location (IX+d) with register r
; **********************************************************************************
GLOBAL _LD_IXD_B, _LD_IXD_C, _LD_IXD_D, _LD_IXD_E, _LD_IXD_H, _LD_IXD_L, _LD_IXD_A, _LD_IXD_N
_LD_IXD_B:__LDIdr DWORD [rIX], BYTE [rB], 3
_LD_IXD_C:__LDIdr DWORD [rIX], BYTE [rC], 3
_LD_IXD_D:__LDIdr DWORD [rIX], BYTE [rD], 3
_LD_IXD_E:__LDIdr DWORD [rIX], BYTE [rE], 3
_LD_IXD_H:__LDIdr DWORD [rIX], BYTE [rH], 3
_LD_IXD_L:__LDIdr DWORD [rIX], BYTE [rL], 3
_LD_IXD_A:__LDIdr DWORD [rIX], BYTE [rAcc], 3
_LD_IXD_N:__LDIdr DWORD [rIX], [rsi+3], 4

; * ADD IXH - DD 84 - 8 Clk - Add IXH to accumulator
; ****************************************************
GLOBAL _ADDIXH
_ADDIXH:
        inc DWORD [rPCx]
        __ADDAs BYTE [rIX+1], 8

; * ADD IXL - DD 85 - 8 Clk - Add IXL to accumulator
; ****************************************************
GLOBAL _ADDIXL
_ADDIXL:
        inc DWORD [rPCx]
        __ADDAs BYTE [rIX], 8

; * ADD A, (IX+d) - DD 86 n - 16 Clk - Add location (IX+d) to accumulator
; *************************************************************************
GLOBAL _ADDA_IXd
_ADDA_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __ADDAs [rsi], 16

; * ADC A, (IX+d) - DD 8E - 19 Clk - Add operand s to accumulator with carry
; ****************************************************************************
GLOBAL _ADCA_IXd
_ADCA_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __ADCAs [rsi], 19

; * SUB IXH - DD 94 - 8 Clk - Subtract IXH from accumulator
; ***********************************************************
GLOBAL _SUBIXH
_SUBIXH:
        inc DWORD [rPCx]
        __SUBs BYTE [rIX+1], 8

; * SUB IXL - DD 95 - 8 Clk - Subtract IXL from accumulator
; ***********************************************************
GLOBAL _SUBIXL
_SUBIXL:
        inc DWORD [rPCx]
        __SUBs BYTE [rIX], 8

; * SUB (IX+d) - DD 96 d - 19 Clk - Subtract location (IX+d) from accumulator
; *****************************************************************************
GLOBAL _SUB_IXd
_SUB_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __SUBs [rsi], 19

; * SBC A, (IX+d) - DD 9E d - 19 Clk - Subtract location (IX+d) from accumulator with carry
; *******************************************************************************************
GLOBAL _SBCA_IXd
_SBCA_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __SBCAs [rsi], 19

; * AND IXH - DD A4 - 8 Clk - Logical AND of IXH to accumulator
; ***************************************************************
GLOBAL _ANDIXH
_ANDIXH:
        inc DWORD [rPCx]
        __ANDs BYTE [rIX+1], 8

; * AND IXL - DD A5 - 8 Clk - Logical AND of IXL to accumulator
; ***************************************************************
GLOBAL _ANDIXL
_ANDIXL:
        inc DWORD [rPCx]
        __ANDs BYTE [rIX], 8

; * AND (IX+d) - DD A6 n - 19 Clk - Logical AND of (IX+d) to accumulator
; ************************************************************************
GLOBAL _AND_IXd
_AND_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __ANDs [rsi], 19

; * XOR (IX+d) DD AE d - 19 Clk - Exclusive OR operand r and accumulator
; ************************************************************************
GLOBAL _XOR_IXd
_XOR_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __XORs [rsi], 19

; * OR IXH - DD B4 - 8 Clk - Logical OR of IXH and accumulator
; **************************************************************
GLOBAL _ORIXH
_ORIXH:
        inc DWORD [rPCx]
        __ORs BYTE [rIX+1], 8

; * OR IXL - DD B5 - 8 Clk - Logical OR of IXL and accumulator
; **************************************************************
GLOBAL _ORIXL
_ORIXL:
        inc DWORD [rPCx]
        __ORs BYTE [rIX], 8

; * OR (IX+d) - DD B6 d - 19 Clk - Logical OR of operand s and accumulator
; **************************************************************************
GLOBAL _OR_IXd
_OR_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __ORs [rsi], 19

; * CP IXH - DD BC - 8 Clk - Compare IXH with accumulator
; *********************************************************
GLOBAL _CPIXH
_CPIXH:
        inc DWORD [rPCx]
        __CPs BYTE [rIX+1], 8

; * CP IXL - DD BD - 8 Clk - Compare IXL with accumulator
; *********************************************************
GLOBAL _CPIXL
_CPIXL:
        inc DWORD [rPCx]
        __CPs BYTE [rIX], 8

; * CP (IX+d) - DD BE - 19 Clk - Compare operand s with accumulator
; *******************************************************************
GLOBAL _CP_IXd
_CP_IXd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __CPs [rsi], 19

; * Prefix DD CB
; ****************
GLOBAL _DDCB
_DDCB:
;       inc BYTE [rR]
        movzx edx, BYTE [rsi+3]
        jmp QWORD [OpcodeDDCB+edx*8]

; * POP IX - DD E1 - 14 Clk - Load IX with top of stack
; *******************************************************
GLOBAL _POPIX
_POPIX:
        mov esi, DWORD [rSPx]
        add DWORD [rSPx], 2
        call read_mem
        movzx eax, WORD [rsi]
        mov DWORD [rIX], eax
        add DWORD [rPCx], 2
        add BYTE [TClock], 14
        jmp TLF

; * EX (SP), IX - DD E3 - 23 Clk - Exchange the location (SP) and IX
; ********************************************************************
GLOBAL _EX_SP_IX
_EX_SP_IX:
        inc DWORD [rPCx]
        __EX_SP_r WORD [rIX], 23

; * PUSH IX - DD E5 - 15 Clk - Load IX onto stack
; *************************************************
GLOBAL _PUSHIX
_PUSHIX:
        mov eax, DWORD [rIX]
        sub DWORD [rSPx], 2
        mov esi, DWORD [rSPx]
        call write_mem
        mov [rsi], ax
        add DWORD [rPCx], 2
        add BYTE [TClock], 15
        jmp TLF

; * JP (IX) - DD E9 - 8 Clk - Unconditional jump to location (IX)
; *****************************************************************
GLOBAL _JP_IX
_JP_IX:
        mov eax, DWORD [rIX]
        mov DWORD [rPCx], eax
        add BYTE [TClock], 8
        jmp TLF

; * LD SP, IX - DD F9 - 10 Clk - Load SP with IX
; ************************************************
GLOBAL _LDSPIX
_LDSPIX:
        mov eax, DWORD [rIX]
        mov DWORD [rSPx], eax
        add DWORD [rPCx], 2
        add BYTE [TClock], 10
        jmp TLF


; ***************************************************************************************
; * Prefix DD CB
; ***************************************************************************************

; * RLC (IX+d) - DD CB d 06 - 23 Clk - Rotate operand r left circular
; *********************************************************************
GLOBAL _RLC_IXd
_RLC_IXd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __RLCr BYTE [rsi], 23, 4

; * RRC (IX+d) - DD CB d 0E - 23 Clk - Rotate operand r right circular
; **********************************************************************
GLOBAL _RRC_IXd
_RRC_IXd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __RRCr BYTE [rsi], 23, 4

; * RL (IX+d) - DD CB d 16 - 23 Clk - Rotate left through carry operand m
; *************************************************************************
GLOBAL _RL_IXd
_RL_IXd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __RLr BYTE [rsi], 23, 4

; * RR (IX+d) - DD CB d 1E - 23 Clk - Rotate right through carry operand m
; **************************************************************************
GLOBAL _RR_IXd
_RR_IXd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __RRr BYTE [rsi], 23, 4

; * SLA (IX+d) - DD CB d 26 - 23 Clk - Shift operand m left arithmetic
; **********************************************************************
GLOBAL _SLA_IXd
_SLA_IXd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __SLAm BYTE [rsi], 23, 4

; * SRA (IX+d) - DD CB d 2E - 23 Clk - Shift operand m right arithmetic
; ***********************************************************************
GLOBAL _SRA_IXd
_SRA_IXd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __SRAm BYTE [rsi], 23, 4

; * SRL (IX+d) - DD CB d 3E - 23 Clk - Shift operand m right logical
; ********************************************************************
GLOBAL _SRL_IXd
_SRL_IXd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIX]
        and esi, 0FFFFh
        call read_mem
        __SRLr BYTE [rsi], 23, 4

; * BIT b, (IX+d) - DD CB d (46,4E,56,5E,66,6E,76,7E) - 20 Clk - Test bit b of location (IX+d)
; **********************************************************************************************
GLOBAL _BIT0_IXD, _BIT1_IXD, _BIT2_IXD, _BIT3_IXD, _BIT4_IXD, _BIT5_IXD, _BIT6_IXD, _BIT7_IXD
_BIT0_IXD:__BITb_Id 1h, DWORD [rIX]
_BIT1_IXD:__BITb_Id 2h, DWORD [rIX]
_BIT2_IXD:__BITb_Id 4h, DWORD [rIX]
_BIT3_IXD:__BITb_Id 8h, DWORD [rIX]
_BIT4_IXD:__BITb_Id 10h, DWORD [rIX]
_BIT5_IXD:__BITb_Id 20h, DWORD [rIX]
_BIT6_IXD:__BITb_Id 40h, DWORD [rIX]
_BIT7_IXD:__BITb_Id 80h, DWORD [rIX]

; * RES b, (IX+d) - DD CB b (86,8E,96,9E,A6,AE,B6,B7) - 23 Clk - Reset bit b of location (IX+d)
; ***********************************************************************************************
GLOBAL _RES0_IXd, _RES1_IXd, _RES2_IXd, _RES3_IXd, _RES4_IXd, _RES5_IXd, _RES6_IXd, _RES7_IXd
_RES0_IXd:__RESb_Id 1h, DWORD [rIX]
_RES1_IXd:__RESb_Id 2h, DWORD [rIX]
_RES2_IXd:__RESb_Id 4h, DWORD [rIX]
_RES3_IXd:__RESb_Id 8h, DWORD [rIX]
_RES4_IXd:__RESb_Id 10h, DWORD [rIX]
_RES5_IXd:__RESb_Id 20h, DWORD [rIX]
_RES6_IXd:__RESb_Id 40h, DWORD [rIX]
_RES7_IXd:__RESb_Id 80h, DWORD [rIX]

; * SET b, (IX+d) - DD CB b (C6,CE,D6,DE,E6,EE,F6,FE) - 23 Clk - Set bit b of location (IX+d)
; *********************************************************************************************
GLOBAL _SET0_IXd, _SET1_IXd, _SET2_IXd, _SET3_IXd, _SET4_IXd, _SET5_IXd, _SET6_IXd, _SET7_IXd
_SET0_IXd:__SETb_Id 1h, DWORD [rIX]
_SET1_IXd:__SETb_Id 2h, DWORD [rIX]
_SET2_IXd:__SETb_Id 4h, DWORD [rIX]
_SET3_IXd:__SETb_Id 8h, DWORD [rIX]
_SET4_IXd:__SETb_Id 10h, DWORD [rIX]
_SET5_IXd:__SETb_Id 20h, DWORD [rIX]
_SET6_IXd:__SETb_Id 40h, DWORD [rIX]
_SET7_IXd:__SETb_Id 80h, DWORD [rIX]

; ***************************************************************************************
; * Prefix ED
; ***************************************************************************************

; * IN r, (C) - ED (40,48,50,58,60,68,78) - 12 Clk - Load the register r with input from device (C)
; ***************************************************************************************************
GLOBAL _INB_C, _INC_C, _IND_C, _INE_C, _INH_C, _INL_C, _INA_C
_INB_C: __INr_C BYTE [rB]
_INC_C: __INr_C BYTE [rC]
_IND_C: __INr_C BYTE [rD]
_INE_C: __INr_C BYTE [rE]
_INH_C: __INr_C BYTE [rH]
_INL_C: __INr_C BYTE [rL]
_INA_C: __INr_C BYTE [rAcc]

; * OUT (C), r - ED (41,49,51,59,61,69,79) - 12 Clk - Load output port (C) with register r
; ******************************************************************************************
GLOBAL _OUT_C_B, _OUT_C_C, _OUT_C_D, _OUT_C_E, _OUT_C_H, _OUT_C_L, _OUT_C_A
_OUT_C_B:__OUT_C_r BYTE [rB]
_OUT_C_C:__OUT_C_r BYTE [rC]
_OUT_C_D:__OUT_C_r BYTE [rD]
_OUT_C_E:__OUT_C_r BYTE [rE]
_OUT_C_H:__OUT_C_r BYTE [rH]
_OUT_C_L:__OUT_C_r BYTE [rL]
_OUT_C_A:__OUT_C_r BYTE [rAcc]

; * SBC HL, ss - ED (42,52,62,72) - 15 Clk - Subtract register pair ss from HL with carry
; *****************************************************************************************
GLOBAL _SBCHLBC, _SBCHLDE, _SBCHLHL, _SBCHLSP
_SBCHLBC:__SBCHLss BYTE [rC]
_SBCHLDE:__SBCHLss BYTE [rE]
_SBCHLHL:__SBCHLss BYTE [rL]
_SBCHLSP:__SBCHLss DWORD [rSPx]

; * LD (nn), dd - ED (43,53,63,73) - 20 Clk - Load location (nn) with register pair dd
; **************************************************************************************
GLOBAL _LD_N_BC, _LD_N_DE, _LD_NN_HL, _LD_N_SP
_LD_N_BC:__LD_nn_dd rC, ax
_LD_N_DE:__LD_nn_dd rE, ax
_LD_NN_HL:__LD_nn_dd rL, ax
_LD_N_SP:__LD_nn_dd rSPx, eax

; * NEG - ED 44 - 8 Clk - Negate accumulator (2's complement)
; *************************************************************
GLOBAL _NEG
_NEG:
        mov BYTE [Flag], 2
        neg BYTE [rAcc]
        lahf
        jno NEG0
        or BYTE [Flag], 4
NEG0:   and ah, 11010001b
        or BYTE [Flag], ah
        add DWORD [rPCx], 2
        add BYTE [TClock], 8
        jmp TLF

; * RETN - ED 45 - 14 Clk - Return from non-maskable interrupt
; **************************************************************
GLOBAL _RETN
_RETN:
        mov BYTE [NMI], 0
        mov al, BYTE [IFF2]
        mov BYTE [IFF1], al
        mov esi, DWORD [rSPx]
        add DWORD [rSPx], 2
        call read_mem
        movzx eax, WORD [rsi]
        mov DWORD [rPCx], eax
        add BYTE [TClock], 14
        jmp TLF

; * IM 0 - ED (46,56,5E) - 8 Clk - Set interrupt mode m
; *******************************************************
GLOBAL _IM0, _IM1, _IM2
_IM0:   __IM 0
_IM1:   __IM 1
_IM2:   __IM 2

; * LD I, A - ED 47 - 9 Clk - Load I with accumulator
; *****************************************************
GLOBAL _LDIA
_LDIA:
        mov al, BYTE [rAcc]
        mov BYTE [rI], al
        add DWORD [rPCx], 2
        add BYTE [TClock], 9
        jmp TLF

; * ADC HL, ss - ED (4A,5A,6A,7A) - 15 CLk - Add with carry register pair ss to HL
; **********************************************************************************
GLOBAL _ADCHLBC, _ADCHLDE, _ADCHLHL, _ADCHLSP
_ADCHLBC:__ADCHLss BYTE [rC]
_ADCHLDE:__ADCHLss BYTE [rE]
_ADCHLHL:__ADCHLss BYTE [rL]
_ADCHLSP:__ADCHLss DWORD [rSPx]

; * LD dd, (nn) - ED (4B,5B,6B,7B) - 20 Clk - Load register pair dd with location (nn)
; **************************************************************************************
GLOBAL _LDBC_N, _LDDE_N, _LDHL_N, _LDSP_N
_LDBC_N:__LDdd_n rC
_LDDE_N:__LDdd_n rE
_LDHL_N:__LDdd_n rL
_LDSP_N:__LDdd_n rSPx

; * RETI - ED 4D - 14 Clk - Return from interrupt
; *************************************************
GLOBAL _RETI
_RETI:
        cmp BYTE [NMI], 1
        je _RETN        ; Bug em Desert Strike (ele usa RETI ao invés de RETN)

        mov esi, DWORD [rSPx]
        add DWORD [rSPx], 2
        call read_mem
        movzx eax, WORD [rsi]
        mov DWORD [rPCx], eax
        add BYTE [TClock], 14
        jmp TLF

; * LD R, A - ED 4F - 9 Clk - Load R with accumulator
; *****************************************************
GLOBAL _LDRA
_LDRA:
        mov al, BYTE [rAcc]
        and al, 7Fh
        mov BYTE [rR], al
        add DWORD [rPCx], 2
        add BYTE [TClock], 9
        jmp TLF

; * LD A, I - ED 57 - 9 Clk - Load accumulator with I
; *****************************************************
GLOBAL _LDAI
_LDAI:
        and BYTE [Flag], 1
        mov al, BYTE [rI]
        or al, al
        lahf
        and ah, 11000000b
        or BYTE [Flag], ah
        test BYTE [IFF2], 1
        jz LDAI0
        or BYTE [Flag], 4
LDAI0:  mov BYTE [rAcc], al
        add DWORD [rPCx], 2
        add BYTE [TClock], 9
        jmp TLF

; * LD A, R - ED 5F - 9 Clk - Load accumulator with R
; *****************************************************
GLOBAL _LDAR
_LDAR:
        and BYTE [Flag], 1
        mov al, BYTE [rR]
        and al, 7Fh
        or al, al
        lahf
        and ah, 11000000b
        or BYTE [Flag], ah
        test BYTE [IFF2], 1
        jz LDAR0
        or BYTE [Flag], 4
LDAR0:  mov BYTE [rAcc], al
        add DWORD [rPCx], 2
        add BYTE [TClock], 9
        jmp TLF

; * RRD - ED 67 - 18 Clk - Rotate digit right and left between accumulator and (HL)
; ***********************************************************************************
GLOBAL _RRD
_RRD:
        and BYTE [Flag], 1
        movzx esi, WORD [rL]
        call read_mem
        mov bl, [rsi]
        and bl, 0Fh
        mov al, BYTE [rAcc]
        shl al, 4
        and BYTE [rAcc], 0F0h
        shr BYTE [rsi], 4
        or [rsi], al
        or BYTE [rAcc], bl
        lahf
        and ah, 11000100b
        and BYTE [Flag], ah
        add DWORD [rPCx], 2
        add BYTE [TClock], 18
        jmp TLF

; * RLD - ED 6F - 18 Clk - Rotate digit left and right between accumulator and (HL)
; ***********************************************************************************
GLOBAL _RLD
_RLD:
        and BYTE [Flag], 1
        movzx esi, WORD [rL]
        call read_mem
        mov bl, [rsi]
        shr bl, 4
        mov al, BYTE [rAcc]
        and al, 0Fh
        and BYTE [rAcc], 0F0h
        shl BYTE [rsi], 4
        or [rsi], al
        or BYTE [rAcc], bl
        lahf
        and ah, 11000100b
        and BYTE [Flag], ah
        add DWORD [rPCx], 2
        add BYTE [TClock], 18
        jmp TLF

; * LDI - ED A0 - 16 Clk - Load location (DE) with location (HL), incr DE,HL; decr BC
; *************************************************************************************
GLOBAL _LDI
_LDI:
        and BYTE [Flag], 11000001b
        movzx esi, WORD [rL]
        inc WORD [rL]
        call read_mem
        mov al, [rsi]
        movzx esi, WORD [rE]
        inc WORD [rE]
        call write_mem
        mov [rsi], al
        dec WORD [rC]
        jz LDI0
        or BYTE [Flag], 4
LDI0:   add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * CPI - ED A1 - 16 Clk - Compare location (HL) and acc., incr HL, decr BC
; ***************************************************************************
GLOBAL _CPI
_CPI:
        and BYTE [Flag], 1
        or BYTE [Flag], 2
        movzx esi, WORD [rL]
        inc WORD [rL]
        call read_mem
        mov al, [rsi]
        cmp BYTE [rAcc], al
        lahf
        and ah, 11010000b
        or BYTE [Flag], ah
        dec WORD [rC]
        jz CPI0
        or BYTE [Flag], 4
CPI0:   add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * INI - ED A2 - 16 Clk - (HL)=Input from port (C). HL=HL+1. B=B-1
; *******************************************************************
GLOBAL _INI
_INI:
        and BYTE [Flag], 1
        or BYTE [Flag], 2
        movzx edx, BYTE [rC]
        call QWORD [read_io+edx*8]
        movzx esi, WORD [rL]
        call write_mem
        mov [rsi], al
        inc WORD [rL]
        dec BYTE [rB]
        jnz INI0
        or BYTE [Flag], 40h
INI0:   add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * OUTI - ED A3 - 16 Clk - Load output port (C) with (HL), incr HL, decr B
; ***************************************************************************
GLOBAL _OUTI
_OUTI:
        movzx esi, WORD [rL]
        inc WORD [rL]
        call read_mem
        mov al, [rsi]
        movzx edx, BYTE [rC]
        call QWORD [write_io+edx*8]
        dec BYTE [rB]
        lahf
        and ah, 0C0h
        mov BYTE [Flag], ah
        add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * LDD - ED A8 - 16 Clk - Load location (DE) with location (HL), decr DE,HL,BC
; *******************************************************************************
GLOBAL _LDD
_LDD:
        and BYTE [Flag], 11000001b
        movzx esi, WORD [rL]
        dec WORD [rL]
        call read_mem
        mov al, [rsi]
        movzx esi, WORD [rE]
        dec WORD [rE]
        call write_mem
        mov [rsi], al
        dec WORD [rC]
        jz LDD0
        or BYTE [Flag], 4
LDD0:   add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * CPD - ED A9 - 16 Clk - Compare location (HL) and acc., decr HL, decr BC
; ***************************************************************************
GLOBAL _CPD
_CPD:
        and BYTE [Flag], 1
        or BYTE [Flag], 2
        movzx esi, WORD [rL]
        call read_mem
        mov al, [rsi]
        cmp BYTE [rAcc], al
        lahf
        and ah, 11010000b
        or BYTE [Flag], ah
        dec WORD [rL]
        dec WORD [rC]
        jz CPD0
        or BYTE [Flag], 4
CPD0:   add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * OUTD - ED AB - 16 Clk - Load output port (C) with (HL), decr HL, decr B
; ***************************************************************************
GLOBAL _OUTD
_OUTD:
        movzx esi, WORD [rL]
        dec WORD [rL]
        call read_mem
        mov al, [rsi]
        movzx edx, BYTE [rC]
        call QWORD [write_io+edx*8]
        dec BYTE [rB]
        lahf
        and ah, 0C0h
        or ah, 2
        mov BYTE [Flag], ah
        add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * LDIR - ED B0 - 16/21 Clk - Perform an LDI and repeat until BC=0
; *******************************************************************
GLOBAL _LDIR
_LDIR:
        and BYTE [Flag], 11000001b
        movzx esi, WORD [rL]
        inc WORD [rL]
        call read_mem
        mov al, [rsi]
        movzx esi, WORD [rE]
        inc WORD [rE]
        call write_mem
        mov [rsi], al
        dec WORD [rC]
        jz LDIR0
        add BYTE [TClock], 21
        jmp TLF
LDIR0:  add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * CPIR - ED B1 - 16/24 Clk - Perform a CPI and repeat until BC=0
; ******************************************************************
GLOBAL _CPIR
_CPIR:
        and BYTE [Flag], 1
        or BYTE [Flag], 2
        movzx esi, WORD [rL]
        inc WORD [rL]
        call read_mem
        mov al, [rsi]
        cmp BYTE [rAcc], al
        lahf
        and ah, 11010000b
        or BYTE [Flag], ah
        dec WORD [rC]
        jz CPIR0
        or BYTE [Flag], 4
        test ah, 40h
        jnz CPIR0
        add BYTE [TClock], 21
        jmp TLF
CPIR0:  add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * INIR - ED B2 - 16 Clk - (HL)=Input from port (C). HL=HL+1. B=B-1
; ********************************************************************
GLOBAL _INIR
_INIR:
        and BYTE [Flag], 1
        or BYTE [Flag], 42h
        movzx edx, BYTE [rC]
        call QWORD [read_io+edx*8]
        movzx esi, WORD [rL]
        inc WORD [rL]
        call write_mem
        mov [rsi], al
        dec BYTE [rB]
        jz INIR0
        add BYTE [TClock], 21
        jmp TLF
INIR0:  add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * OTIR - ED B3 - 16/21 Clk - Perform an OUTI and repeat until B=0
; *******************************************************************
GLOBAL _OTIR
_OTIR:
        and BYTE [Flag], 1
        or BYTE [Flag], 01000010b
        movzx esi, WORD [rL]
        inc WORD [rL]
        call read_mem
        mov al, [rsi]
        movzx edx, BYTE [rC]
        call QWORD [write_io+edx*8]
        dec BYTE [rB]
        jz OTIR0
        add BYTE [TClock], 21
        jmp TLF
OTIR0:  add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * LDDR - ED B8 - 21/16 Clk - Perform an LDD and repeat until BC=0
; *******************************************************************
GLOBAL _LDDR
_LDDR:
        and BYTE [Flag], 11000001b
        movzx esi, WORD [rL]
        dec WORD [rL]
        call read_mem
        mov al, [rsi]
        movzx esi, WORD [rE]
        dec WORD [rE]
        call write_mem
        mov [rsi], al
        dec WORD [rC]
        jz LDDR0
        add BYTE [TClock], 21
        jmp TLF
LDDR0:  add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * CPDR - ED B9 - 16/24 Clk - Perform a CPD and repeat until BC=0
; ******************************************************************
GLOBAL _CPDR
_CPDR:
        and BYTE [Flag], 1
        or BYTE [Flag], 2
        movzx esi, WORD [rL]
        dec WORD [rL]
        call read_mem
        mov al, [rsi]
        cmp BYTE [rAcc], al
        lahf
        and ah, 11010000b
        or BYTE [Flag], ah
        dec WORD [rC]
        jz CPDR0
        or BYTE [Flag], 4
        test ah, 40h
        jnz CPDR0
        add BYTE [TClock], 21
        jmp TLF
CPDR0:  add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF

; * OTDR - ED BB - 16/21 Clk - Perform an OUTD and repeat until B=0
; *******************************************************************
GLOBAL _OTDR
_OTDR:
        and BYTE [Flag], 1
        or BYTE [Flag], 01000010b
        movzx esi, WORD [rL]
        dec WORD [rL]
        call read_mem
        mov al, [rsi]
        movzx edx, BYTE [rC]
        call QWORD [write_io+edx*8]
        dec BYTE [rB]
        jz OTDR0
        add BYTE [TClock], 21
        jmp TLF
OTDR0:  add DWORD [rPCx], 2
        add BYTE [TClock], 16
        jmp TLF


; ***************************************************************************************
; * Prefix FD
; ***************************************************************************************

; * ADD IY, pp - FD (09, 19,29,39) - 15 Clk - Add register pair pp to IY
; ************************************************************************
GLOBAL _ADDIYBC, _ADDIYDE, _ADDIYIY, _ADDIYSP
_ADDIYBC:__ADDIpp rIY, rC
_ADDIYDE:__ADDIpp rIY, rE
_ADDIYIY:__ADDIpp rIY, rIY
_ADDIYSP:__ADDIpp rIY, rSPx

; * LD IY, nn - FD 21 - 14 Clk - Load IY with value nn
; ******************************************************
GLOBAL _LDIYN
_LDIYN:
        movzx eax, WORD [rsi+2]
        mov DWORD [rIY], eax
        add DWORD [rPCx], 4
        add BYTE [TClock], 14
        jmp TLF

; * LD (nn), IY - FD 22 n n - 20 Clk - Load location (nn) with IY
; *****************************************************************
GLOBAL _LD_N_IY
_LD_N_IY:
        mov eax, DWORD [rIY]
        movzx esi, WORD [rsi+2]
        call write_mem
        mov [rsi], ax
        add DWORD [rPCx], 4
        add BYTE [TClock], 20
        jmp TLF

; * INC IY - FD 23 - 10 Clk - Increment IY
; ******************************************
GLOBAL _INCIY
_INCIY:
        __INCI WORD [rIY]

; * INC IYH - FD 24 - 8 Clk - Incrementa parte do registrador de índice
; ***********************************************************************
GLOBAL _INCIYH
_INCIYH:
        inc DWORD [rPCx]
        __INCr BYTE [rIY+1], 8

; * DEC IYH - FD 25 - 8 Clk - Decrementa parte do registrador de índice
; ***********************************************************************
GLOBAL _DECIYH
_DECIYH:
        inc DWORD [rPCx]
        __DECr BYTE [rIY+1], 8

; * LD IYH, n - FD 26 n - 11 Clk - Carrega a parte high do registro de índice com um valor imediato
; ***************************************************************************************************
GLOBAL _LDIYHN
_LDIYHN:
        __LDIn BYTE [rIY+1]

; * LD IY, (nn) - FD 2A n n - 20 Clk - Load IY with location (nn)
; *****************************************************************
GLOBAL _LDIY_N
_LDIY_N:
        movzx esi, WORD [rsi+2]
        call read_mem
        mov ax, [rsi]
        mov WORD [rIY], ax
        add DWORD [rPCx], 4
        add BYTE [TClock], 20
        jmp TLF

; * DEC IY - FD 2B - 10 Clk - Decrement IY
; ******************************************
GLOBAL _DECIY
_DECIY:
        __DECI WORD [rIY]

; * INC IYL - FD 2C - 8 Clk - Incrementa parte do registrador de índice
; ***********************************************************************
GLOBAL _INCIYL
_INCIYL:
        inc DWORD [rPCx]
        __INCr BYTE [rIY], 8

; * DEC IYL - DD 2D - 8 Clk - Decrementa parte do registrador de índice
; ***********************************************************************
GLOBAL _DECIYL
_DECIYL:
        inc DWORD [rPCx]
        __DECr BYTE [rIY], 8

; * LD IYL, n - FD 2E n - 11 Clk - Carrega a parte low do registro de índice com um valor imediato
; **************************************************************************************************
GLOBAL _LDIYLN
_LDIYLN:
        __LDIn BYTE [rIY]

; * INC (IY+d) - FD 34 - 23 Clk - Increment operand s
; *****************************************************
GLOBAL _INC_IYd
_INC_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __INCr BYTE [rsi], 23

; * DEC (IY+d) - FD 35 - 23 Clk - Decrement operand s
; *****************************************************
GLOBAL _DEC_IYd
_DEC_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __DECr BYTE [rsi], 23

; * LD r, IYH - FD (44,4C,54,5C,7C) - Carrega registrador com a parte high do registro de índice
; ******************************************************************************************************
GLOBAL _LDB_IYH, _LDC_IYH, _LDD_IYH, _LDE_IYH, _LDA_IYH
_LDB_IYH:__LDIr BYTE [rB], BYTE [rIY+1]
_LDC_IYH:__LDIr BYTE [rC], BYTE [rIY+1]
_LDD_IYH:__LDIr BYTE [rD], BYTE [rIY+1]
_LDE_IYH:__LDIr BYTE [rE], BYTE [rIY+1]
_LDA_IYH:__LDIr BYTE [rAcc], BYTE [rIY+1]

; * LD r, IYL - FD (45,4D,55,5D,7D) - Carrega registrador com a parte low do registro de índice
; *****************************************************************************************************
GLOBAL _LDB_IYL, _LDC_IYL, _LDD_IYL, _LDE_IYL, _LDA_IYL
_LDB_IYL:__LDIr BYTE [rB], BYTE [rIY]
_LDC_IYL:__LDIr BYTE [rC], BYTE [rIY]
_LDD_IYL:__LDIr BYTE [rD], BYTE [rIY]
_LDE_IYL:__LDIr BYTE [rE], BYTE [rIY]
_LDA_IYL:__LDIr BYTE [rAcc], BYTE [rIY]

; * LD r, (IY+d) - FD (46,4E,56,5E,66,6E,7E) d - 19 Clk - Load register r with location (IY+d)
; **********************************************************************************************
GLOBAL _LDB_IYD, _LDC_IYD, _LDD_IYD, _LDE_IYD, _LDH_IYD, _LDL_IYD, _LDA_IYD
_LDB_IYD:__LDrId BYTE [rB], DWORD [rIY]
_LDC_IYD:__LDrId BYTE [rC], DWORD [rIY]
_LDD_IYD:__LDrId BYTE [rD], DWORD [rIY]
_LDE_IYD:__LDrId BYTE [rE], DWORD [rIY]
_LDH_IYD:__LDrId BYTE [rH], DWORD [rIY]
_LDL_IYD:__LDrId BYTE [rL], DWORD [rIY]
_LDA_IYD:__LDrId BYTE [rAcc], DWORD [rIY]

; * LD IYH, r - FD (60-67) - 8 Clk - Carrega a parte high do registro de índice
; *******************************************************************************
GLOBAL _LD_IYH_B, _LD_IYH_C, _LD_IYH_D, _LD_IYH_E, _LD_IYH_H, _LD_IYH_L, _LD_IYH_A
_LD_IYH_B:__LDIr BYTE [rIY+1], BYTE [rB]
_LD_IYH_C:__LDIr BYTE [rIY+1], BYTE [rC]
_LD_IYH_D:__LDIr BYTE [rIY+1], BYTE [rD]
_LD_IYH_E:__LDIr BYTE [rIY+1], BYTE [rE]
_LD_IYH_H:__LDIr BYTE [rIY+1], BYTE [rIY+1]
_LD_IYH_L:__LDIr BYTE [rIY+1], BYTE [rIY]
_LD_IYH_A:__LDIr BYTE [rIY+1], BYTE [rAcc]

; * LD IYL, r - FD (68-6F) - 8 Clk - Carrega a parte low do registro de índice
; ******************************************************************************
GLOBAL _LD_IYL_B, _LD_IYL_C, _LD_IYL_D, _LD_IYL_E, _LD_IYL_H, _LD_IYL_L, _LD_IYL_A
_LD_IYL_B:__LDIr BYTE [rIY], BYTE [rB]
_LD_IYL_C:__LDIr BYTE [rIY], BYTE [rC]
_LD_IYL_D:__LDIr BYTE [rIY], BYTE [rD]
_LD_IYL_E:__LDIr BYTE [rIY], BYTE [rE]
_LD_IYL_H:__LDIr BYTE [rIY], BYTE [rIY+1]
_LD_IYL_L:__LDIr BYTE [rIY], BYTE [rIY]
_LD_IYL_A:__LDIr BYTE [rIY], BYTE [rAcc]

; * LD (IY+d), r - FD (70-77,36) d - 19 Clk - Load location (IY+d) with register r
; **********************************************************************************
GLOBAL _LD_IYD_B, _LD_IYD_C, _LD_IYD_D, _LD_IYD_E, _LD_IYD_H, _LD_IYD_L, _LD_IYD_A, _LD_IYD_N
_LD_IYD_B:__LDIdr DWORD [rIY], BYTE [rB], 3
_LD_IYD_C:__LDIdr DWORD [rIY], BYTE [rC], 3
_LD_IYD_D:__LDIdr DWORD [rIY], BYTE [rD], 3
_LD_IYD_E:__LDIdr DWORD [rIY], BYTE [rE], 3
_LD_IYD_H:__LDIdr DWORD [rIY], BYTE [rH], 3
_LD_IYD_L:__LDIdr DWORD [rIY], BYTE [rL], 3
_LD_IYD_A:__LDIdr DWORD [rIY], BYTE [rAcc], 3
_LD_IYD_N:__LDIdr DWORD [rIY], [rsi+3], 4

; * ADD IYH - FD 84 - 8 Clk - Add IYH to accumulator
; ****************************************************
GLOBAL _ADDIYH
_ADDIYH:
        inc DWORD [rPCx]
        __ADDAs BYTE [rIY+1], 8

; * ADD IYL - FD 85 - 8 Clk - Add IYL to accumulator
; ****************************************************
GLOBAL _ADDIYL
_ADDIYL:
        inc DWORD [rPCx]
        __ADDAs BYTE [rIY], 8

; * ADD A, (IY+d) - FD 86 n - 16 Clk - Add location (IY+d) to accumulator
; *************************************************************************
GLOBAL _ADDA_IYd
_ADDA_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __ADDAs [rsi], 16

; * ADC A, (IY+d) - FD 8E - 19 Clk - Add operand s to accumulator with carry
; ****************************************************************************
GLOBAL _ADCA_IYd
_ADCA_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __ADCAs [rsi], 19

; * SUB IYH - FD 94 - 8 Clk - Subtract IYH from accumulator
; ***********************************************************
GLOBAL _SUBIYH
_SUBIYH:
        inc DWORD [rPCx]
        __SUBs BYTE [rIY+1], 8

; * SUB IYL - FD 95 - 8 Clk - Subtract IYL from accumulator
; ***********************************************************
GLOBAL _SUBIYL
_SUBIYL:
        inc DWORD [rPCx]
        __SUBs BYTE [rIY], 8

; * SUB (IY+d) - FD 96 d - 19 Clk - Subtract location (IY+d) from accumulator
; *****************************************************************************
GLOBAL _SUB_IYd
_SUB_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __SUBs [rsi], 19

; * SBC A, (IY+d) - FD 9E d - 19 Clk - Subtract location (IY+d) from accumulator with carry
; *******************************************************************************************
GLOBAL _SBCA_IYd
_SBCA_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __SBCAs [rsi], 19

; * AND IYH - FD A4 - 8 Clk - Logical AND of IYH to accumulator
; ***************************************************************
GLOBAL _ANDIYH
_ANDIYH:
        inc DWORD [rPCx]
        __ANDs BYTE [rIY+1], 8

; * AND IYL - FD A5 - 8 Clk - Logical AND of IYL to accumulator
; ***************************************************************
GLOBAL _ANDIYL
_ANDIYL:
        inc DWORD [rPCx]
        __ANDs BYTE [rIY], 8

; * AND (IY+d) - FD A6 n - 19 Clk - Logical AND of (IY+d) to accumulator
; ************************************************************************
GLOBAL _AND_IYd
_AND_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __ANDs [rsi], 19

; * XOR (IY+d) FD AE d - 19 Clk - Exclusive OR operand r and accumulator
; ************************************************************************
GLOBAL _XOR_IYd
_XOR_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __XORs [rsi], 19

; * OR IYH - FD B4 - 8 Clk - Logical OR of IYH and accumulator
; **************************************************************
GLOBAL _ORIYH
_ORIYH:
        inc DWORD [rPCx]
        __ORs BYTE [rIY+1], 8

; * OR IYL - FD B5 - 8 Clk - Logical OR of IYL and accumulator
; **************************************************************
GLOBAL _ORIYL
_ORIYL:
        inc DWORD [rPCx]
        __ORs BYTE [rIY], 8

; * OR (IY+d) - FD B6 d - 19 Clk - Logical OR of operand s and accumulator
; **************************************************************************
GLOBAL _OR_IYd
_OR_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __ORs [rsi], 19

; * CP IYH - FD BC - 8 Clk - Compare IYH with accumulator
; *********************************************************
GLOBAL _CPIYH
_CPIYH:
        inc DWORD [rPCx]
        __CPs BYTE [rIY+1], 8

; * CP IYL - FD BD - 8 Clk - Compare IYL with accumulator
; *********************************************************
GLOBAL _CPIYL
_CPIYL:
        inc DWORD [rPCx]
        __CPs BYTE [rIY], 8

; * CP (IY+d) - FD BE d - 19 Clk - Compare operand s with accumulator
; *********************************************************************
GLOBAL _CP_IYd
_CP_IYd:
        add DWORD [rPCx], 2
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __CPs [rsi], 19

; * Prefix FD CB
; ****************
GLOBAL _FDCB
_FDCB:
;       inc BYTE [rR]
        movzx edx, BYTE [rsi+3]
        jmp QWORD [OpcodeFDCB+edx*8]

; * POP IY - FD E1 - 14 Clk - Load IY with top of stack
; *******************************************************
GLOBAL _POPIY
_POPIY:
        mov esi, DWORD [rSPx]
        add DWORD [rSPx], 2
        call read_mem
        movzx eax, WORD [rsi]
        mov DWORD [rIY], eax
        add DWORD [rPCx], 2
        add BYTE [TClock], 14
        jmp TLF

; * EX (SP), IY - FD E3 - 23 Clk - Exchange the location (SP) and IY
; ********************************************************************
GLOBAL _EX_SP_IY
_EX_SP_IY:
        inc DWORD [rPCx]
        __EX_SP_r WORD [rIY], 23

; * PUSH IY - FD E5 - 15 Clk - Load IY onto stack
; *************************************************
GLOBAL _PUSHIY
_PUSHIY:
        mov eax, DWORD [rIY]
        sub DWORD [rSPx], 2
        mov esi, DWORD [rSPx]
        call write_mem
        mov [rsi], ax
        add DWORD [rPCx], 2
        add BYTE [TClock], 15
        jmp TLF

; * JP (IY) - FD E9 - 8 Clk - Unconditional jump to location (IY)
; *****************************************************************
GLOBAL _JP_IY
_JP_IY:
        mov eax, DWORD [rIY]
        mov DWORD [rPCx], eax
        add BYTE [TClock], 8
        jmp TLF

; * LD SP, IY - FD F9 - 10 Clk - Load SP with IY
; ************************************************
GLOBAL _LDSPIY
_LDSPIY:
        mov eax, DWORD [rIY]
        mov DWORD [rSPx], eax
        add DWORD [rPCx], 2
        add BYTE [TClock], 10
        jmp TLF


; ***************************************************************************************
; * Prefix FD CB
; ***************************************************************************************

; * RLC (IY+d) - FD CB d 06 - 23 Clk - Rotate operand r left circular
; *********************************************************************
GLOBAL _RLC_IYd
_RLC_IYd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __RLCr BYTE [rsi], 23, 4

; * RRC (IY+d) - FD CB d 0E - 23 Clk - Rotate operand r right circular
; **********************************************************************
GLOBAL _RRC_IYd
_RRC_IYd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __RRCr BYTE [rsi], 23, 4

; * RL (IY+d) - FD CB d 16 - 23 Clk - Rotate left through carry operand m
; *************************************************************************
GLOBAL _RL_IYd
_RL_IYd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __RLr BYTE [rsi], 23, 4

; * RR (IY+d) - FD CB d 1E - 23 Clk - Rotate right through carry operand m
; **************************************************************************
GLOBAL _RR_IYd
_RR_IYd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __RRr BYTE [rsi], 23, 4

; * SLA (IY+d) - FD CB d 26 - 23 Clk - Shift operand m left arithmetic
; **********************************************************************
GLOBAL _SLA_IYd
_SLA_IYd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __SLAm BYTE [rsi], 23, 4

; * SRA (IY+d) - FD CB d 2E - 23 Clk - Shift operand m right arithmetic
; ***********************************************************************
GLOBAL _SRA_IYd
_SRA_IYd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __SRAm BYTE [rsi], 23, 4

; * SRL (IY+d) - FD CB d 3E - 23 Clk - Shift operand m right logical
; ********************************************************************
GLOBAL _SRL_IYd
_SRL_IYd:
        movsx esi, BYTE [rsi+2]
        add esi, DWORD [rIY]
        and esi, 0FFFFh
        call read_mem
        __SRLr BYTE [rsi], 23, 4

; * BIT b, (IY+d) - FD CB d (46,4E,56,5E,66,6E,76,7E) - 20 Clk - Test bit b of location (IY+d)
; **********************************************************************************************
GLOBAL _BIT0_IYD, _BIT1_IYD, _BIT2_IYD, _BIT3_IYD, _BIT4_IYD, _BIT5_IYD, _BIT6_IYD, _BIT7_IYD
_BIT0_IYD:__BITb_Id 1h, DWORD [rIY]
_BIT1_IYD:__BITb_Id 2h, DWORD [rIY]
_BIT2_IYD:__BITb_Id 4h, DWORD [rIY]
_BIT3_IYD:__BITb_Id 8h, DWORD [rIY]
_BIT4_IYD:__BITb_Id 10h, DWORD [rIY]
_BIT5_IYD:__BITb_Id 20h, DWORD [rIY]
_BIT6_IYD:__BITb_Id 40h, DWORD [rIY]
_BIT7_IYD:__BITb_Id 80h, DWORD [rIY]

; * RES b, (IY+d) - FD CB b (86,8E,96,9E,A6,AE,B6,B7) - 23 Clk - Reset bit b of location (IY+d)
; ***********************************************************************************************
GLOBAL _RES0_IYd, _RES1_IYd, _RES2_IYd, _RES3_IYd, _RES4_IYd, _RES5_IYd, _RES6_IYd, _RES7_IYd
_RES0_IYd:__RESb_Id 1h, DWORD [rIY]
_RES1_IYd:__RESb_Id 2h, DWORD [rIY]
_RES2_IYd:__RESb_Id 4h, DWORD [rIY]
_RES3_IYd:__RESb_Id 8h, DWORD [rIY]
_RES4_IYd:__RESb_Id 10h, DWORD [rIY]
_RES5_IYd:__RESb_Id 20h, DWORD [rIY]
_RES6_IYd:__RESb_Id 40h, DWORD [rIY]
_RES7_IYd:__RESb_Id 80h, DWORD [rIY]

; * SET b, (IY+d) - DD CB b (C6,CE,D6,DE,E6,EE,F6,FE) - 23 Clk - Set bit b of location (IY+d)
; *********************************************************************************************
GLOBAL _SET0_IYd, _SET1_IYd, _SET2_IYd, _SET3_IYd, _SET4_IYd, _SET5_IYd, _SET6_IYd, _SET7_IYd
_SET0_IYd:__SETb_Id 1h, DWORD [rIY]
_SET1_IYd:__SETb_Id 2h, DWORD [rIY]
_SET2_IYd:__SETb_Id 4h, DWORD [rIY]
_SET3_IYd:__SETb_Id 8h, DWORD [rIY]
_SET4_IYd:__SETb_Id 10h, DWORD [rIY]
_SET5_IYd:__SETb_Id 20h, DWORD [rIY]
_SET6_IYd:__SETb_Id 40h, DWORD [rIY]
_SET7_IYd:__SETb_Id 80h, DWORD [rIY]


SECTION .data

; Opcode table
GLOBAL Opcode
Opcode:
    ;   0/8       1/9       2/A       3/B       4/C       5/D       6/E       7/F
    DQ _NOP,     _LDBCN,   _LD_BC_A, _INCBC,   _INCB,    _DECB,    _LDBN,    _RLCA
    DQ _EXAFAF,  _ADDHLBC, _LDA_BC,  _DECBC,   _INCC,    _DECC,    _LDCN,    _RRCA      ; 0
    DQ _DJNZ,    _LDDEN,   _LD_DE_A, _INCDE,   _INCD,    _DECD,    _LDDN,    _RLA
    DQ _JRE,     _ADDHLDE, _LDA_DE,  _DECDE,   _INCE,    _DECE,    _LDEN,    _RRA       ; 1
    DQ _JRNZE,   _LDHLN,   _LD_N_HL, _INCHL,   _INCH,    _DECH,    _LDHN,    _DAA
    DQ _JRZE,    _ADDHLHL, _LDHL_N2, _DECHL,   _INCL,    _DECL,    _LDLN,    __CPL      ; 2
    DQ _JRNCE,   _LDSPN,   _LD_N_A,  _INCSP,   _INC_HL,  _DEC_HL,  _LD_HL_N, _SCF
    DQ _JRCE,    _ADDHLSP, _LDA_N,   _DECSP,   _INCA,    _DECA,    _LDAN,    _CCF       ; 3
    DQ _LDBB,    _LDBC,    _LDBD,    _LDBE,    _LDBH,    _LDBL,    _LDB_HL,  _LDBA
    DQ _LDCB,    _LDCC,    _LDCD,    _LDCE,    _LDCH,    _LDCL,    _LDC_HL,  _LDCA      ; 4
    DQ _LDDB,    _LDDC,    _LDDD,    _LDDE,    _LDDH,    _LDDL,    _LDD_HL,  _LDDA
    DQ _LDEB,    _LDEC,    _LDED,    _LDEE,    _LDEH,    _LDEL,    _LDE_HL,  _LDEA      ; 5
    DQ _LDHB,    _LDHC,    _LDHD,    _LDHE,    _LDHH,    _LDHL,    _LDH_HL,  _LDHA
    DQ _LDLB,    _LDLC,    _LDLD,    _LDLE,    _LDLH,    _LDLL,    _LDL_HL,  _LDLA      ; 6
    DQ _LD_HL_B, _LD_HL_C, _LD_HL_D, _LD_HL_E, _LD_HL_H, _LD_HL_L, _HALT,    _LD_HL_A
    DQ _LDAB,    _LDAC,    _LDAD,    _LDAE,    _LDAH,    _LDAL,    _LDA_HL,  _LDAA      ; 7
    DQ _ADDAB,   _ADDAC,   _ADDAD,   _ADDAE,   _ADDAH,   _ADDAL,   _ADDA_HL, _ADDAA
    DQ _ADCAB,   _ADCAC,   _ADCAD,   _ADCAE,   _ADCAH,   _ADCAL,   _ADCA_HL, _ADCAA     ; 8
    DQ _SUBB,    _SUBC,    _SUBD,    _SUBE,    _SUBH,    _SUBL,    _SUB_HL,  _SUBA
    DQ _SBCAB,   _SBCAC,   _SBCAD,   _SBCAE,   _SBCAH,   _SBCAL,   _SBCA_HL, _SBCAA     ; 9
    DQ _ANDB,    _ANDC,    _ANDD,    _ANDE,    _ANDH,    _ANDL,    _AND_HL,  _ANDA
    DQ _XORB,    _XORC,    _XORD,    _XORE,    _XORH,    _XORL,    _XOR_HL,  _XORA      ; A
    DQ _ORB,     _ORC,     _ORD,     _ORE,     _ORH,     _ORL,     _OR_HL,   _ORA
    DQ _CPB,     _CPC,     _CPD2,    _CPE,     _CPH,     _CPL,     _CP_HL,   _CPA       ; B
    DQ _RETNZ,   _POPBC,   _JPNZN,   _JPN,     _CALLNZN, _PUSHBC,  _ADDAN,   _RST0
    DQ _RETZ,    _RET,     _JPZN,    _CB,      _CALLZN,  _CALLN,   _ADCAN,   _RST8      ; C
    DQ _RETNC,   _POPDE,   _JPNCN,   _OUTNA,   _CALLNCN, _PUSHDE,  _SUBN,    _RST10
    DQ _RETC,    _EXX,     _JPCN,    _INA_N,   _CALLCN,  _DD,      _SBCAN,   _RST18     ; D
    DQ _RETPO,   _POPHL,   _JPPON,   _EX_SP_HL,_CALLPON, _PUSHHL,  _ANDN,    _RST20
    DQ _RETPE,   _JP_HL,   _JPPEN,   _EXDEHL,  _CALLPEN, _ED,      _XORN,    _RST28     ; E
    DQ _RETP,    _POPAF,   _JPPN,    _DI,      _CALLPN,  _PUSHAF,  _ORN,     _RST30
    DQ _RETM,    _LDSPHL,  _JPMN,    _EI,      _CALLMN,  _FD,      _CPN,     _RST38     ; F

; Opcode table  (CB)
GLOBAL OpcodeCB
OpcodeCB:
    ;   0/8       1/9       2/A       3/B       4/C       5/D       6/E       7/F
    DQ _RLCB,    _RLCC,    _RLCD,    _RLCE,    _RLCH,    _RLCL,    _RLC_HL,  _RLCA2
    DQ _RRCB,    _RRCC,    _RRCD,    _RRCE,    _RRCH,    _RRCL,    _RRC_HL,  _RRCA2     ; 0
    DQ _RLB,     _RLC,     _RLD2,    _RLE,     _RLH,     _RLL,     _RL_HL,   _RLA2
    DQ _RRB,     _RRC,     _RRD2,    _RRE,     _RRH,     _RRL,     _RR_HL,   _RRA2      ; 1
    DQ _SLAB,    _SLAC,    _SLAD,    _SLAE,    _SLAH,    _SLAL,    _SLA_HL,  _SLAA
    DQ _SRAB,    _SRAC,    _SRAD,    _SRAE,    _SRAH,    _SRAL,    _SRA_HL,  _SRAA      ; 2
    DQ _SLLB,    _SLLC,    _SLLD,    _SLLE,    _SLLH,    _SLLL,    _SLL_HL,  _SLLA
    DQ _SRLB,    _SRLC,    _SRLD,    _SRLE,    _SRLH,    _SRLL,    _SRL_HL,  _SRLA      ; 3
    DQ _BIT0B,   _BIT0C,   _BIT0D,   _BIT0E,   _BIT0H,   _BIT0L,   _BIT0_HL, _BIT0A
    DQ _BIT1B,   _BIT1C,   _BIT1D,   _BIT1E,   _BIT1H,   _BIT1L,   _BIT1_HL, _BIT1A     ; 4
    DQ _BIT2B,   _BIT2C,   _BIT2D,   _BIT2E,   _BIT2H,   _BIT2L,   _BIT2_HL, _BIT2A
    DQ _BIT3B,   _BIT3C,   _BIT3D,   _BIT3E,   _BIT3H,   _BIT3L,   _BIT3_HL, _BIT3A     ; 5
    DQ _BIT4B,   _BIT4C,   _BIT4D,   _BIT4E,   _BIT4H,   _BIT4L,   _BIT4_HL, _BIT4A
    DQ _BIT5B,   _BIT5C,   _BIT5D,   _BIT5E,   _BIT5H,   _BIT5L,   _BIT5_HL, _BIT5A     ; 6
    DQ _BIT6B,   _BIT6C,   _BIT6D,   _BIT6E,   _BIT6H,   _BIT6L,   _BIT6_HL, _BIT6A
    DQ _BIT7B,   _BIT7C,   _BIT7D,   _BIT7E,   _BIT7H,   _BIT7L,   _BIT7_HL, _BIT7A     ; 7
    DQ _RES0B,   _RES0C,   _RES0D,   _RES0E,   _RES0H,   _RES0L,   _RES0_HL, _RES0A
    DQ _RES1B,   _RES1C,   _RES1D,   _RES1E,   _RES1H,   _RES1L,   _RES1_HL, _RES1A     ; 8
    DQ _RES2B,   _RES2C,   _RES2D,   _RES2E,   _RES2H,   _RES2L,   _RES2_HL, _RES2A
    DQ _RES3B,   _RES3C,   _RES3D,   _RES3E,   _RES3H,   _RES3L,   _RES3_HL, _RES3A     ; 9
    DQ _RES4B,   _RES4C,   _RES4D,   _RES4E,   _RES4H,   _RES4L,   _RES4_HL, _RES4A
    DQ _RES5B,   _RES5C,   _RES5D,   _RES5E,   _RES5H,   _RES5L,   _RES5_HL, _RES5A     ; A
    DQ _RES6B,   _RES6C,   _RES6D,   _RES6E,   _RES6H,   _RES6L,   _RES6_HL, _RES6A
    DQ _RES7B,   _RES7C,   _RES7D,   _RES7E,   _RES7H,   _RES7L,   _RES7_HL, _RES7A     ; B
    DQ _SET0B,   _SET0C,   _SET0D,   _SET0E,   _SET0H,   _SET0L,   _SET0_HL, _SET0A
    DQ _SET1B,   _SET1C,   _SET1D,   _SET1E,   _SET1H,   _SET1L,   _SET1_HL, _SET1A     ; C
    DQ _SET2B,   _SET2C,   _SET2D,   _SET2E,   _SET2H,   _SET2L,   _SET2_HL, _SET2A
    DQ _SET3B,   _SET3C,   _SET3D,   _SET3E,   _SET3H,   _SET3L,   _SET3_HL, _SET3A     ; D
    DQ _SET4B,   _SET4C,   _SET4D,   _SET4E,   _SET4H,   _SET4L,   _SET4_HL, _SET4A
    DQ _SET5B,   _SET5C,   _SET5D,   _SET5E,   _SET5H,   _SET5L,   _SET5_HL, _SET5A     ; E
    DQ _SET6B,   _SET6C,   _SET6D,   _SET6E,   _SET6H,   _SET6L,   _SET6_HL, _SET6A
    DQ _SET7B,   _SET7C,   _SET7D,   _SET7E,   _SET7H,   _SET7L,   _SET7_HL, _SET7A     ; F

; Opcode table (DD)
GLOBAL OpcodeDD
OpcodeDD:
    ;   0/8       1/9       2/A       3/B       4/C       5/D       6/E       7/F
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _ADDIXBC, _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; 0
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _ADDIXDE, _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; 1
    DQ _NOP,     _LDIXN,   _LD_N_IX, _INCIX,   _INCIXH,  _DECIXH,  _LDIXHN,  _NOP
    DQ _NOP,     _ADDIXIX, _LDIX_N,  _DECIX,   _INCIXL,  _DECIXL,  _LDIXLN,  _NOP       ; 2
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _INC_IXd, _DEC_IXd, _LD_IXD_N,_NOP
    DQ _NOP,     _ADDIXSP, _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; 3
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDB_IXH, _LDB_IXL, _LDB_IXD, _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDC_IXH, _LDC_IXL, _LDC_IXD, _NOP       ; 4
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDD_IXH, _LDD_IXL, _LDD_IXD, _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDE_IXH, _LDE_IXL, _LDE_IXD, _NOP       ; 5
    DQ _LD_IXH_B,_LD_IXH_C,_LD_IXH_D,_LD_IXH_E,_LD_IXH_H,_LD_IXH_L,_LDH_IXD, _LD_IXH_A
    DQ _LD_IXL_B,_LD_IXL_C,_LD_IXL_D,_LD_IXL_E,_LD_IXL_H,_LD_IXL_L,_LDL_IXD, _LD_IXL_A  ; 6
    DQ _LD_IXD_B,_LD_IXD_C,_LD_IXD_D,_LD_IXD_E,_LD_IXD_H,_LD_IXD_L,_NOP,     _LD_IXD_A
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDA_IXH, _LDA_IXL, _LDA_IXD, _NOP       ; 7
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _ADDIXH,  _ADDIXL,  _ADDA_IXd,_NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NIMP2,   _NIMP2,   _ADCA_IXd,_NOP       ; 8
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _SUBIXH,  _SUBIXL,  _SUB_IXd, _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NIMP2,   _NIMP2,   _SBCA_IXd,_NOP       ; 9
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _ANDIXH,  _ANDIXL,  _AND_IXd, _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NIMP2,   _NIMP2,   _XOR_IXd, _NOP       ; A
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _ORIXH,   _ORIXL,   _OR_IXd,  _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _CPIXH,   _CPIXL,   _CP_IXd,  _NOP       ; B
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _NOP,     _NOP,     _DDCB,    _NOP,     _NOP,     _NOP,     _NOP       ; C
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; D
    DQ _NOP,     _POPIX,   _NOP,     _EX_SP_IX,_NOP,     _PUSHIX,  _NOP,     _NOP
    DQ _NOP,     _JP_IX,   _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; E
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _LDSPIX,  _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; F

; Opcode table (DD CB)
GLOBAL OpcodeDDCB
OpcodeDDCB:
    ;   0/8       1/9       2/A       3/B       4/C       5/D       6/E       7/F
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RLC_IXd, _NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RRC_IXd, _NIMP3     ; 0
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RL_IXd,  _NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RR_IXd,  _NIMP3     ; 1
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SLA_IXd, _NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SRA_IXd, _NIMP3     ; 2
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SRL_IXd, _NIMP3     ; 3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT0_IXD,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT1_IXD,_NIMP3     ; 4
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT2_IXD,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT3_IXD,_NIMP3     ; 5
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT4_IXD,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT5_IXD,_NIMP3     ; 6
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT6_IXD,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT7_IXD,_NIMP3     ; 7
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES0_IXd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES1_IXd,_NIMP3     ; 8
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES2_IXd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES3_IXd,_NIMP3     ; 9
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES4_IXd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES5_IXd,_NIMP3     ; A
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES6_IXd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES7_IXd,_NIMP3     ; B
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET0_IXd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET1_IXd,_NIMP3     ; C
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET2_IXd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET3_IXd,_NIMP3     ; D
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET4_IXd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET5_IXd,_NIMP3     ; E
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET6_IXd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET7_IXd,_NIMP3     ; F

; Opcode table (ED)
GLOBAL OpcodeED
OpcodeED:
    ;   0/8       1/9       2/A       3/B       4/C       5/D       6/E       7/F
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; 0
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; 1
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; 2
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; 3
    DQ _INB_C,   _OUT_C_B, _SBCHLBC, _LD_N_BC, _NEG,     _RETN,    _IM0,     _LDIA
    DQ _INC_C,   _OUT_C_C, _ADCHLBC, _LDBC_N,  _NIMP2,   _RETI,    _NIMP2,   _LDRA      ; 4
    DQ _IND_C,   _OUT_C_D, _SBCHLDE, _LD_N_DE, _NIMP2,   _NIMP2,   _IM1,     _LDAI
    DQ _INE_C,   _OUT_C_E, _ADCHLDE, _LDDE_N,  _NIMP2,   _NIMP2,   _IM2,     _LDAR      ; 5
    DQ _INH_C,   _OUT_C_H, _SBCHLHL, _LD_NN_HL,_NIMP2,   _NIMP2,   _NIMP2,   _RRD
    DQ _INL_C,   _OUT_C_L, _ADCHLHL, _LDHL_N,  _NIMP2,   _NIMP2,   _NIMP2,   _RLD       ; 6
    DQ _NIMP2,   _NIMP2,   _SBCHLSP, _LD_N_SP, _NIMP2,   _NIMP2,   _NIMP2,   _NIMP2
    DQ _INA_C,   _OUT_C_A, _ADCHLSP, _LDSP_N,  _NIMP2,   _NIMP2,   _NIMP2,   _NOLIST    ; 7
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; 8
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; 9
    DQ _LDI,     _CPI,     _INI,     _OUTI,    _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _LDD,     _CPD,     _NIMP2,   _OUTD,    _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; A
    DQ _LDIR,    _CPIR,    _INIR,    _OTIR,    _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _LDDR,    _CPDR,    _NIMP2,   _OTDR,    _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; B
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; C
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; D
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; E
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST
    DQ _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST,  _NOLIST    ; F

; Opcode table (FD)
GLOBAL OpcodeFD
OpcodeFD:
    ;   0/8       1/9       2/A       3/B       4/C       5/D       6/E       7/F
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _ADDIYBC, _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; 0
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _ADDIYDE, _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; 1
    DQ _NOP,     _LDIYN,   _LD_N_IY, _INCIY,   _INCIYH,  _DECIYH,  _LDIYHN,  _NOP
    DQ _NOP,     _ADDIYIY, _LDIY_N,  _DECIY,   _INCIYL,  _DECIYL,  _LDIYLN,  _NOP       ; 2
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _INC_IYd, _DEC_IYd, _LD_IYD_N,_NOP
    DQ _NOP,     _ADDIYSP, _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; 3
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDB_IYH, _LDB_IYL, _LDB_IYD, _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDC_IYH, _LDC_IYL, _LDC_IYD, _NOP       ; 4
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDD_IYH, _LDD_IYL, _LDD_IYD, _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDE_IYH, _LDE_IYL, _LDE_IYD, _NOP       ; 5
    DQ _LD_IYH_B,_LD_IYH_C,_LD_IYH_D,_LD_IYH_E,_LD_IYH_H,_LD_IYH_L,_LDH_IYD, _LD_IYH_A
    DQ _LD_IYL_B,_LD_IYL_C,_LD_IYL_D,_LD_IYL_E,_LD_IYL_H,_LD_IYL_L,_LDL_IYD, _LD_IYL_A  ; 6
    DQ _LD_IYD_B,_LD_IYD_C,_LD_IYD_D,_LD_IYD_E,_LD_IYD_H,_LD_IYD_L,_NIMP2,   _LD_IYD_A
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _LDA_IYH, _LDA_IYL, _LDA_IYD, _NOP       ; 7
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _ADDIYH,  _ADDIYL,  _ADDA_IYd,_NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NIMP2,   _NIMP2,   _ADCA_IYd,_NOP       ; 8
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _SUBIYH,  _SUBIYL,  _SUB_IYd, _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NIMP2,   _NIMP2,   _SBCA_IYd,_NOP       ; 9
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _ANDIYH,  _ANDIYL,  _AND_IYd, _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NIMP2,   _NIMP2,   _XOR_IYd, _NOP       ; A
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _ORIYH,   _ORIYL,   _OR_IYd,  _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _CPIYH,   _CPIYL,   _CP_IYd,  _NOP       ; B
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _NOP,     _NOP,     _FDCB,    _NOP,     _NOP,     _NOP,     _NOP       ; C
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; D
    DQ _NOP,     _POPIY,   _NOP,     _EX_SP_IY,_NOP,     _PUSHIY,  _NOP,     _NOP
    DQ _NOP,     _JP_IY,   _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; E
    DQ _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP
    DQ _NOP,     _LDSPIY,  _NOP,     _NOP,     _NOP,     _NOP,     _NOP,     _NOP       ; F

; Opcode table (FD CB)
GLOBAL OpcodeFDCB
OpcodeFDCB:
    ;   0/8       1/9       2/A       3/B       4/C       5/D       6/E       7/F
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RLC_IYd, _NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RRC_IYd, _NIMP3     ; 0
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RL_IYd,  _NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RR_IYd,  _NIMP3     ; 1
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SLA_IYd, _NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SRA_IYd, _NIMP3     ; 2
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SRL_IYd, _NIMP3     ; 3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT0_IYD,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT1_IYD,_NIMP3     ; 4
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT2_IYD,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT3_IYD,_NIMP3     ; 5
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT4_IYD,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT5_IYD,_NIMP3     ; 6
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT6_IYD,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _BIT7_IYD,_NIMP3     ; 7
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES0_IYd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES1_IYd,_NIMP3     ; 8
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES2_IYd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES3_IYd,_NIMP3     ; 9
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES4_IYd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES5_IYd,_NIMP3     ; A
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES6_IYd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _RES7_IYd,_NIMP3     ; B
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET0_IYd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET1_IYd,_NIMP3     ; C
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET2_IYd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET3_IYd,_NIMP3     ; D
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET4_IYd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET5_IYd,_NIMP3     ; E
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET6_IYd,_NIMP3
    DQ _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _NIMP3,   _SET7_IYd,_NIMP3     ; F
