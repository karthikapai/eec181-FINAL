#define IMG_SIZE  78400
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

short int round_Z(float x)
{
  short int a = 0;
  if(x > 0.4 || x == 0.4)
    a = 1;
  else
    a = 0;
  return a;
}

//****************************************************************************************************************************
// CALCULATE L1 dataTimeweightS
void Multiplication_layer1(short int *Z1, void *SDRAMBASE, int x)
{ 
  short int Timeweight;
  int i0;
  
  float Z1_array[200];	
 
	
  for (i0 = 0; i0 < 200; i0++) 
  {												  
    Z1[i0] =  (((short int*)SDRAMBASE)[IMG_SIZE + LABEL_SIZE + B1 + B2 + (W1/4) + W2 + W3 + 200*x + i0]);
   
  }
 
  
		
  for (i0 = 0; i0 < 200; i0++) 
  { 

    Z1_array[i0] = 1.0 / (1.0 + exp((float)(-Z1[i0])));
    Z1[i0] = round_Z(Z1_array[i0]);
  }
}
//**************************************************************************************************************************
void Multiplication_layer2(float *Z2, void *SDRAMBASE, short int *Z1)
{
	
  short int dataTimeweight2;
  short int temp[200];
  int i0;
  int i;
 

  for (i0 = 0; i0 < 200; i0++) 
  {
    dataTimeweight2 = 0;
    for (i = 0; i < 200; i++) 
    {
      dataTimeweight2 += ((short int*)SDRAMBASE)[IMG_SIZE+LABEL_SIZE+B1+B2+(W1/4)+i + 200*i0] * Z1[i];
    }
    temp[i0] = dataTimeweight2 + ((short int*)SDRAMBASE)[i0+IMG_SIZE+LABEL_SIZE+B1];
	
 }

  for (i0 = 0; i0 < 200; i0++) 
  {
    Z2[i0] = 1.0 / (1.0 + exp((float)(-temp[i0])));
    
  }		
}

//*********************************************************************************************************************************
int Multiplication_layer3(float *Z2, void *SDRAMBASE )
{
  int index = 0;
  float max = -128.0;
  float Z3[10]; 
  short int temp[200];
  int i0;
  int i;
  for (i = 0; i < 10; i++) 
  {
    Z3[i] = 0;
    for (i0 = 0; i0 < 200; i0++) 
    {
	temp[i0]= ((short int*)SDRAMBASE)[i0 + 200 * i+IMG_SIZE+LABEL_SIZE+B1+B2+(W1/4)+W2];
	Z3[i] += (float)(temp[i0]) * (Z2[i0]);
    }
			//index = Comparation(Z3[i], i);
    if (Z3[i] > max) 
    {
      max = Z3[i];
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
		
		if( (n%4) == 0)
		  c = b;
		if ( (n%4) == 1)
		  c = c | (b << 4);
		if( (n%4) == 2)
		  c = c | (b << 8);
		if ( (n%4) == 3){
		  c = c | (b << 12);
		  ((short int*)SDRAMBASE)[j+m*196] = c ;
		  j++;
		  c = 0;
		}
	}
				
	fclose(img_file);
}


int main()
{
	
	
	int result[400];
	short int Z1[200];
	float Z2[200];
	float Z3[10];

	
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
	int index;
	int counter = 0;
	short int img[IMG_SIZE];
	short int label[LABEL_SIZE];
	short int Bias1;
	short int Bias2[B2];
	short int Weight1;
	short int d =0;
	short int Weight2[W2];
	short int Weight3[W3];
	//short int mask = 0x00F;
	
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
		  if(n == 3)
		    printf("d is %hx\n", d);
		  d = 0;
		}
		
		
	}
	
	
	printf("w1 is %hx\n", ((short int*)SDRAMBASE)[57+IMG_SIZE+LABEL_SIZE+B1+B2]);
	
	//*******************************************************************************
	//store W2 to sdram
	//store 1 pixel to each sdram location
	
	FILE *W2_file;
	W2_file = fopen("newW2.txt","r");
	for (n = 0; n<(W2); n++)
	{
		fscanf(W2_file, "%hi", &(((short int*)SDRAMBASE)[n+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4]));
	}
	

	//*********************************************************************************
	//store W3 to sdram
	//store 1 pixel to each sdram location
	FILE *W3_file;
	W3_file = fopen("newW3.txt","r");
	for (n = 0; n<(W3); n++)
	{
		fscanf(W3_file, "%hi", &(((short int*)SDRAMBASE)[n+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4+W2]));
	}

	timer = clock();
	timer2 = clock();
	
	//start verilog machine
	*(int*)start = 1;
	
	printf("done is %d\n", *(int*)done);

	while(!(*(int*)done))
	{ 
		
	}
	*(int*)start = 0;

	timer2 = clock() - timer2;
	

	/*for(n = 10; n < 20; n++)
	{
		printf("%d\n",((short int*)SDRAMBASE)[n+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4+W2+W3]); 
	}*/
	//end verilog machine

	for (x = 0; x < 400; x++) 
	{
	
		// CALCULATE L1 dataTimeweightS
		Multiplication_layer1 (Z1, SDRAMBASE,x);
		
		
		// CALCULATE L2 dataTimeweightS
		Multiplication_layer2 (Z2, SDRAMBASE, Z1);
		
	
		// CALCULATE L3 dataTimeweightS 
		index = Multiplication_layer3(Z2, SDRAMBASE);
	
		result[x] = index;  
	}
        
	

	for (i = 0; i < 400; i++)
	{
		
		((short int*)SDRAMBASE)[i+IMG_SIZE+LABEL_SIZE+B1+B2+W1/4+W2+W3+400*200] = (short int)result[i];
	}

	timer = clock() - timer;
	// caculate the accuracy 
	correct = 0.0;
	for(i = 0; i < 400; i++) {
		if ((((short int*)SDRAMBASE)[IMG_SIZE+i]) == (short int)result[i]) {
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
	
