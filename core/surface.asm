; Alis, A SEGA Master System emulator
; Copyright (C) 2002-2013 Cidorvan Leite

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


%INCLUDE "vdp.inc"

SECTION .text

GLOBAL write_frame
write_frame:
        push ebx
        push esi
        push edi

        test BYTE [VDPR], 020h
        jz NR

        mov esi, VideoBuffer + 32
        mov edi, VideoBuffer
        mov dh, 192
NL:     mov dl, 8
NB:     mov ecx, 32
        rep movsd
        mov eax, [edi-8]
        mov [edi-4], eax
        sub esi, 4
        dec dl
        jnz NB
        add esi, 32
        dec dh
        jnz NL

NR:     mov esi, VideoBuffer
        mov edi, [esp+16]       ; First parameter (surface)

        mov al, BYTE [esp+20]   ; Second parameter (bpp)
        cmp al, 32
        je bpp32
        cmp al, 24
        je bpp24
        cmp al, 16
        je bpp16
        cmp al, 15
        je bpp15
        jmp bppdone

        ; 15 bits
bpp15:  mov ecx, 256 * 192
bpp150: lodsd
        mov ebx, eax
        mov edx, eax
        shr eax, 3
        and eax, 01Fh
        shr ebx, 6
        and ebx, 03E0h
        or eax, ebx
        shr edx, 9
        and edx, 07C00h
        or eax, edx
        stosw
        dec ecx
        jnz bpp150
        jmp bppdone

        ; 16 bits
bpp16:  mov ecx, 256 * 192
bpp160: lodsd
        mov ebx, eax
        mov edx, eax
        shr eax, 3
        and eax, 01Fh
        shr ebx, 5
        and ebx, 07E0h
        or eax, ebx
        shr edx, 8
        and edx, 0F800h
        or eax, edx
        stosw
        dec ecx
        jnz bpp160
        jmp bppdone

        ; 24 bits
bpp24:  mov ecx, 256 * 192
bpp240: lodsd
        mov [edi], eax
        add edi, 3
        dec ecx
        jnz bpp240
        jmp bppdone

        ; 32 bits
bpp32:  mov ecx, 256 * 192
        rep movsd

bppdone:pop edi
        pop esi
        pop ebx
        ret
