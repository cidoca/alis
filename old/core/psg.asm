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


FREQUENCY   EQU 48000
BUFFERSIZE  EQU FREQUENCY / 60

%INCLUDE "data.inc"

SECTION .text

; * Reset sound system
; **********************
GLOBAL reset_PSG
reset_PSG:
        ; Clear sound registers
        xor eax, eax
        mov [rVol1], eax
        mov [rFreq1], eax
        mov [rFreq2], eax
        mov [rFreq3], eax
        mov [rFreq4], eax
        mov [rLast], eax

        ; Initialize noise
        mov DWORD [Noise], 1
        mov DWORD [FeedBack], 8000h
        mov [NoiseFreq2], al

        ; Initialize periods
        mov [Signal], al
        mov DWORD [Period1], FREQUENCY
        mov DWORD [Period2], FREQUENCY
        mov DWORD [Period3], FREQUENCY
        mov [Period4], eax

        ret

; * Write in sound registers
; ****************************
GLOBAL write_PSG
write_PSG:
        test al, 80h
        jz PSGW1
        movzx ebx, al
        shr bl, 5
        and bl, 3
        test al, 10h
        jz PSGW0

        ; Volume
        not al
        and al, 0Fh
        mov [rVol1+ebx], al
        ret

        ; Frequency (first write)
PSGW0:  cmp bl, 3
        je PSGW01
        and al, 0Fh
        and DWORD [rFreq1+ebx*4], 3F0h
        or [rFreq1+ebx*4], al
        cmp bl, 2
        jne PSGW00
        cmp BYTE [NoiseFreq2], 0
        je PSGW00
        and DWORD [rFreq4], 3F0h
        or [rFreq4], al
PSGW00: mov [rLast], ebx
        ret

        ; Noise
PSGW01: test al, 4
        jnz PSGW02
        mov DWORD [Noise], 1
        mov DWORD [FeedBack], 08000h    ; Periodic noise
        jmp PSGW03
PSGW02: mov DWORD [FeedBack], 0F037h    ; White noise
PSGW03: and al, 3
        cmp al, 3
        je PSGW04
        mov BYTE [NoiseFreq2], 0
        mov cl, al
        mov eax, 16
        shl al, cl
        mov [rFreq4], eax
        ret
PSGW04: mov BYTE [NoiseFreq2], 1
        mov eax, [rFreq3]
        mov [rFreq4], eax
        ret

        ; Frequency (second write)
PSGW1:  mov ebx, [rLast]
        shl eax, 4
        and eax, 3F0h
        and DWORD [rFreq1+ebx*4], 0Fh
        or [rFreq1+ebx*4], eax
        cmp bl, 2
        jne PSGW2
        cmp BYTE [NoiseFreq2], 0
        je PSGW2
        and DWORD [rFreq4], 0Fh
        or [rFreq4], eax
PSGW2:  ret

; * Updates buffer
; ******************
GLOBAL make_PSG
make_PSG:
        ; Clear buffer
        mov rax, 8080808080808080h
        mov ecx, BUFFERSIZE / 8
        mov rdi, rsi
        rep stosq

        ; Generates channel 1
        mov al, [rVol1]
        mov ah, 1
        test [Signal], ah
        jz MPS01
        neg al
MPS01:  mov r8d, [rFreq1]
        movzx r8d, WORD [Frequencia+r8d*2]
        cmp r8d, FREQUENCY
        ja MPS2
        mov edx, [Period1]
        call square_wave
        mov [Period1], edx

        ; Generates channel 2
MPS2:   mov al, [rVol2]
        mov ah, 2
        test [Signal], ah
        jz MPS02
        neg al
MPS02:  mov r8d, [rFreq2]
        movzx r8d, WORD [Frequencia+r8d*2]
        cmp r8d, FREQUENCY
        ja MPS4
        mov edx, [Period2]
        call square_wave
        mov [Period2], edx

        ; Generates channel 3
MPS4:   mov al, [rVol3]
        mov ah, 4
        test [Signal], ah
        jz MPS04
        neg al
MPS04:  mov r8d, [rFreq3]
        movzx r8d, WORD [Frequencia+r8d*2]
        cmp r8d, FREQUENCY
        ja MPS6
        mov edx, [Period3]
        call square_wave
        mov [Period3], edx

        ; Generates channel 4
MPS6:   mov ah, [rVol4]
        shl ah, 1
        mov r8d, [rFreq4]
        movzx r8d, WORD [Frequencia+r8d*2]
        cmp r8d, FREQUENCY
        ja MPS66
        mov ecx, BUFFERSIZE
        mov edx, [Period4]
        mov r9d, [FeedBack]
        mov rdi, rsi
        call WPNoise
        mov [Period4], edx

MPS66:  ret

; * Generates a squera wave
; ***************************
GLOBAL square_wave
square_wave:
        mov ecx, BUFFERSIZE
        mov rdi, rsi

SW0:    jecxz SW1
        dec ecx

        add [rdi], al
        inc rdi

        sub edx, r8d
        jg SW0

        neg al
        xor [Signal], ah
        add edx, FREQUENCY
        jmp SW0

SW1:    ret

; * Generates a white or periodic noise
; ***************************************
GLOBAL WPNoise
WPNoise:
        test DWORD [Noise], 1
        jnz WPN0
        mov al, 0
        jmp WPN1
WPN0:   mov al, ah
        xor [Noise], r9d
WPN1:   shr DWORD [Noise], 1

        add edx, FREQUENCY
WPN2:   jecxz WPN3
        add [rdi], al
        inc rdi
        dec ecx
        sub edx, r8d
        jns WPN2
        jmp WPNoise

WPN3:   ret


SECTION .data

; Frequency table
GLOBAL Frequencia
Frequencia:
    DW 0FFFFh, 0FFFFh, 0FFFFh, 0FFFFh, 0F424h, 0C350h, 0A2C2h, 08B82h, 07A12h, 06C81h, 061A8h
    DW 058C7h, 05161h, 04B1Eh, 045C1h, 0411Ah, 03D09h, 03971h, 03640h, 03365h, 030D4h, 02E80h
    DW 02C63h, 02A75h, 028B0h, 02710h, 0258Fh, 0242Bh, 022E0h, 021ACh, 0208Dh, 01F80h, 01E84h
    DW 01D97h, 01CB8h, 01BE6h, 01B20h, 01A64h, 019B2h, 0190Ah, 0186Ah, 017D1h, 01740h, 016B5h
    DW 01631h, 015B3h, 0153Ah, 014C7h, 01458h, 013EEh, 01388h, 01325h, 012C7h, 0126Ch, 01215h
    DW 011C1h, 01170h, 01121h, 010D6h, 0108Dh, 01046h, 01002h, 00FC0h, 00F80h, 00F42h, 00F06h
    DW 00ECBh, 00E93h, 00E5Ch, 00E27h, 00DF3h, 00DC1h, 00D90h, 00D60h, 00D32h, 00D05h, 00CD9h
    DW 00CAEh, 00C85h, 00C5Ch, 00C35h, 00C0Eh, 00BE8h, 00BC4h, 00BA0h, 00B7Dh, 00B5Ah, 00B39h
    DW 00B18h, 00AF8h, 00AD9h, 00ABBh, 00A9Dh, 00A80h, 00A63h, 00A47h, 00A2Ch, 00A11h, 009F7h
    DW 009DDh, 009C4h, 009ABh, 00992h, 0097Bh, 00963h, 0094Ch, 00936h, 00920h, 0090Ah, 008F5h
    DW 008E0h, 008CCh, 008B8h, 008A4h, 00890h, 0087Dh, 0086Bh, 00858h, 00846h, 00834h, 00823h
    DW 00812h, 00801h, 007F0h, 007E0h, 007D0h, 007C0h, 007B0h, 007A1h, 00791h, 00783h, 00774h
    DW 00765h, 00757h, 00749h, 0073Bh, 0072Eh, 00720h, 00713h, 00706h, 006F9h, 006EDh, 006E0h
    DW 006D4h, 006C8h, 006BCh, 006B0h, 006A4h, 00699h, 0068Dh, 00682h, 00677h, 0066Ch, 00661h
    DW 00657h, 0064Ch, 00642h, 00638h, 0062Eh, 00624h, 0061Ah, 00610h, 00607h, 005FDh, 005F4h
    DW 005EBh, 005E2h, 005D9h, 005D0h, 005C7h, 005BEh, 005B5h, 005ADh, 005A5h, 0059Ch, 00594h
    DW 0058Ch, 00584h, 0057Ch, 00574h, 0056Ch, 00565h, 0055Dh, 00556h, 0054Eh, 00547h, 00540h
    DW 00538h, 00531h, 0052Ah, 00523h, 0051Ch, 00516h, 0050Fh, 00508h, 00502h, 004FBh, 004F5h
    DW 004EEh, 004E8h, 004E2h, 004DBh, 004D5h, 004CFh, 004C9h, 004C3h, 004BDh, 004B7h, 004B1h
    DW 004ACh, 004A6h, 004A0h, 0049Bh, 00495h, 00490h, 0048Ah, 00485h, 00480h, 0047Ah, 00475h
    DW 00470h, 0046Bh, 00466h, 00461h, 0045Ch, 00457h, 00452h, 0044Dh, 00448h, 00443h, 0043Eh
    DW 0043Ah, 00435h, 00430h, 0042Ch, 00427h, 00423h, 0041Eh, 0041Ah, 00416h, 00411h, 0040Dh
    DW 00409h, 00404h, 00400h, 003FCh, 003F8h, 003F4h, 003F0h, 003ECh, 003E8h, 003E4h, 003E0h
    DW 003DCh, 003D8h, 003D4h, 003D0h, 003CCh, 003C8h, 003C5h, 003C1h, 003BDh, 003BAh, 003B6h
    DW 003B2h, 003AFh, 003ABh, 003A8h, 003A4h, 003A1h, 0039Dh, 0039Ah, 00397h, 00393h, 00390h
    DW 0038Dh, 00389h, 00386h, 00383h, 00380h, 0037Ch, 00379h, 00376h, 00373h, 00370h, 0036Dh
    DW 0036Ah, 00367h, 00364h, 00361h, 0035Eh, 0035Bh, 00358h, 00355h, 00352h, 0034Fh, 0034Ch
    DW 00349h, 00346h, 00344h, 00341h, 0033Eh, 0033Bh, 00339h, 00336h, 00333h, 00330h, 0032Eh
    DW 0032Bh, 00329h, 00326h, 00323h, 00321h, 0031Eh, 0031Ch, 00319h, 00317h, 00314h, 00312h
    DW 0030Fh, 0030Dh, 0030Ah, 00308h, 00305h, 00303h, 00301h, 002FEh, 002FCh, 002FAh, 002F7h
    DW 002F5h, 002F3h, 002F1h, 002EEh, 002ECh, 002EAh, 002E8h, 002E5h, 002E3h, 002E1h, 002DFh
    DW 002DDh, 002DAh, 002D8h, 002D6h, 002D4h, 002D2h, 002D0h, 002CEh, 002CCh, 002CAh, 002C8h
    DW 002C6h, 002C4h, 002C2h, 002C0h, 002BEh, 002BCh, 002BAh, 002B8h, 002B6h, 002B4h, 002B2h
    DW 002B0h, 002AEh, 002ACh, 002ABh, 002A9h, 002A7h, 002A5h, 002A3h, 002A1h, 002A0h, 0029Eh
    DW 0029Ch, 0029Ah, 00298h, 00297h, 00295h, 00293h, 00291h, 00290h, 0028Eh, 0028Ch, 0028Bh
    DW 00289h, 00287h, 00285h, 00284h, 00282h, 00281h, 0027Fh, 0027Dh, 0027Ch, 0027Ah, 00278h
    DW 00277h, 00275h, 00274h, 00272h, 00271h, 0026Fh, 0026Dh, 0026Ch, 0026Ah, 00269h, 00267h
    DW 00266h, 00264h, 00263h, 00261h, 00260h, 0025Eh, 0025Dh, 0025Bh, 0025Ah, 00258h, 00257h
    DW 00256h, 00254h, 00253h, 00251h, 00250h, 0024Fh, 0024Dh, 0024Ch, 0024Ah, 00249h, 00248h
    DW 00246h, 00245h, 00244h, 00242h, 00241h, 00240h, 0023Eh, 0023Dh, 0023Ch, 0023Ah, 00239h
    DW 00238h, 00236h, 00235h, 00234h, 00233h, 00231h, 00230h, 0022Fh, 0022Eh, 0022Ch, 0022Bh
    DW 0022Ah, 00229h, 00227h, 00226h, 00225h, 00224h, 00223h, 00221h, 00220h, 0021Fh, 0021Eh
    DW 0021Dh, 0021Bh, 0021Ah, 00219h, 00218h, 00217h, 00216h, 00215h, 00213h, 00212h, 00211h
    DW 00210h, 0020Fh, 0020Eh, 0020Dh, 0020Ch, 0020Bh, 00209h, 00208h, 00207h, 00206h, 00205h
    DW 00204h, 00203h, 00202h, 00201h, 00200h, 001FFh, 001FEh, 001FDh, 001FCh, 001FBh, 001FAh
    DW 001F9h, 001F8h, 001F7h, 001F6h, 001F5h, 001F4h, 001F3h, 001F2h, 001F1h, 001F0h, 001EFh
    DW 001EEh, 001EDh, 001ECh, 001EBh, 001EAh, 001E9h, 001E8h, 001E7h, 001E6h, 001E5h, 001E4h
    DW 001E3h, 001E2h, 001E1h, 001E0h, 001DFh, 001DEh, 001DEh, 001DDh, 001DCh, 001DBh, 001DAh
    DW 001D9h, 001D8h, 001D7h, 001D6h, 001D5h, 001D5h, 001D4h, 001D3h, 001D2h, 001D1h, 001D0h
    DW 001CFh, 001CEh, 001CEh, 001CDh, 001CCh, 001CBh, 001CAh, 001C9h, 001C9h, 001C8h, 001C7h
    DW 001C6h, 001C5h, 001C4h, 001C4h, 001C3h, 001C2h, 001C1h, 001C0h, 001C0h, 001BFh, 001BEh
    DW 001BDh, 001BCh, 001BCh, 001BBh, 001BAh, 001B9h, 001B8h, 001B8h, 001B7h, 001B6h, 001B5h
    DW 001B5h, 001B4h, 001B3h, 001B2h, 001B2h, 001B1h, 001B0h, 001AFh, 001AFh, 001AEh, 001ADh
    DW 001ACh, 001ACh, 001ABh, 001AAh, 001A9h, 001A9h, 001A8h, 001A7h, 001A7h, 001A6h, 001A5h
    DW 001A4h, 001A4h, 001A3h, 001A2h, 001A2h, 001A1h, 001A0h, 0019Fh, 0019Fh, 0019Eh, 0019Dh
    DW 0019Dh, 0019Ch, 0019Bh, 0019Bh, 0019Ah, 00199h, 00199h, 00198h, 00197h, 00197h, 00196h
    DW 00195h, 00195h, 00194h, 00193h, 00193h, 00192h, 00191h, 00191h, 00190h, 00190h, 0018Fh
    DW 0018Eh, 0018Eh, 0018Dh, 0018Ch, 0018Ch, 0018Bh, 0018Ah, 0018Ah, 00189h, 00189h, 00188h
    DW 00187h, 00187h, 00186h, 00186h, 00185h, 00184h, 00184h, 00183h, 00182h, 00182h, 00181h
    DW 00181h, 00180h, 00180h, 0017Fh, 0017Eh, 0017Eh, 0017Dh, 0017Dh, 0017Ch, 0017Bh, 0017Bh
    DW 0017Ah, 0017Ah, 00179h, 00179h, 00178h, 00177h, 00177h, 00176h, 00176h, 00175h, 00175h
    DW 00174h, 00174h, 00173h, 00172h, 00172h, 00171h, 00171h, 00170h, 00170h, 0016Fh, 0016Fh
    DW 0016Eh, 0016Eh, 0016Dh, 0016Ch, 0016Ch, 0016Bh, 0016Bh, 0016Ah, 0016Ah, 00169h, 00169h
    DW 00168h, 00168h, 00167h, 00167h, 00166h, 00166h, 00165h, 00165h, 00164h, 00164h, 00163h
    DW 00163h, 00162h, 00162h, 00161h, 00161h, 00160h, 00160h, 0015Fh, 0015Fh, 0015Eh, 0015Eh
    DW 0015Dh, 0015Dh, 0015Ch, 0015Ch, 0015Bh, 0015Bh, 0015Ah, 0015Ah, 00159h, 00159h, 00158h
    DW 00158h, 00157h, 00157h, 00156h, 00156h, 00155h, 00155h, 00155h, 00154h, 00154h, 00153h
    DW 00153h, 00152h, 00152h, 00151h, 00151h, 00150h, 00150h, 00150h, 0014Fh, 0014Fh, 0014Eh
    DW 0014Eh, 0014Dh, 0014Dh, 0014Ch, 0014Ch, 0014Ch, 0014Bh, 0014Bh, 0014Ah, 0014Ah, 00149h
    DW 00149h, 00148h, 00148h, 00148h, 00147h, 00147h, 00146h, 00146h, 00145h, 00145h, 00145h
    DW 00144h, 00144h, 00143h, 00143h, 00142h, 00142h, 00142h, 00141h, 00141h, 00140h, 00140h
    DW 00140h, 0013Fh, 0013Fh, 0013Eh, 0013Eh, 0013Eh, 0013Dh, 0013Dh, 0013Ch, 0013Ch, 0013Ch
    DW 0013Bh, 0013Bh, 0013Ah, 0013Ah, 0013Ah, 00139h, 00139h, 00138h, 00138h, 00138h, 00137h
    DW 00137h, 00136h, 00136h, 00136h, 00135h, 00135h, 00135h, 00134h, 00134h, 00133h, 00133h
    DW 00133h, 00132h, 00132h, 00131h, 00131h, 00131h, 00130h, 00130h, 00130h, 0012Fh, 0012Fh
    DW 0012Fh, 0012Eh, 0012Eh, 0012Dh, 0012Dh, 0012Dh, 0012Ch, 0012Ch, 0012Ch, 0012Bh, 0012Bh
    DW 0012Bh, 0012Ah, 0012Ah, 00129h, 00129h, 00129h, 00128h, 00128h, 00128h, 00127h, 00127h
    DW 00127h, 00126h, 00126h, 00126h, 00125h, 00125h, 00125h, 00124h, 00124h, 00124h, 00123h
    DW 00123h, 00123h, 00122h, 00122h, 00122h, 00121h, 00121h, 00121h, 00120h, 00120h, 00120h
    DW 0011Fh, 0011Fh, 0011Fh, 0011Eh, 0011Eh, 0011Eh, 0011Dh, 0011Dh, 0011Dh, 0011Ch, 0011Ch
    DW 0011Ch, 0011Bh, 0011Bh, 0011Bh, 0011Ah, 0011Ah, 0011Ah, 00119h, 00119h, 00119h, 00118h
    DW 00118h, 00118h, 00117h, 00117h, 00117h, 00117h, 00116h, 00116h, 00116h, 00115h, 00115h
    DW 00115h, 00114h, 00114h, 00114h, 00113h, 00113h, 00113h, 00113h, 00112h, 00112h, 00112h
    DW 00111h, 00111h, 00111h, 00110h, 00110h, 00110h, 00110h, 0010Fh, 0010Fh, 0010Fh, 0010Eh
    DW 0010Eh, 0010Eh, 0010Dh, 0010Dh, 0010Dh, 0010Dh, 0010Ch, 0010Ch, 0010Ch, 0010Bh, 0010Bh
    DW 0010Bh, 0010Bh, 0010Ah, 0010Ah, 0010Ah, 00109h, 00109h, 00109h, 00109h, 00108h, 00108h
    DW 00108h, 00107h, 00107h, 00107h, 00107h, 00106h, 00106h, 00106h, 00106h, 00105h, 00105h
    DW 00105h, 00104h, 00104h, 00104h, 00104h, 00103h, 00103h, 00103h, 00103h, 00102h, 00102h
    DW 00102h, 00101h, 00101h, 00101h, 00101h, 00100h, 00100h, 00100h, 00100h, 000FFh, 000FFh
    DW 000FFh, 000FFh, 000FEh, 000FEh, 000FEh, 000FEh, 000FDh, 000FDh, 000FDh, 000FDh, 000FCh
    DW 000FCh, 000FCh, 000FCh, 000FBh, 000FBh, 000FBh, 000FBh, 000FAh, 000FAh, 000FAh, 000FAh
    DW 000F9h, 000F9h, 000F9h, 000F9h, 000F8h, 000F8h, 000F8h, 000F8h, 000F7h, 000F7h, 000F7h
    DW 000F7h, 000F6h, 000F6h, 000F6h, 000F6h, 000F5h, 000F5h, 000F5h, 000F5h, 000F4h, 000F4h
    DW 000F4h


SECTION .bss

; Channels period
GLOBAL Period1, Period2, Period3, Period4, Signal
Period1     RESD 1
Period2     RESD 1
Period3     RESD 1
Period4     RESD 1
Signal      RESB 1
