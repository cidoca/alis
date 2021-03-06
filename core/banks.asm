; Alis, A SEGA Master System emulator
; Copyright (C) 2002-2014 Cidorvan Leite

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


EXTERN init_battery
%INCLUDE "data.inc"

SECTION .text

; * Initialize banks pointers
; *****************************
GLOBAL init_banks
init_banks:
        push edi

        ; Clear RAM
        xor eax, eax
        mov BYTE [battery], al
        mov ecx, (40*1024)/4
        mov edi, RAM
        rep stosd

        ; Initialize banks pointers and page registers
        mov BYTE [RAMSelect], al
        mov eax, DWORD [ROM]
        mov DWORD [pBank0], eax
        mov DWORD [pBank1], eax
        mov DWORD [pBank2], eax
        mov DWORD [pBank2ROM], eax
        mov BYTE [RAM+1FFEh], 1
        mov BYTE [RAM+1FFFh], 2

        mov eax, [esp+8]        ; First Parameter (ROM_size)
        mov [ROM_size], al

        pop edi
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

        ; Read RAM or page register
        and esi, 0DFFFh
        add esi, RAM - 0C000h
        ret

        ; Select the right bank
RM0:    add esi, DWORD [ROM]
        ret
RM1:    add esi, DWORD [pBank0]
        ret
RM2:    add esi, DWORD [pBank1]
        ret
RM3:    add esi, DWORD [pBank2]
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
        add esi, RAM - 0C000h
        ret

        ; Select
WM1:    cmp esi, 0FFFCh
        jne WM4
        mov BYTE [RAMSelect], al
        test al, 8
        jnz WM11
        mov ebx, DWORD [pBank2ROM]
        mov DWORD [pBank2], ebx
        jmp WM0

        ; Initialize battery
WM11:   cmp BYTE [battery], 0
        jne WM2
        push eax
        call init_battery
        pop eax
        mov BYTE [battery], 1

        ; Select battery bank
WM2:    test al, 4
        jnz WM3
        mov DWORD [pBank2], RAM_EX - 08000h
        jmp WM0
WM3:    mov DWORD [pBank2], RAM_EX - 04000h
        jmp WM0

        ; Select ROM page
WM4:    mov ebx, eax
        mov ah, 0
        div BYTE [ROM_size]
        movzx eax, ah
        shl eax, 14
        add eax, DWORD [ROM]

        ; Bank 0
        cmp esi, 0FFFDh
        jne WM5
        mov DWORD [pBank0], eax
        mov eax, ebx
        jmp WM0

        ; Bank 1
WM5:    cmp esi, 0FFFEh
        jne WM6
        sub eax, 04000h
        mov DWORD [pBank1], eax
        mov eax, ebx
        jmp WM0

        ; Bank 2
WM6:    sub eax, 08000h
        mov DWORD [pBank2ROM], eax
        test BYTE [RAMSelect], 8
        jnz WM66
        mov DWORD [pBank2], eax
WM66:   mov eax, ebx
        jmp WM0

        ; Write in selected bank
WM7:    mov esi, garbage
        ret
WM8:    test BYTE [RAMSelect], 8
        jz WM7
        add esi, DWORD [pBank2]
        ret


SECTION .bss

GLOBAL garbage, ROM_size, ROM
garbage     RESW 1
ROM_size    RESB 1
ROM         RESD 1
