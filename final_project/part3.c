#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>

#include "rt_nonfinite.h"
#include "test1.h"
#include "rand.h"
#include <stdio.h>
#include <math.h>

//include vector header file
#include "vector.h"

#define HW_BASE 0xFC000000
#define HW_SPAN 0x04000000
#define HW_MASK (HW_SPAN - 1)
//#define OUTPUT_SEVEN_SEGMENT_COMPONENT_TYPE seven_segment

static double rt_roundd_snf(double u);

/* Function Definitions */

/*
 * Arguments    : double u
 * Return Type  : double
 */
static double rt_roundd_snf(double u)
{
  double y;
  if (fabs(u) < 4.503599627370496E+15) {
    if (u >= 0.5) {
      y = floor(u + 0.5);
    } else if (u > -0.5) {
      y = u * 0.0;
    } else {
      y = ceil(u - 0.5);
    }
  } else {
    y = u;
  }

  return y;
}

/*
 * Lenna = imread('Lenna.jpg');
 * figure;
 * imshow(Lenna)
 * lenna_gray = rgb2gray(Lenna);
 * Arguments    : const unsigned char lenna_gray[160000]
 *                unsigned char D[158404]
 * Return Type  : void
 */
void test1(const unsigned char lenna_gray[160000], unsigned char D[158404])
{
  static double unusedExpr[158404];
  int row;
  int col;
  double sumx;
  double sumy;
  int i;
  int j;
  static const signed char Gx[9] = { -1, -2, -1, 0, 0, 0, 1, 2, 1 };

  static const signed char Gy[9] = { 1, 0, -1, 2, 0, -2, 1, 0, -1 };

  unsigned char u0;

  /* %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% */
  //rand(unusedExpr);
  
  //get rid of rand
  
  //is this right??? look up on google
  for (row = 0; row < 398; row++) {
    for (col = 0; col < 398; col++) {
      sumx = 0.0;
      sumy = 0.0;
      for (i = 0; i < 3; i++) {
        for (j = 0; j < 3; j++) {
          sumx += (double)(lenna_gray[(row + i) + 400 * (col + j)] * Gx[i + 3 *
                           j]);
          sumy += (double)(lenna_gray[(row + i) + 400 * (col + j)] * Gy[i + 3 *
                           j]);
        }
      }

      sumx = rt_roundd_snf(fabs(sumx) + fabs(sumy));
      if (sumx < 256.0) {
        u0 = (unsigned char)sumx;
      } else {
        u0 = MAX_uint8_T;
      }

      D[row + 398 * col] = u0;
    }
  }

  /* figure; */
  /* imshow (D) */
  
  // matlab stuff here
}

/*
 * File trailer for test1.c
 *
 * [EOF]
 */
void print_array(unsigned char* array, int MAX_ELEMENT)
{
	FILE* fp;
	char output[] = "array2.txt";
  	int i;
	fp = fopen(output,"w+");
	for (i=0; i < MAX_ELEMENT; i++)
	{
	  fprintf(fp, "%u,", array[i]);
	}
	fclose(fp);
}

int main()
{
	unsigned char D_vector[158404];
	test1(vector, D_vector);
	int w = 0;
	int MAX_ELEMENT = 158404;
	printf("start ");
	for (w = 0; w < 158404; w++)
	{
	  printf("%u,", D_vector[w]);
	}

	print_array(D_vector, MAX_ELEMENT);

	return 0;

}

int delay(unsigned int mseconds)
{
  clock_t goal = mseconds + clock();
  while (goal > clock());
}

int main(){
  void *VA, *led_ptr, *sdram;
  int fd;
  int result;
  unsigned int data = 0;
  int i;
  int j;
  
  unsigned char D_vector[158404];
  test1(vector, D_vector);
  int w = 0;
  int MAX_ELEMENT = 158404;

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

  //led_ptr = VA + ((unsigned long)(0xff200000 + 0x80) & (unsigned long)(HW_MASK));
  sdram = VA + ((unsigned long)(HW_BASE + 0x00) & (unsigned long)(HW_MASK));
 

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
  
	*((unsigned char*)sdram) = D_vector;
	
	//printf("start ");
	
	/*for (w = 0; w < 158404; w++)
	{
	  printf("%u,", D_vector[w]);
	}*/

	print_array(D_vector, MAX_ELEMENT);


  if(munmap(VA, HW_SPAN) != 0){
    printf("ERROR: munmap() failed... \n");
    close(fd);
    return 1;
  }

  close(fd);
  return 0;
}
