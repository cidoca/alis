#include <stdint.h>
#include <string.h>
#include "psg.h"
#include "cpu.h"
#include "log.h"

#undef DBG_PRINT
#define DBG_PRINT(f, ...) {}
#define DBG_TITLE "\033[1;36mPSG:\033[0m "

#define PSG_CLOCK 111861    // 3579545 / 32

#define noise       psg.noise
#define attenuation psg.attenuation
#define signal      psg.signal
#define feedback    psg.feedback
#define noiseFreq3  psg.noiseFreq3
#define frequency   psg.frequency
#define period      psg.period

struct PSG psg;

void resetPSG() {
    memset(&psg, 0, sizeof(psg));
    noise = 0x4000;
    for (int i = 0; i < 4; i++)
        period[i] = PSG_FREQUENCY;
}

void writePSG(uint8_t value) {
    int channel;
    static int last;

    DBG_PRINT("writing data %02X\n", value);

    cpu.TClock += 25;

    if (value & 0x80) {                 // First write
        last = (value >> 4) & 7;
        channel = last >> 1;
        if (value & 0x10)               // Attenuation
            attenuation[channel] = (~value) & 0xF;
        else if (channel < 3)       // Tone frequency
            frequency[channel] = (frequency[channel] & 0x3F0) | (value & 0xF);
        else {                          // Noise control
            noise = 0x4000;
            feedback = (value >> 2) & 1;
            noiseFreq3 = (value & 3) == 3;
            frequency[3] = 16 << (value & 3);
        }
    } else {
        channel = last >> 1;
        if (last & 1)                   // Attenuation
            attenuation[channel] = (~value) & 0xF;
        else if (channel < 3)           // Second write (high frequency)
            frequency[channel] = (frequency[channel] & 0xF) | ((value & 0x3F) << 4);
        else {
            noise = 0x4000;
            feedback = (value >> 2) & 1;
            noiseFreq3 = (value & 3) == 3;
            frequency[3] = 16 << (value & 3);
        }
    }
}

void writeSquareWave(uint8_t *out, int channel, int len) {
    int freq;
    int8_t volume;

    if (!attenuation[channel])
        return;

    freq = frequency[channel];
    if (freq >= 5) {
        freq = 2 * PSG_CLOCK / freq;
        volume = signal[channel] ? -attenuation[channel] : attenuation[channel];

        for (int i = 0; i < len; i++) {
            *out++ += volume;

            period[channel] -= freq;
            if (period[channel] <= 0) {
                period[channel] += PSG_FREQUENCY;
                volume = -volume;
            }
        }

        signal[channel] = volume < 0;
    }
}

void writeNoise(uint8_t *out, int len) {
    int freq;
    int8_t volume;

    if (!attenuation[3])
        return;

    freq = noiseFreq3 ? frequency[2] : frequency[3];
    if (freq >= 5) {
        freq = 2 * PSG_CLOCK / freq;
        volume = attenuation[3];

        for (int i = 0; i < len; i++) {
            *out++ += noise & 1 ? volume : -volume;

            period[3] -= freq;
            if (period[3] <= 0) {
                noise = (((feedback & ((noise >> 1) & 1)) ^ (noise & 1)) << 14) | (noise >> 1);
                period[3] += PSG_FREQUENCY;
            }
        }
    }
}

void PSGupdateBuffer(void *data, uint8_t *buffer, int len) {
    memset(buffer, 0x80, len * sizeof(uint8_t));

    writeSquareWave(buffer, 0, len);
    writeSquareWave(buffer, 1, len);
    writeSquareWave(buffer, 2, len);
    writeNoise(buffer, len);
}
