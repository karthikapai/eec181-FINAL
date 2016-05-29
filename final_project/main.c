#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>

#define HW_BASE 0xFC000000
#define HW_SPAN 0x04000000
#define HW_MASK (HW_SPAN - 1)
//#define OUTPUT_SEVEN_SEGMENT_COMPONENT_TYPE seven_segment

int delay(unsigned int mseconds)
{
  clock_t goal = mseconds + clock();
  while (goal > clock());
}
int main(){
  void *VA, *led_ptr;
  int fd;
  int result;
  unsigned int data = 0;
  int i;
  int j;

  if ((fd = open("/dev/mem", (O_RDWR|O_SYNC))) == -1){
    printf("ERROR: could not open \"/dev/mem\"...\n");
    return  (1);
  }

  VA = mmap(NULL, HW_SPAN, (PROT_READ|PROT_WRITE), MAP_SHARED, fd, HW_BASE);

  if (VA == MAP_FAILED){
    printf("ERROR: mmap() failed... \n");
    close(fd);
    return (1);
  }

  led_ptr = VA + ((unsigned long)(0xff200000 + 0x80) & (unsigned long)(HW_MASK));
 

  while (1){
	  for(i = 9; i >= 0 ; i--){
            for(j = 0; j <= i; j++){
	    result = data + (1<<j);
	    *((int*)led_ptr) = result;
	  
	    delay (500000)
	    }
	    data += (1<<i);
	  }
          data = 0;	
	  usleep(10*1000);
  }

  if(munmap(VA, HW_SPAN) != 0){
    printf("ERROR: munmap() failed... \n");
    close(fd);
    return 1;
  }

  close(fd);
  return 0;
}
