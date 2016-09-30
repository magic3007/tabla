#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <time.h>
#include <sys/time.h>
#include <string.h>

#include "cma.h"



/* SYNC_MODE:
 * 0: CPU cache ON (very fast, but no consistent)
 * 1: CPU cache OFF, O_SYNC (slow)
 * 2: CPU cache OFF, O_SYNC, Write Combine ON (fast)
 * 3: CPU cache OFF, O_SYNC, DMA coherent (fast)
 */
#define SYNC_MODE       3
#define SHARED_MEM_SIZE 0x38000000
#define SHARED_START    0x08000000
#define ADDRESS_MASK    0xFFFF0000

#define CONTROL_ADDRESS 0x43c00000
#define CONTROL_SIZE    16

int main(int argc, char** argv)
{

  printf("Tabla Loopback Test : \n\r ");
  int i;


  int dh = open("/dev/mem", O_RDWR | O_SYNC); // Open /dev/mem which represents the whole physical memory
  volatile unsigned int* control_master = mmap(NULL, CONTROL_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, dh, CONTROL_ADDRESS); // Memory map AXI Lite register block

  void* buf = mmap(NULL, SHARED_MEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, dh, SHARED_START);
  if (buf == NULL) {
    printf ("Can't allocate buf\n\r ");
  }
  
  //printf ("Address of buffer : Physical = %8x, Virtual = %8x\n\r ", SHARED_START, buf);


  unsigned int test_vector = 16;
  int errors = 0;

  int iter;
  for (iter=0; iter<1<<5 && !errors; iter++) {
    test_vector = 16*iter + 16;
    printf ("Testing for vector length = %d\n\r ", test_vector);
    int rd_address = *(control_master + 2);
    int rd_offset  = rd_address - SHARED_START;// + (rd_address - (rd_address & ADDRESS_MASK));
    int wr_address = *(control_master + 3);
    int wr_offset  = wr_address - SHARED_START;// + (wr_address - (wr_address & ADDRESS_MASK));


    volatile int* rd_buf = buf + rd_offset;
    volatile int* wr_buf = buf + wr_offset;

    printf ("Physical Addresses of rd_buf and wr_buf are : %8x and %8x\n\r ", rd_address, wr_address);
    printf ("Virtual  Addresses of rd_buf and wr_buf are : %8x and %8x\n\r ", rd_buf,     wr_buf);
    printf ("Offset   Addresses of rd_buf and wr_buf are : %8x and %8x\n\r ", rd_offset,  wr_offset);

    
    int r = rand();
    for(i=0; i<test_vector*2; i++){
      *(rd_buf+i) = i + r;
    }
    for(i=test_vector*2; i<1024; i++){
      *(rd_buf+i) = -1;
    }

    //cma_cache_clean((char*)rd_buf, 16);

    struct timeval s, e;

    gettimeofday(&s, NULL);

    for(i=0; i<1024; i++){
      *(wr_buf+i) = -1;
    }

    //cma_cache_clean((char*)buf, SHARED_MEM_SIZE);

    cma_cache_clean((char*)wr_buf, test_vector*2*8);
    cma_cache_clean((char*)rd_buf, test_vector*2*8);
    for(i=0; i<test_vector*2; i++){
        //printf("INIT: rd_buf : %8x, wr_buf : %8x\n\r ", *(rd_buf+i), *(wr_buf+i));
        //printf("INIT: rd_addr: %8x, wr_addr: %8x\n\r ", rd_buf+i, wr_buf+i);
        assert (*(wr_buf+i) == -1);
    }


    printf("Invoking the accelerator\n\r ");
    *(control_master+1) = test_vector;
    assert (test_vector == *(control_master+8));
    *(control_master+0) = 1- *(control_master+0);
    //msync (control_master, TEST_VEC_SIZE, 2);
    printf("Waiting for the accelerator to finish processing\n\r ");
    sleep(0.1);
    while (*(control_master+1) != 1) {
       sleep(1);
    }
    //msync (control_master, TEST_VEC_SIZE, 2);
    //cma_cache_clean((char*)buf, SHARED_MEM_SIZE);

    gettimeofday(&e, NULL);

    //cma_cache_clean((char*)wr_buf, 16);
    
    int j = 0;
    for(i=0; i<test_vector*2; i++){
      if(*(wr_buf+i+j) != *(rd_buf+i)){
        errors++;
        printf("NG: rd_buf : %8x, wr_buf : %8x\n\r ", *(rd_buf+i), *(wr_buf+i));
        printf("NG: rd_addr: %8x, wr_addr: %8x\n\r ", rd_buf+i, wr_buf+i);
        while (*(wr_buf+i) != 0xDEADBEEF && j < 1024) {
          j++;
        }
        if (j < 1024) {
          printf ("Write offset = %d", j);
          errors--;
        }
        else {
          j=0;
        }
      }
      else {
        //printf("OK: rd_buf : %8x, wr_buf : %8x\n\r ", *(rd_buf+i), *(wr_buf+i));
        //printf("OK: rd_addr: %8x, wr_addr: %8x\n\r ", rd_buf+i, wr_buf+i);
      }
    }

    double exec_time = (e.tv_sec - s.tv_sec) + (e.tv_usec - s.tv_usec) * 1.0E-6;
    printf("exectuion time=%lf\n\r ", exec_time);
    
    printf ("rd_addr      : %8x\n\r ", *(control_master+2));
    printf ("wr_addr      : %8x\n\r ", *(control_master+3));
    printf ("\n\r ");


    printf ("Loopback_len : %8d\n\r ", *(control_master+8));
    printf ("\n\r ");

    printf ("total_cycles : %8d\n\r ", *(control_master+4));
    printf ("rd_cycles    : %8d\n\r ", *(control_master+5));
    printf ("pr_cycles    : %8d\n\r ", *(control_master+6));
    printf ("wr_cycles    : %8d\n\r ", *(control_master+7));
    printf ("\n\r ");

    printf ("rd_count     : %8d\n\r ", *(control_master+9));
    printf ("wr_count     : %8d\n\r ", *(control_master+10));
    printf ("ar_count     : %8d\n\r ", *(control_master+11));
    printf ("aw_count     : %8d\n\r ", *(control_master+12));

    printf ("==================================================\n\r ");
    if(!errors){
      printf("TEST Passed - Test vector len - %d\n\r ", test_vector);
      printf ("==================================================\n\r ");
    }
    else{
      printf("TEST Failed - Test vector len = %d\n Errors = %d\n\r ", test_vector, errors);
      printf ("==================================================\n\r ");
      //munmap((void*)control_master, CONTROL_SIZE);
      //munmap(buf, SHARED_MEM_SIZE);
      //return 0;
    }
  }

  munmap((void*)control_master, CONTROL_SIZE);
  munmap(buf, SHARED_MEM_SIZE);
  return 0;

}
