extern uint8_t bankMask;
extern uint8_t ROM[1024 * 1024];

const uint8_t readMemory(unsigned address);
void writeMemory(unsigned address, uint8_t value);
