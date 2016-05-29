#define IMG_SIZE  19600  //78400
#define LABEL_SIZE 400
#define B1	200
#define B2	200
#define W1	784*200
#define W2	200*200
#define W3  10*200
///////SDRAM mapping
#define HW_BASE 0xC0000000
#define HW_SPAN 0x40000000
#define HW_MASK HW_SPAN-1
#define HW_OFST 0xC0000000
///////start and done mapping
#define ALT_LWFPGASLVS_OFST 0xff200000
#define HW_REGS_SPAN 0x04000000
#define HW_REGS_BASE 0xfc000000
#define HW_REGS_MASK HW_REGS_SPAN-1
/* Include files */


#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <time.h>
#include <math.h>

short int round_testData(float x)
{
  short int a = 0;
  if(x > 0.000001 || x == 0.000001)
    a = 1;
  else 
    a = 0;
  return a;
}

//*********************************************************************************************************************************
int Multiplication_layer3(void *SDRAMBASE, int x )
{
  int index = 0;
  short int max = -128;
  short int Z3; 
  short int temp;
  int i0;
  int i;
  for (i = 0; i < 10; i++) 
  {
    Z3= 0;
    for (i0 = 0; i0 < 200; i0++) 
    {
	temp= ((short int*)SDRAMBASE)[i0 + 200 * i+IMG_SIZE+LABEL_SIZE+B1+B2+(W1/4)+(W2/4)];
	Z3 += temp * ((short int*)SDRAMBASE)[i0+200*x+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4+W2/4+W3+400*200/4];
    }

    if (Z3 > max) 
    {
      max = Z3;
      index = i + 1;
    }
  }
  return index;
}



void readImage(void *SDRAMBASE, int num, int m)
{
	char filename[40];
	int i = 0;
	float a;
	unsigned short int b;
	unsigned short int c =0;
	int n = 0;
	int j = 0;
	FILE *img_file;
	
	snprintf(filename, sizeof(filename), "./Sample/%d.txt", num);
	
	img_file = fopen(filename,"r");
	
	for (n = 0; n < 784; n++)
	{
		fscanf(img_file, "%f", &a);
		b = round_testData(a);
		
		if( (n%16) == 0)
		  c = b;
		if ( (n%16) == 1)
		  c = c | (b << 1);
		if( (n%16) == 2)
		  c = c | (b << 2);
		if((n%16) == 3)
			c = c | (b << 3);
		if((n%16) == 4)
			c = c | (b << 4);
		if((n%16) == 5)
			c = c | (b << 5);
		if((n%16) == 6)
			c = c | (b << 6);
		if((n%16) == 7)
			c = c | (b << 7);
		if((n%16) == 8)
			c = c | (b << 8);
		if((n%16) == 9)
			c = c | (b << 9);
		if((n%16) == 10)
			c = c | (b << 10);
		if((n%16) == 11)
			c = c | (b << 11);
		if((n%16) == 12)
			c = c | (b << 12);
		if((n%16) == 13)
			c = c | (b << 13);
		if((n%16) == 14)
			c = c | (b << 14);
		if((n%16) == 15)
		{
			c = c | (b << 15);
			((short int*)SDRAMBASE)[j+m*49] = c ;
			j++;
			c = 0;
		}
	}
				
	fclose(img_file);
}


int main()
{
	
	void *VA, *LW;
	int fd;
	
	int n;
	clock_t timer;
	clock_t timer2;
	
	
	void *SDRAMBASE;
	void *start;
	void *done;
	
	float a;
	float correct;
	float accuracy;
	short int b;
	int x;
	int i;
	int i0;
	short int index;
	int counter = 0;
	short int Weight1;
	short int Weight2;
	short int Weight3;
	short int d =0;
	int finish =0;

	
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

	LW = mmap(NULL, HW_REGS_SPAN, (PROT_READ|PROT_WRITE), MAP_SHARED, fd, HW_REGS_BASE);
	if (LW == MAP_FAILED){
    		printf("ERROR: mmap() failed... \n");
    		close(fd);
    		return (1);
 	 }
	SDRAMBASE = VA+((unsigned long)(HW_BASE + 0x00)&(unsigned long)(HW_MASK));
	done = LW + ((unsigned long)(ALT_LWFPGASLVS_OFST + 0x90)&(unsigned long)(HW_REGS_MASK));
	start = LW + ((unsigned long)(ALT_LWFPGASLVS_OFST + 0x80)&(unsigned long)(HW_REGS_MASK));
	//**************************************************************
	timer = clock();
	//Store image to sdram
	//store 2 pixels to each sdram location
	for( n = 0; n < 400 ; n++)
	{ 
		readImage(SDRAMBASE, n+1, n);
	}

	
	
	//store testLabel to sdram
	//sore 1 pixel to each sdram location 
	//snprintf(filename, sizeof(
	FILE *label_file;
	label_file = fopen("./Sample/labels.txt","r");
	if(label_file == NULL)
	{
		printf("file open fail\n");
		return -1;
	}else{
	for (n = 0; n<(LABEL_SIZE); n++)
	{ 
	  fscanf(label_file, "%hi", &(((short int*)SDRAMBASE)[n+IMG_SIZE]));
	
	}}
	
	//*****************************************************************
	
	//store B1 to sdram
	//store 2 pixels to each sdram location

	FILE *B1_file;
	B1_file = fopen("newB1.txt","r");
	for (n = 0; n<(B1); n++)
	{
		fscanf(B1_file, "%hi",  &(((short int*)SDRAMBASE)[n+IMG_SIZE+LABEL_SIZE]));
		
	}
 	
	
	//**********************************************************************************
	//store B2 to sdram
	//store 1 pixel to each sdram location
	FILE *B2_file;
	B2_file = fopen("newB2.txt","r");
	for (n = 0; n<(B2); n++)
	{
	  fscanf(B2_file, "%hi",  &(((short int*)SDRAMBASE)[n+IMG_SIZE+LABEL_SIZE+B1]));
	}

	//**********************************************************************************
	//store W1 to sdram
	//store 2 pixels to each sdram location
	FILE *W1_file;
	W1_file = fopen("newW1.txt","r");
	for (n = 0; n<(W1); n++)
	{
		//fscanf(W1_file, "%hi", &(((short int*)SDRAMBASE)[n+IMG_SIZE+LABEL_SIZE+B1+B2]));
		
		fscanf(W1_file, "%hi",  &Weight1);
		
		if( (n % 4) == 0)
		  d = (Weight1 & 0x000F) ;	
		if ( (n % 4) == 1)
		  d = d | (Weight1 & 0x000F) << 4; // 4
		if ( (n % 4) == 2)
		  d = d | (Weight1 & 0x000F) << 8; // 8
		if ( (n % 4) == 3)
		{
		  d = d | (Weight1 & 0x000F) << 12; // 12
		  ((short int*)SDRAMBASE)[counter+IMG_SIZE+LABEL_SIZE+B1+B2] = d;
		  counter = counter + 1;
		  d = 0;
		}
		
		
	}
	
	
	
	
	//*******************************************************************************
	//store W2 to sdram
	//store 1 pixel to each sdram location
	d =0;
	counter = 0;
	FILE *W2_file;
	W2_file = fopen("newW2.txt","r");
	for (n = 0; n<(W2); n++)
	{
		fscanf(W2_file, "%hi", &Weight2);
		
		if( (n % 4) == 0)
		  d = (Weight2 & 0x000F) ;	
		if ( (n % 4) == 1)
		  d = d | (Weight2 & 0x000F) << 4; // 4
		if ( (n % 4) == 2)
		  d = d | (Weight2 & 0x000F) << 8; // 8
		if ( (n % 4) == 3)
		{
		  d = d | (Weight2 & 0x000F) << 12; // 12
		  ((short int*)SDRAMBASE)[counter+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4] = d;
		  counter = counter + 1;
		  d = 0;
		}
		
	}
	

	//*********************************************************************************
	//store W3 to sdram
	//store 1 pixel to each sdram location
	d =0;
	counter = 0;
	FILE *W3_file;
	W3_file = fopen("newW3.txt","r");
	for (n = 0; n<(W3); n++)
	{
		fscanf(W3_file, "%hi", &(((short int*)SDRAMBASE)[n+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4+W2/4]));
		//fscanf(W3_file, "%hi", &Weight3);
	/*	if( (n % 4) == 0)
		  d = (Weight3 & 0x000F) ;	
		if ( (n % 4) == 1)
		  d = d | (Weight3 & 0x000F) << 4; // 4
		if ( (n % 4) == 2)
		  d = d | (Weight3 & 0x000F) << 8; // 8
		if ( (n % 4) == 3)
		{
		  d = d | (Weight3 & 0x000F) << 12; // 12
		  ((short int*)SDRAMBASE)[counter+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4+W2/4] = d;
		  counter = counter + 1;
		  d = 0;
		}*/
	}

	
	timer2 = clock();
	
	//start verilog machine
	*(int*)start = 1;
	
	//printf("done is %d\n", *(int*)done);

	while(!(*(int*)done))
	{ 
		
	}
	timer2 = clock() - timer2;
	*(int*)start = 0;

	
	//end verilog machine

	for (x = 0; x < 400; x++) 
	{
	
		// CALCULATE L1 dataTimeweightS
		//Multiplication_layer1 (SDRAMBASE,x);
		
		
		// CALCULATE L2 dataTimeweightS
		//Multiplication_layer2 (SDRAMBASE);
		
	
		// CALCULATE L3 dataTimeweightS 
		index = Multiplication_layer3(SDRAMBASE,x);
		
		((short int*)SDRAMBASE)[x+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4+W2/4+W3+400*200/4 + 400*200] = (short int)index;
		
	}
        

	timer = clock() - timer;
	// caculate the accuracy 
	correct = 0.0;
	for(i = 0; i < 400; i++) {
		if ( ((short int*)SDRAMBASE)[IMG_SIZE+i] == ((short int*)SDRAMBASE)[i+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4+W2/4+W3+400*200/4 + 400*200] ) {
		  correct++;
		}
	}
	printf("correct is %f\n", correct);
	accuracy = correct/ 400.0;  


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	
	
	float time_taken = ((float)timer)/CLOCKS_PER_SEC;
        float time_taken2 = ((float)timer2)/CLOCKS_PER_SEC;
	
	printf("accuracy is %f percent\n", accuracy*100);
	printf("execution time is %f seconds\n", time_taken);
	printf("machine time is %f seconds\n", time_taken2);
	 
	//fclose(img_file);
	fclose(label_file);
	fclose(B1_file);
	fclose(B2_file);
	fclose(W1_file);
	fclose(W2_file);
	fclose(W3_file);
	
        if (munmap(VA, HW_SPAN) != 0)
	{
		printf("ERROR: munmap() failed... \n");
		close(fd);
		return 1;
	}
        if (munmap(LW, HW_REGS_SPAN) != 0)
	{
		printf("ERROR: munmap() failed... \n");
		close(fd);
		return 1;
	}
	close(fd);
	munmap(LW, HW_REGS_SPAN);
	munmap(SDRAMBASE, HW_SPAN);
	return 0;
}	
	
