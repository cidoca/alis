// Standard C libraries
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <stdint.h>
#include <time.h>

// FTDI D2XX header
#include "ftdi/ftd2xx.h"

// ******************************************************************************
// *                           FTDI global variables                            *
// ******************************************************************************

static int enabled = 0;
static FT_HANDLE FTDI_Handle;           // handle for FTDI channel
static FT_STATUS FTDI_Status = FT_OK;   // returned status
static uint32_t FTDI_DeviceCount;       // number of FTDI devices found

static unsigned char cmdBuffer[327680], *pBuffer = cmdBuffer;

// check ftStatus, exit app with error if failure occurred
#define FTDI_StatusCheck() {if(FTDI_Status!=FT_OK){printf("%s:%d:%s(): status(0x%x) != FT_OK\n",__FILE__, __LINE__, __FUNCTION__,FTDI_Status);exit(1);}else{;}};

// ******************************************************************************
// *                   FTDI connection and initialization                       *
// ******************************************************************************

// print out FTDI device type
void FTDI_PrintDeviceType(int device_type)
{
    switch (device_type) {
    case FT_DEVICE_BM:
        printf("FT232BM");
        break;
    case FT_DEVICE_AM:
        printf("FT232AM");
        break;
    case FT_DEVICE_2232C:
        printf("FT2232C");
        break;
    case FT_DEVICE_232R:
        printf("FT232R");
        break;
    case FT_DEVICE_2232H:
        printf("FT2232H");
        break;
    case FT_DEVICE_4232H:
        printf("FT4232H");
        break;
    case FT_DEVICE_232H:
        printf("FT232H");
        break;
    default:
        printf("Unknown (0x%02X)", device_type);
        break;
    }
}

// Print FTDI device list and return index of first Mercury 2 board
// TODO: Update app to allow users to select from multiple connected Mercury 2 FPGAs
int FTDI_FindMercury2(void)
{
    // Build FTDI device information list
    printf("Checking for FTDI devices... "); fflush(stdout);
    FTDI_Status = FT_CreateDeviceInfoList(&FTDI_DeviceCount);
    FTDI_StatusCheck();

    // Print list of FTDI devices
    printf("%d FTDI devices found\n", FTDI_DeviceCount);
    if (FTDI_DeviceCount > 0) {

        // Fill FTDI device list
        FT_DEVICE_LIST_INFO_NODE *devInfo;
        devInfo = (FT_DEVICE_LIST_INFO_NODE *) malloc(sizeof(FT_DEVICE_LIST_INFO_NODE) * FTDI_DeviceCount);
        FTDI_Status = FT_GetDeviceInfoList(devInfo, &FTDI_DeviceCount);
        if (FTDI_Status == FT_OK) {

            // Print FTDI device list
            for (int i = 0; i < FTDI_DeviceCount; i++) {
                printf("Device %d:\n", i);
                printf("  - Description = '%s'\n", devInfo[i].Description);
                printf("  - Serial #    = '%s'\n", devInfo[i].SerialNumber);
                printf("  - FTDI Chip   = ");
                FTDI_PrintDeviceType(devInfo[i].Type);
                printf(" @ ");
                printf("%s\n", (devInfo[i].Flags & FT_FLAGS_HISPEED) ? "480Mbps" : "12Mbps");
                printf("  - Opened      = %s\n", (devInfo[i].Flags & FT_FLAGS_OPENED) ? "Yes" : "No");
            }
            printf("\n");

            // Find channel A (programming channel) of first Mercury 2 FPGA
            for (int i = 0; i < FTDI_DeviceCount; i++) {
                if (!strcmp(devInfo[i].Description, "Mercury 2 FPGA B")
                    && !(devInfo[i].Flags & FT_FLAGS_OPENED)) {
                    // Mercury 2 found
                    printf("Found Mercury 2 FPGA board at FTDI device %i.\n", i);
                    return i;
                }
            }
        } else {
            printf("ERROR: Unable to enumerate FTDI devices.\n");
            exit(1);
        }
    }

    // Mercury 2 not found
    printf("ERROR: No Mercury 2 FPGA board found.\n");

    printf("\n");
    printf("Please note that you may have to disable the FTDI VCP driver in order to use the D2XX driver.\n");
    printf("You can do this by running: \033[0;1msudo rmmod ftdi_sio && sudo rmmod usbserial\033[0m\n");
    printf("\n");
    printf("See FTDI Application Note AN_220 for more details:\n");
    printf("https://www.ftdichip.com/Support/Documents/AppNotes/AN_220_FTDI_Drivers_Installation_Guide_for_Linux.pdf\n");
    printf("\n");

    exit(1);
}

// Attempt to connect to Mercury 2 board with specified FTDI device ID
void FTDI_ConnectMercury2(int deviceID)
{
    // open FTDI device
    FTDI_Status = FT_Open(deviceID, &FTDI_Handle);
    if (FTDI_Status == FT_OK) {
        printf("FTDI device %i opened successfully.\n", deviceID);
    } else {
        printf("ERROR: Unable to open FTDI device %i.\n", deviceID);
        exit(1);
    }

    // configuration (see FT_000208, section 4.2 and section 5.2)
    printf("Configuring FTDI for BIT BANG communication... "); fflush(stdout);
    FTDI_Status |= FT_ResetDevice(FTDI_Handle);                                 FTDI_StatusCheck();     // reset device

    FTDI_Status |= FT_SetUSBParameters(FTDI_Handle, 4096, 4096);                FTDI_StatusCheck();     // set input transfer size to 64 bytes
    FTDI_Status |= FT_SetChars(FTDI_Handle, 0, 0, 0, 0);                        FTDI_StatusCheck();     // set error characters to none
    FTDI_Status |= FT_SetLatencyTimer(FTDI_Handle, 16);                         FTDI_StatusCheck();     // set latency timer to 2ms
    FTDI_Status |= FT_SetFlowControl(FTDI_Handle, FT_FLOW_NONE, 0x11, 0x13);    FTDI_StatusCheck();     // set flow control to RTS/CTS
    FTDI_Status |= FT_SetBaudRate(FTDI_Handle, 500000);                        FTDI_StatusCheck();
//    FTDI_Status |= FT_SetDivisor(FTDI_Handle, 5);                               FTDI_StatusCheck();
    FTDI_Status |= FT_SetBitMode(FTDI_Handle, 0xFF, 0x01);                      FTDI_StatusCheck();

    printf("OK!\n");
}

void FTDI_WriteBuffer(uint8_t mode, uint8_t value) {
    if (enabled) {
        *pBuffer++ = mode;
        *pBuffer++ = value;
        *pBuffer++ = value;
        *pBuffer++ = value;
        if (pBuffer - cmdBuffer > 32700)
            printf("##### Katia Flavia ######\n");
    }
}

void FTDI_FlushBuffer() {
    DWORD ret;

    if (enabled && pBuffer != cmdBuffer) {
        FTDI_Status = FT_Write(FTDI_Handle, cmdBuffer, pBuffer - cmdBuffer, &ret);
        FTDI_StatusCheck();
        pBuffer = cmdBuffer;
    }
}

void FTDI_SendFrame(unsigned char *buffer, int len) {
    DWORD ret;

    FT_Write(FTDI_Handle, buffer, len, &ret);
}

void FTDI_Open() {
    if (enabled)
        FTDI_ConnectMercury2(FTDI_FindMercury2());
}

void FTDI_Close() {
    if (enabled)
        FT_Close(FTDI_Handle);
}

void FTDI_Enabled() {
    enabled = 1;
}

int FTDI_IsEnabled() {
    return enabled;
}
