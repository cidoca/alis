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

		mov esi, VideoBuffer
		mov edi, [esp+16] 		; First parameter (surface)

		mov al, BYTE [esp+20]	; Second parameter (bpp)
		cmp al, 15
		je bpp15
		cmp al, 16
		je bpp16
		cmp al, 24
		je bpp24
		jmp bpp32

		; 15 bits
bpp15:	mov ecx, (256 * 192 * 2) / 4
bpp150:	mov eax, [esi]
		add esi, 4
		mov ebx, eax
		and eax, 0001F001Fh
		and ebx, 0FFC0FFC0h
		shr ebx, 1
		or eax, ebx
		mov [edi], eax
		add edi, 4
		dec ecx
		jnz bpp150
		jmp bppdone
		
		; 16 bits
bpp16:	mov ecx, (256 * 192 * 2) / 4
		rep movsd
		jmp bppdone

		; 24 bits
bpp24:	mov ecx, (256 * 192 * 2) / 2
bpp240:	movzx eax, word [esi]
		add esi, 2
		mov ebx, eax
		mov edx, eax
		shl eax, 3
		and eax, 0000000F8h
		shl ebx, 5
		and ebx, 00000FC00h
		shl edx, 8
		and edx, 000F80000h
		or eax, ebx
		or eax, edx
		mov [edi], eax
		add edi, 3
		dec ecx
		jnz bpp240
		jmp bppdone

		; 32 bits
bpp32:	mov ecx, (256 * 192 * 2) / 2
bpp320:	movzx eax, word [esi]
		add esi, 2
		mov ebx, eax
		mov edx, eax
		shl eax, 3
		and eax, 0000000F8h
		shl ebx, 5
		and ebx, 00000FC00h
		shl edx, 8
		and edx, 000F80000h
		or eax, ebx
		or eax, edx
		mov [edi], eax
		add edi, 4
		dec ecx
		jnz bpp320

bppdone:pop edi
		pop esi
		pop ebx
		ret
