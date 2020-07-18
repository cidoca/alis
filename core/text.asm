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

WIDTH 	EQU 7
HEIGHT	EQU 7

SECTION .text

GLOBAL draw_text
draw_text:
        shl rdx, 8
        add rdx, rsi
        shl rdx, 2
        add rdi, rdx

DT0:    movzx eax, BYTE [rcx]
        inc rcx
        test al, al
        jz DT9

        cmp al, ' '
        jne DT1
        add rdi, WIDTH * 4
        jmp DT0

DT1:    cmp al, 'A'
        jb DT2
        mov rsi, FontAlpha
        sub al, 'A'
        jmp DT4

DT2:    cmp al, '0'
        jb DT3
        mov rsi, FontNum
        sub al, '0'
        jmp DT4

DT3:    mov rsi, FontX
        jmp DT5

DT4:    shl eax, 3
        add rsi, rax

DT5:    mov dh, HEIGHT
DT6:    mov dl, WIDTH
        mov al, [rsi]
DT7:    test al, 080h
        jz DT8
        mov [rdi], r8d
DT8:    add rdi, 4
        shl al, 1
        dec dl
        jnz DT7
        inc rsi
        add rdi, (256 - WIDTH) * 4
        dec dh
        jnz DT6

        sub rdi, (256 * HEIGHT - WIDTH) * 4
        jmp DT0

DT9:    ret


SECTION .data

FontNum     DQ 0007088C8A8988870h, 00070202020206020h, 000F8804030088870h, 000708808301008F8h ; 0 1 2 3
            DQ 0001010F890503010h, 00070880808F080F8h, 000708888F0804038h, 000404040201008F8h ; 4 5 6 7
            DQ 00070888870888870h, 000E0100878888870h                                         ; 8 9
FontAlpha   DQ 0008888F888885020h, 000F08888F08888F0h, 00070888080808870h, 000F08888888888F0h ; A B C D
            DQ 000F88080F08080F8h, 000808080F08080F8h, 00078889880808078h, 000888888F8888888h ; E F G H
            DQ 00070202020202070h, 00070880808080808h, 0008890A0C0A09088h, 000F8808080808080h ; I J K L
            DQ 000888888A8A8D888h, 000888898A8C88888h, 00070888888888870h, 000808080F08888F0h ; M N O P
            DQ 0006890A888888870h, 0008890A0F08888F0h, 00070880870808870h, 000202020202020F8h ; Q R S T
            DQ 00070888888888888h, 00020508888888888h, 00088D8A8A8888888h, 00088885020508888h ; U V W X
            DQ 00020202020508888h, 000F88040201008F8h                                         ; Y Z
FontX       DQ 0001898402010C8C0h                                                             ; %
