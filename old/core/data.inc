; **** BANKS ****
EXTERN pBank0, pBank1, pBank2, pBank2ROM, battery, BankRegs

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
