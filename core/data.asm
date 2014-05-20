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


SECTION .bss

; **** BANKS ****
GLOBAL pData, pBank0, pBank1, pBank2, pBank2ROM, battery, RAMSelect
pData:              ; Alias for start pointer for state block
pBank0      RESD 1
pBank1      RESD 1
pBank2      RESD 1
pBank2ROM   RESD 1
battery     RESB 1
RAMSelect   RESB 1


; **** CPU ****
; Primary and secondary registers
GLOBAL Flag, rAcc, rC, rB, rE, rD, rL, rH
GLOBAL Flag2, rAcc2, rC2, rB2, rE2, rD2, rL2, rH2
GLOBAL rR, rI
Flag    RESB 1
rAcc    RESB 1
Flag2   RESB 1
rAcc2   RESB 1
rC      RESB 1
rB      RESB 1
rC2     RESB 1
rB2     RESB 1
rE      RESB 1
rD      RESB 1
rE2     RESB 1
rD2     RESB 1
rL      RESB 1
rH      RESB 1
rL2     RESB 1
rH2     RESB 1
rR      RESB 1
rI      RESB 1

; Pointers
GLOBAL rIX, rIY, rPCx, rSPx
rIX     RESD 1
rIY     RESD 1
rPCx    RESD 1
rSPx    RESD 1

; Interruptions
GLOBAL TClock, IM, IFF1, IFF2, Halt, NMI
TClock  RESB 1
IM      RESB 1
IFF1    RESB 1
IFF2    RESB 1
Halt    RESB 1
NMI     RESB 1


; **** IO ****
GLOBAL Nationalization
Nationalization RESB 1


; **** PSG ****
; Sound registers
GLOBAL rVol1, rVol2, rVol3, rVol4, rFreq1, rFreq2, rFreq3, rFreq4, rLast
rVol1   RESB 1
rVol2   RESB 1
rVol3   RESB 1
rVol4   RESB 1
rFreq1  RESD 1
rFreq2  RESD 1
rFreq3  RESD 1
rFreq4  RESD 1
rLast   RESD 1

; Noise state
GLOBAL Noise, FeedBack, NoiseFreq2
Noise       RESD 1
FeedBack    RESD 1
NoiseFreq2  RESB 1


; **** VDP ****
GLOBAL VDPStatus, cVDP, VDPLow
VDPStatus   RESB 1
cVDP        RESB 1          ; First or second write in BFh port
VDPLow      RESB 1          ; Temporary value for BFh port

GLOBAL pRAM, VDPR, CRAM, VRAM
pRAM    RESD 1              ; Pointer for palette or video memory
VDPR    RESB 16             ; Video registers
CRAM    RESB 32             ; Color palette
VRAM    RESB 4000h          ; Video memory


; **** MEMORY ****
GLOBAL RAM, pDataEnd, RAM_EX, pDataXEnd
RAM         RESB 8*1024
pDataEnd:                   ; Alias for end pointer for state block
RAM_EX      RESB 2*16*1024
pDataXEnd:                  ; Alias for end pointer with extra memory block
