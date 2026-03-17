#include <stdio.h>

#ifdef DEBUG
    #define DBG_DUMP_CORE       dumpOpcode();
    #define DBG_PRINT_HISTORY   printHistory();
    #define DBG_PRINT(f, ...)   printf(DBG_TITLE f, ##__VA_ARGS__)
#else
    #define DBG_DUMP_CORE       {}
    #define DBG_PRINT_HISTORY   {}
    #define DBG_PRINT(f, ...)   {}
#endif

extern int dumping;

void printHistory();
void dumpOpcode();
