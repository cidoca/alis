#define PSG_FREQUENCY 48000

struct PSG {
    uint8_t attenuation[4], signal[3], feedback, noiseFreq3;
    uint32_t noise;
    int32_t frequency[4], period[4];
};

extern struct PSG psg;

void resetPSG();
void writePSG(uint8_t value);
void PSGupdateBuffer(void *data, uint8_t *buffer, int len);
