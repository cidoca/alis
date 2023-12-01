#ifdef FTDI
void FTDI_Enabled();
void FTDI_Open();
void FTDI_Close();
void FTDI_SendFrame(unsigned char *buffer, int len);
void FTDI_WriteBuffer(uint8_t mode, uint8_t value);
void FTDI_FlushBuffer();
#else
#define FTDI_Enabled() {}
#define FTDI_Open() {}
#define FTDI_Close() {}
#define FTDI_SendFrame(buffer, len) {}
#define FTDI_WriteBuffer(mode, value) {}
#define FTDI_FlushBuffer() {}
#endif
