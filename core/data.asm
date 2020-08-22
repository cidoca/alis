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


SECTION .bss

GLOBAL pData, pDataEnd, pDataXEnd, pReg, pRegEnd    ; Alias for memory block
GLOBAL pBank0, pBank1, pBank2, pBank2ROM, BankRegs  ; ROM bank pointers
GLOBAL rIX, rIY, rPCx, rSPx, rR, rI                 ; Special purpose registers
GLOBAL Flag, rAcc, rC, rB, rE, rD, rL, rH           ; Main CPU registers
GLOBAL Flag2, rAcc2, rC2, rB2, rE2, rD2, rL2, rH2   ; Alternate CPU registers
GLOBAL TClock, IM, IFF1, IFF2, Halt, NMI            ; CPU interruptions
GLOBAL rVol1, rVol2, rVol3, rVol4                   ; Sound volume
GLOBAL rFreq1, rFreq2, rFreq3, rFreq4, rLast        ; Sound frequency
GLOBAL Noise, FeedBack, NoiseFreq2                  ; Sound seeds
GLOBAL VDPStatus, cVDP, VDPLow, VDPR                ; Video registers
GLOBAL pRAM, CRAM, VRAM                             ; Video memory
GLOBAL RAM, RAM_EX                                  ; RAMs
GLOBAL battery, Nationalization

pData:                      ; Alias for start pointer for state block
pBank0      RESQ 1          ; Bank0 pointer
pBank1      RESQ 1          ; Bank1 pointer
pBank2      RESQ 1          ; Bank2 pointer (can be ROM or extra RAM pointer)
pBank2ROM   RESQ 1          ; Bank2 pointer (always pointing to ROM)

pRAM        RESQ 1          ; Video memory or palette pointer

rFreq1      RESD 1          ; Sound frequency for channel 1
rFreq2      RESD 1          ; Sound frequency for channel 2
rFreq3      RESD 1          ; Sound frequency for channel 3
rFreq4      RESD 1          ; Sound frequency for channel 4
rLast       RESD 1
Noise       RESD 1          ; Sound noise seed
FeedBack    RESD 1          ; Sound feeback seed

pReg:                       ; Alias for start register state block
rIX         RESD 1          ; Register IX
rIY         RESD 1          ; Register IY
rPCx        RESD 1          ; Register PC
rSPx        RESD 1          ; Register SP
Flag        RESB 1          ; Flags
rAcc        RESB 1          ; Register A
Flag2       RESB 1          ; Flags'
rAcc2       RESB 1          ; Register A'
rC          RESB 1          ; Register C
rB          RESB 1          ; Register B
rC2         RESB 1          ; Register C'
rB2         RESB 1          ; Register B'
rE          RESB 1          ; Register E
rD          RESB 1          ; Register D
rE2         RESB 1          ; Register E'
rD2         RESB 1          ; Register D'
rL          RESB 1          ; Register L
rH          RESB 1          ; Register H
rL2         RESB 1          ; Register L'
rH2         RESB 1          ; Register H'
rR          RESB 1          ; Register R
rI          RESB 1          ; Register I

BankRegs    RESB 4          ; Bank memory registers
pRegEnd:                    ; Alias for end register state block

battery     RESB 1          ; Extra RAM enabled
Nationalization RESB 1

TClock      RESB 1
IM          RESB 1
IFF1        RESB 1
IFF2        RESB 1
Halt        RESB 1
NMI         RESB 1

rVol1       RESB 1          ; Sound volume for channel 1
rVol2       RESB 1          ; Sound volume for channel 2
rVol3       RESB 1          ; Sound volume for channel 3
rVol4       RESB 1          ; Sound volume for channel 4
NoiseFreq2  RESB 1

VDPStatus   RESB 1
cVDP        RESB 1          ; First or second write in BFh port
VDPLow      RESB 1          ; Temporary value for BFh port

VDPR        RESB 16         ; Video registers
CRAM        RESB 32         ; Color palette
VRAM        RESB 4000h      ; Video memory

RAM         RESB 8*1024     ; Main RAM
pDataEnd:                   ; Alias for end pointer for state block
RAM_EX      RESB 32*1024    ; Extra RAM
pDataXEnd:                  ; Alias for end pointer with extra memory block
