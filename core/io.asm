%INCLUDE "cpu.inc"
%INCLUDE "vdp.inc"
%INCLUDE "psg.inc"

SECTION .text

; * Porta para escrita não implementada
; ***************************************
GLOBAL _NWIMP
_NWIMP:
		;movzx eax, al
		;push eax
		;push edx
		;push DWORD [rPC]
		;call ?WriteIOErr@@YAXHHH@Z
		;add esp, 12
		ret

; * Porta para leitura não implementada
; ***************************************
GLOBAL _NRIMP
_NRIMP:
		;push edx
		;push DWORD [rPC]
		;call ?ReadIOErr@@YAXHH@Z
		;add esp, 8
		ret

; * Nada (R)
; ************
GLOBAL NadaR
NadaR:
		mov al, 0FFh
		ret

; * Nada (W)
; ************
GLOBAL NadaW
NadaW:
		ret

; * 3E Memory Control (W)
; *************************
GLOBAL MemCtrl
MemCtrl:
		ret

; * 3F - Automatic nationalisation (W)
; **************************************
GLOBAL AutNat
AutNat:
		mov BYTE [Nationalization], al
		ret

; * 7E - V Counter (R)
; **********************
GLOBAL VCounter
VCounter:
		mov eax, DWORD [ScanLine]
		dec eax
		cmp eax, 0DAh
		jbe VC0
		sub eax, 6h
VC0:	ret

; * 7F - H Counter (R)
; **********************
GLOBAL HCounter
HCounter:
		movzx eax, BYTE [TClock]
		shr al, 2
		imul eax, eax, 6
		cmp eax, 0E9h
		jbe HC0
		sub eax, 57h
HC0:	ret		

; * BE - VDP data (R)
; *********************
GLOBAL RVDPD
RVDPD:
		mov esi, DWORD [pRAM]
		cmp esi, 0
		je RVDPD0
		inc DWORD [pRAM]
		mov al, [esi]
RVDPD0:	mov BYTE [cVDP], 0
		ret

; * BE - VDP data (W)
; *********************
GLOBAL WVDPD
WVDPD:
		mov esi, DWORD [pRAM]
		cmp esi, 0
		je WVDPD1
		inc DWORD [pRAM]
		cmp DWORD [pRAM], VRAM + 4000h ; cmp DWORD [pRAM], offset VRAM + 4000h
		jb WVDPD0
		sub DWORD [pRAM], 4000h
WVDPD0:	mov [esi], al
WVDPD1:	mov BYTE [cVDP], 0
		ret

; BF - VDP status (R)
; *********************
GLOBAL _RVDPS
_RVDPS:
		mov al, BYTE [VDPStatus]
		and BYTE [VDPStatus], 1Fh
		mov BYTE [cVDP], 0
		mov BYTE [LineInt], 0
		ret

; BF - VDP address (W)
; **********************
GLOBAL WVDPA
WVDPA:
		; Primeira ou segunda escrita?
		test BYTE [cVDP], 1
		jnz WVDPA0
		mov BYTE [VDPLow], al
		jmp WVDPAF

		; BYTE [VRAM] endereço
WVDPA0: test al, 80h
		jnz WVDPA1
;		mov bl, al
		and al, 3Fh
		mov ah, al
		mov al, BYTE [VDPLow]
		movzx eax, ax
		add eax, VRAM ; add eax, offset VRAM
;		test bl, 40h
;		jnz WVDPA00
;		inc eax
WVDPA00:mov DWORD [pRAM], eax
		jmp WVDPAF

		; PALRAM endereço
WVDPA1: test al, 40h
		jz WVDPA2
		mov al, BYTE [VDPLow]
		and al, 1Fh
		movzx eax, al
		add eax, CRAM ; add eax, offset CRAM
		mov DWORD [pRAM], eax
		jmp WVDPAF

		; Registros do VDP
WVDPA2: and al, 0Fh
		movzx edx, al
		mov al, BYTE [VDPLow]
		mov BYTE [VDPR+edx], al

WVDPAF:	xor BYTE [cVDP], 1
		ret		

; * DC/C0 - Joypad port 1 (R)
; *****************************
GLOBAL RJoy1
RJoy1:
		mov al, BYTE [Joy1]
		ret
		
; * DD/C1 - Joypad port 2 (R)
; *****************************
GLOBAL RJoy2
RJoy2:
		test BYTE [Nationalization], 80h
		jnz RJ20
		and BYTE [Joy2], ~80h
RJ20:	test BYTE [Nationalization], 20h
		jnz RJ21
		and BYTE [Joy2], ~40h
RJ21:	mov al, BYTE [Joy2]
		ret

; * DE/DF - Unknown (R/W)
; *************************
GLOBAL Unknown
Unknown:
		mov al, 0FFh
		ret

; * F0 - YM2413 address register (W)
; ************************************
GLOBAL YMAR
YMAR:
		ret

; * F1 - YM2413 data register (W)
; *********************************
GLOBAL YMDR
YMDR:
		ret

; * F2 - YM2413 control register (R)
; ************************************
GLOBAL YMCRR
YMCRR:
		mov al, 0
		ret

; * F2 - YM2413 control register (W)
; ************************************
GLOBAL YMCRW
YMCRW:
		ret


SECTION .data

GLOBAL read_io
read_io:
;		0/8		  1/9		2/A		  3/B		4/C		  5/D		6/E		  7/F
	DD NadaR,    _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 0
	DD NadaR,    _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 1
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 2
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 3
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 4
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 5
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 6
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   VCounter, HCounter	; 7
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 8
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; 9
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; A
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   RVDPD,    _RVDPS		; B
	DD RJoy1,    RJoy2,    _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; C
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   RJoy1,    RJoy2,    Unknown,  Unknown	; D
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; E
	DD _NRIMP,   _NRIMP,   YMCRR,    _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP
	DD _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP,   _NRIMP		; F

GLOBAL write_io
write_io:
;		0/8		  1/9		2/A		  3/B		4/C		  5/D		6/E		  7/F
	DD MemCtrl,  _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; 0
	DD _NWIMP,   AutNat,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD MemCtrl,  _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; 1
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; 2
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   MemCtrl,  AutNat		; 3
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; 4
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; 5
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; 6
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   write_PSG,write_PSG	; 7
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; 8
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; 9
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; A
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   WVDPA,    WVDPD,    WVDPA		; B
	DD NadaW,    _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; C
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   NadaW,    NadaW		; D
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP		; E
	DD YMAR,     YMDR,     YMCRW,    _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP
	DD _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   _NWIMP,   NadaW,    NadaW		; F


SECTION .bss

GLOBAL Nationalization
Nationalization	RESB 1

; Portas do joystick
GLOBAL Joy1, Joy2
Joy1	RESB 1
Joy2	RESB 1
