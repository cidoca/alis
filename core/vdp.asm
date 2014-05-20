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


%INCLUDE "data.inc"
%INCLUDE "cpu.inc"
%INCLUDE "io.inc"

SECTION .text

; * Reset VDP
; *************
GLOBAL reset_VDP
reset_VDP:
        push edi

        ; Initialize VDP controls
        xor eax, eax
        mov BYTE [cVDP], al
        mov BYTE [VDPLow], al
        mov BYTE [VDPStatus], al
        mov BYTE [LineInt], al

        ; Clear registers, palette and video memory
        mov ecx, (4+16+32+4000h)/4
        mov edi, pRAM
        rep stosd

        pop edi
        ret

; * Render a frame
; ******************
GLOBAL scan_frame
scan_frame:
        push ebx
        push esi
        push edi
        push ebp

        ; Clear buffer
        xor eax, eax
        mov ecx, 256 * 192
        mov edi, [esp+20]       ; Param buffer
        rep stosd

        ; Start a new frame
        mov DWORD [ScanLine], 0
        mov al, BYTE [VDPR+10]  ; Line Counter
        cmp al, 192
        jne SF00
        dec al
SF00:   mov BYTE [VDPCounter], al

        ; Executes each scanline
SF0:    call TraceLine

        ; Renders last scanline
        cmp DWORD [ScanLine], 192
        jae SF1
        test BYTE [VDPR+1], 40h
        jz SF1
        call render_background_layer
        call render_sprite_layer
        cmp BYTE [RenderBL2], 0
        je SF1
        call render_background_layer2

        ; Lines 0-192
SF1:    cmp DWORD [ScanLine], 192
        ja SF5

        ; Frame Interrupt on line 192
        jne SF2
        or BYTE [VDPStatus], 80h    ; Frame Interrupt pendente

        ; Checks Line Interrupt
SF2:    cmp BYTE [VDPCounter], 0
        jne SF3
        mov al, BYTE [VDPR+10]      ; Line Counter
        mov BYTE [VDPCounter], al
        mov BYTE [LineInt], 1       ; Line Interrupt pending
        jmp SF4

SF3:    dec BYTE [VDPCounter]

        ; Trigger Line Interruption
        cmp BYTE [LineInt], 0
        je SF6
SF4:    test BYTE [VDPR+0], 10h     ; Line Interrupt
        jz SF6
        call int_Z80
        jmp SF6

        ; Lines 193-261
SF5:    mov al, BYTE [VDPR+10]      ; Line Counter
        mov BYTE [VDPCounter], al

        cmp DWORD [ScanLine], 224
        jae SF6
        test BYTE [VDPStatus], 80h  ; Frame Interrupt pendente
        jz SF6
        test BYTE [VDPR+1], 20h     ; Frame Interrupt
        jz SF6
        call int_Z80

SF6:    sub BYTE [TClock], 228
        inc DWORD [ScanLine]
        cmp DWORD [ScanLine], 262
        jb SF0

        pop ebp
        pop edi
        pop esi
        pop ebx
        ret

; * Render one line
; *******************
render_background_layer:
        mov BYTE [RenderBL2], 0

        movzx eax, BYTE [VDPR+9]
        add eax, DWORD [ScanLine]
        cmp eax, 224
        jb RL000
        sub eax, 224

RL000:  shr eax, 3
        shl eax, 6
        mov esi, VRAM
        add esi, eax
        movzx eax, BYTE [VDPR+2]
        shl eax, 10
        and eax, 3800h
        add esi, eax

        mov eax, DWORD [ScanLine]
        shl eax, 10
        mov edi, [esp+24]           ; Param buffer (after one call instruction)
        add edi, eax

        mov DWORD [scrollx], 0

        ; Hide first two lines
        test BYTE [VDPR+0], 40h
        jz RL00
        cmp DWORD [ScanLine], 16
        jb RL01

RL00:   movzx eax, BYTE [VDPR+8]
        shl eax, 2
        mov DWORD [scrollx], eax

RL01:   movzx ebx, BYTE [VDPR+9]
        add ebx, DWORD [ScanLine]
        and ebx, 7
        shl ebx, 2

        mov ch, 32
RL_0:   movzx edx, WORD [esi]
        add esi, 2

        ; Sprite palette?
        mov DWORD [pal], edx
        and DWORD [pal], 0800h
        shr DWORD [pal], 7

RL_00:  test BYTE [esi-1], 10h      ; Tile in front layer (renders after)
        jz RL11
        mov BYTE [RenderBL2], 1
        mov eax, DWORD [pal]
        mov al, BYTE [CRAM+eax]
        and al, 3Fh
        mov eax, [palette+eax*4]
        mov edx, DWORD [scrollx]
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov DWORD [scrollx], edx
        dec ch
        jnz RL_0
        ret

RL11:   and edx, 1FFh
        shl edx, 5
        mov eax, ebx
        test BYTE [esi-1], 4h       ; Flip Vertical
        jz RL12
        mov eax, 28
        sub eax, ebx

RL12:   mov ebp, DWORD [VRAM+edx+eax]
        test BYTE [esi-1], 2h       ; Flip Horizontal
        jnz RL22

        mov cl, 8
RL1:    mov eax, ebp
        shl ebp, 1
        and eax, 80808080h
        shr eax, 7
        mov edx, eax
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        and eax, 0Fh
        mov edx, DWORD [pal]
        mov al, BYTE [CRAM+eax+edx]
        and al, 3Fh
        mov eax, [palette+eax*4]
        mov edx, DWORD [scrollx]
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov DWORD [scrollx], edx
        dec cl
        jnz RL1
        dec ch
        jnz RL_0
        ret

RL22:   mov cl, 8
RL3:    mov eax, ebp
        shr ebp, 1
        and eax, 01010101h
        mov edx, eax
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        and eax, 0Fh
        mov edx, DWORD [pal]
        mov al, BYTE [CRAM+eax+edx]
        and al, 3Fh
        mov eax, [palette+eax*4]
        mov edx, DWORD [scrollx]
        mov [edi+edx], eax
        add edx, 4
        and edx, 3FFh
        mov DWORD [scrollx], edx
        dec cl
        jnz RL3
        dec ch
        jnz RL_0
        ret

; * Render one line in front layer
; **********************************
render_background_layer2:
        movzx eax, BYTE [VDPR+9]
        add eax, DWORD [ScanLine]
        cmp eax, 224
        jb RBL000
        sub eax, 224

RBL000: shr eax, 3
        shl eax, 6
        mov esi, VRAM
        add esi, eax
        movzx eax, BYTE [VDPR+2]
        shl eax, 10
        and eax, 3800h
        add esi, eax

        mov eax, DWORD [ScanLine]
        shl eax, 10
        mov edi, [esp+24]               ; Param buffer (after one call instruction)
        add edi, eax

        mov DWORD [scrollx], 0

        ; Hide first two lines
        test BYTE [VDPR+0], 40h
        jz RBL00
        cmp DWORD [ScanLine], 16
        jb RBL01

RBL00:  movzx eax, BYTE [VDPR+8]
        shl eax, 2
        mov DWORD [scrollx], eax

RBL01:  movzx ebx, BYTE [VDPR+9]
        add ebx, DWORD [ScanLine]
        and ebx, 7
        shl ebx, 2

        mov ch, 32
RBL_0:  movzx edx, WORD [esi]
        add esi, 2

        test BYTE [esi-1], 10h          ; Tile in front layer (renders now)
        jnz RBL_00
        add DWORD [scrollx], 8*4
        and DWORD [scrollx], 3FFh
        dec ch
        jnz RBL_0
        ret

RBL_00: and edx, 1FFh
        shl edx, 5
        mov eax, ebx
        test BYTE [esi-1], 4h           ; Flip Vertical
        jz RBL11
        mov eax, 28
        sub eax, ebx
RBL11:  mov DWORD [pal], 0
        test BYTE [esi-1], 8h           ; Sprite palette
        jz RBL12
        mov DWORD [pal], 16
RBL12:  mov ebp, DWORD [VRAM+edx+eax]
        test BYTE [esi-1], 2h           ; Flip Horizontal
        jnz RBL22

        mov cl, 8
RBL1:   mov eax, ebp
        shl ebp, 1
        and eax, 80808080h
        shr eax, 7
        mov edx, eax
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        and eax, 0Fh
        jnz RBL13
        mov edx, DWORD [scrollx]
        jmp RBL14
RBL13:  mov edx, DWORD [pal]
        mov al, BYTE [CRAM+eax+edx]
        and al, 3Fh
        mov eax, [palette+eax*4]
        mov edx, DWORD [scrollx]
        mov [edi+edx], eax
RBL14:  add edx, 4
        and edx, 3FFh
        mov DWORD [scrollx], edx
        dec cl
        jnz RBL1
        dec ch
        jnz RBL_0
        ret

RBL22:  mov cl, 8
RBL3:   mov eax, ebp
        shr ebp, 1
        and eax, 01010101h
        mov edx, eax
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        and eax, 0Fh
        jnz RBL4
        mov edx, DWORD [scrollx]
        jmp RBL5
RBL4:   mov edx, DWORD [pal]
        mov al, BYTE [CRAM+eax+edx]
        and al, 3Fh
        mov eax, [palette+eax*4]
        mov edx, DWORD [scrollx]
        mov [edi+edx], eax
RBL5:   add edx, 4
        and edx, 3FFh
        mov DWORD [scrollx], edx
        dec cl
        jnz RBL3
        dec ch
        jnz RBL_0
        ret

; * Render one sprite line
; **************************
render_sprite_layer:
        xor ecx, ecx
        mov esi, VRAM + 3F00h
RSLX0:  cmp BYTE [esi+ecx], 0D0h
        je RSLX1
        inc cl
        cmp cl, 64
        jb RSLX0
        jmp RSLX2
RSLX1:  cmp cl, 0
        je RSL2
RSLX2:  dec cl

        mov BYTE [s8x], 8
        test BYTE [VDPR+1], 2
        jz RSL00
        mov BYTE [s8x], 16

RSL00:  mov DWORD [sb], 0
        test BYTE [VDPR+6], 4
        jz RSL01
        mov DWORD [sb], 2000h

RSL01:  mov eax, DWORD [ScanLine]
        shl eax, 10
        mov edi, [esp+24]               ; Param buffer (after one call instruction)
        add edi, eax
        mov DWORD [vb], edi

        mov eax, DWORD [ScanLine]
        dec eax
        mov BYTE [sl], al

RSL0:   mov al, BYTE [sl]
        mov ah, [esi+ecx]
        sub al, ah
        cmp al, BYTE [s8x]
        jae RSL1

        movzx ebx, al
        shl ebx, 2

        movzx edi, BYTE [esi+ecx*2+128]
        test BYTE [VDPR+0], 8
        jz RSL02
        sub edi, 8
        and edi, 0FFh
RSL02:  shl edi, 2
        add edi, DWORD [vb]
        movzx eax, BYTE [esi+ecx*2+129]
        shl eax, 5
        add eax, DWORD [sb]
        mov ebp, DWORD [VRAM+eax+ebx]

        mov bl, 8
RSL3:   mov eax, ebp
        shl ebp, 1
        and eax, 80808080h
        shr eax, 7
        mov edx, eax
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        shr edx, 7
        or eax, edx
        and eax, 0Fh
        jz RSL4
        mov al, BYTE [CRAM+eax+16]
        and al, 3Fh
        mov eax, [palette+eax*4]
        mov [edi], eax
RSL4:   add edi, 4
        dec bl
        jnz RSL3

RSL1:   dec cl
        jnl RSL0
RSL2:   ret


SECTION .data

palette:
    DD 0000000h, 0520000h, 0AC0000h, 0FF0000h, 0005500h, 0525500h, 0AC5500h, 0FF5500h
    DD 000AA00h, 052AA00h, 0ACAA00h, 0FFAA00h, 000FF00h, 052FF00h, 0ACFF00h, 0FFFF00h
    DD 0000052h, 0520052h, 0AC0052h, 0FF0052h, 0005552h, 0525552h, 0AC5552h, 0FF5552h
    DD 000AA52h, 052AA52h, 0ACAA52h, 0FFAA52h, 000FF52h, 052FF52h, 0ACFF52h, 0FFFF52h
    DD 00000ACh, 05200ACh, 0AC00ACh, 0FF00ACh, 00055ACh, 05255ACh, 0AC55ACh, 0FF55ACh
    DD 000AAACh, 052AAACh, 0ACAAACh, 0FFAAACh, 000FFACh, 052FFACh, 0ACFFACh, 0FFFFACh
    DD 00000FFh, 05200FFh, 0AC00FFh, 0FF00FFh, 00055FFh, 05255FFh, 0AC55FFh, 0FF55FFh
    DD 000AAFFh, 052AAFFh, 0ACAAFFh, 0FFAAFFh, 000FFFFh, 052FFFFh, 0ACFFFFh, 0FFFFFFh


SECTION .bss

scrollx     RESD 1
pal         RESD 1
vb          RESD 1
sl          RESB 1
sb          RESD 1
s8x         RESB 1
RenderBL2   RESB 1

GLOBAL ScanLine, LineInt, VDPCounter
ScanLine    RESD 1          ; Current scanline
LineInt     RESB 1          ; Line Interrupt pending
VDPCounter  RESB 1          ; Line Interrupt Counter
