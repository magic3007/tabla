/******************************************************************************
*
* Copyright (C) 2009 - 2014 Xilinx, Inc.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* Use of the Software is limited solely to applications:
* (a) running on a Xilinx device, or
* (b) that interact with a Xilinx device through a bus or interconnect.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
* XILINX  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
* WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
* OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*
* Except as contained in this notice, the name of the Xilinx shall not be used
* in advertising or otherwise to promote the sale, use or other dealings in
* this Software without prior written authorization from Xilinx.
*
******************************************************************************/

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "xil_types.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "unistd.h"

#define AXI_GP0_MASTER_BASE_ADDR (u32*)0x43C00000
#define AXI_HP0_RD_BASE_ADDR (u32*)0x00000000
#define AXI_HP0_WR_BASE_ADDR (u32*)0x02000000



int main () {
	init_platform();
	Xil_DCacheDisable();

	int i, k = 16;

	xil_printf (" ==================================================\n\r ");
	xil_printf ("Loopback Test\n\r ");
	u32 * base_address = AXI_GP0_MASTER_BASE_ADDR;
	u32 * rd_address   = AXI_HP0_RD_BASE_ADDR;
	u32 * wr_address   = AXI_HP0_WR_BASE_ADDR;

	//for (i=0; i<3; i++) {
	//	xil_printf ("Address:%08x Value:%08x\n\r ", base_address+i,*(base_address+i));
	//}

	for (i=0; i<k; i++) {
		*(wr_address+i) = 1;
	}
    xil_printf ("Initializing Write location\n\r ");
	xil_printf("    Done!\n\r ");

	for (i=0; i<k; i++) {
		*(rd_address+i) = i;
	}
    xil_printf ("Initializing Read location\n\r ");
	xil_printf("    Done!\n\r ");

	xil_printf("Invoking the accelerator\n\r ");
	*(base_address+0) = 0x00000001;
	xil_printf("Waiting for the accelerator to finish processing\n\r ");
	//sleep(1);
	while (*(base_address+1) != 1) {
		sleep(5);
	}
	xil_printf("    Done!\n\r ");
    xil_printf("Verifying results \n\r ");

	for (i=0; i<k; i++) {
		//xil_printf ("WRITE Address:%08x Value:%d\n\r ", wr_address+i,*(wr_address+i));
	}

	for (i=0; i<k; i++) {
		//xil_printf ("READ Address:%08x Value:%08x\n\r ", rd_address+i, *(rd_address+i));
	}

    int count = 0;
	for (i=0; i<k; i++) {
		if (*(rd_address + i) != *(wr_address + i)) count++;
	}
    if (count > 0) {
        xil_printf ("Results : Failed\n\r ");
    }
    else {
        xil_printf ("Results : Passed\n\r ");
    }
	xil_printf ("==================================================\n\r ");

	cleanup_platform();
	return 0;
}

