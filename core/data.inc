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

; **** BANKS ****
EXTERN pBank0, pBank1, pBank2, pBank2ROM, battery, RAMSelect

; **** CPU ****
EXTERN Flag, rAcc, rC, rB, rE, rD, rL, rH
EXTERN Flag2, rAcc2, rC2, rB2, rE2, rD2, rL2, rH2
EXTERN rR, rI, rIX, rIY, rPCx, rSPx
EXTERN TClock, IM, IFF1, IFF2, Halt, NMI

; **** IO ****
EXTERN Nationalization

; **** PSG ****
EXTERN rVol1, rVol2, rVol3, rVol4, rFreq1, rFreq2, rFreq3, rFreq4, rLast
EXTERN Noise, FeedBack, NoiseFreq2

; **** VDP ****
EXTERN VDPStatus, cVDP, VDPLow
EXTERN pRAM, VDPR, CRAM, VRAM

; **** MEMORY ****
EXTERN RAM, RAM_EX
