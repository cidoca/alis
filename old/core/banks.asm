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


%INCLUDE "data.inc"

SECTION .text

; * Initialize banks pointers
; *****************************
GLOBAL init_banks
init_banks:
        mov [ROM_size], dil     ; First Parameter (ROM_size rdi)

        ; Clear RAM
        xor rax, rax
        mov ecx, (40 * 1024) / 8
        mov rdi, RAM
        rep stosq

        ; Initialize banks pointers and page registers
        mov [battery], al
        mov rax, [ROM]
        mov [pBank0], rax
        mov [pBank1], rax
        mov [pBank2], rax
        mov [pBank2ROM], rax
        mov DWORD [BankRegs], 002010000h

        ret

; * Read memory
; ***************
GLOBAL read_mem
read_mem:
        ; Which bank?
        cmp esi, 00400h
        jb RM0
        cmp esi, 04000h
        jb RM1
        cmp esi, 08000h
        jb RM2
        cmp esi, 0C000h
        jb RM3

        ; Read RAM or page register?
        cmp esi, 0FFFCh
        jae RM00

        ; Read from RAM
        and esi, 0DFFFh
        add rsi, RAM - 0C000h
        ret

        ; Read from page register
RM00:   add esi, BankRegs - 0FFFCh
        ret

        ; Select the right bank
RM0:    add rsi, [ROM]
        ret
RM1:    add rsi, [pBank0]
        ret
RM2:    add rsi, [pBank1]
        ret
RM3:    add rsi, [pBank2]
        ret

; * Write memory
; ****************
GLOBAL write_mem
write_mem:
        ; Which bank?
        cmp esi, 08000h
        jb WM7
        cmp esi, 0C000h
        jb WM8

        ; Write in page registers?
        cmp esi, 0FFFCh
        jae WM1

        ; Write in RAM
WM0:    and esi, 0DFFFh
        add rsi, RAM - 0C000h
        ret

        ; Write in banks registers
WM00:   mov [BankRegs+esi-0FFFCh], al
        jmp WM0

        ; Select
WM1:    cmp esi, 0FFFCh
        jne WM4
        test al, 8
        jnz WM11
        mov rbx, [pBank2ROM]
        mov [pBank2], rbx
        jmp WM00

        ; Initialize battery
WM11:   mov BYTE [battery], 1

        ; Select battery bank
WM2:    test al, 4
        jnz WM3
        mov QWORD [pBank2], RAM_EX - 08000h
        jmp WM00
WM3:    mov QWORD [pBank2], RAM_EX - 04000h
        jmp WM00

        ; Select ROM page
WM4:    mov ebx, eax
        mov ah, 0
        div BYTE [ROM_size]
        movzx eax, ah
        shl eax, 14
        add rax, [ROM]

        ; Bank 0
        cmp esi, 0FFFDh
        jne WM5
        mov [pBank0], rax
        mov eax, ebx
        jmp WM00

        ; Bank 1
WM5:    cmp esi, 0FFFEh
        jne WM6
        sub rax, 04000h
        mov [pBank1], rax
        mov eax, ebx
        jmp WM00

        ; Bank 2
WM6:    sub rax, 08000h
        mov [pBank2ROM], rax
        test BYTE [BankRegs], 8
        jnz WM66
        mov [pBank2], rax   ; cmov???
WM66:   mov eax, ebx
        jmp WM00

        ; Write in selected bank
WM7:    mov rsi, garbage
        ret
WM8:    test BYTE [BankRegs], 8
        jz WM7
        add rsi, [pBank2]
        ret


SECTION .bss

GLOBAL ROM, garbage, ROM_size
ROM         RESQ 1
garbage     RESD 1
ROM_size    RESB 1
