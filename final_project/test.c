#include <stdio.h>
#include <stdlib.h>
#include <time.h>


/*
int main(void)
 {
	 int array[1000];
	 int * address = (int *)0xC4000000;   // fpga on-chip memory
	 
	 int i = 0;
	int fakeCounter = 0;
	initCounters ()
		
	// RAM 00;
	//volatile int * sdram		 		=(int *) 0xC4000000;
	//volatile int * hex_led 			=(int *) 0xFF200028;
	
	//while(1) 
	//{
//		clock_t diff, readtime;
	//	clock_t start, end;
		
	//	int i=0;
		while(i<1000)
		{
			array[i]= 1;
			i++;
		}
		//start = clock(); //start
		int count=0;
		while(count<1000)
		{
			*(address) =array[count];
			*(address) =*(address) +4;
			count++;
		}
		
		unsigned int time = getCycles();
		for (i = 0; i < 20000; i++)
fakeCounter = fakeCounter + 1;
time = getCycles() - time;
printf ("Elapsed Time: %d cycles\n", time);
time = getCycles();
		//end = clock();
		//diff = (end-start)/CLOCKS_PER_SEC;
		//printf("write time");
		//printf("%d\n", diff);
		
	/*	start = clock(); //start
		int y = 0;
		while(y<1000)
		{
			array[y]=*(address);
			*(address) =*(address) -4;
			y++;
		}
		end = clock();
		readtime = (end-start)/CLOCKS_PER_SEC;
		
		int n=0;
		while(n<8000)
		{
			//output= *(sdram[n]);
			printf("%d\n", array[n]);
			n++;
		}
		//readtime = (clock()-end)/CLOCKS_PER_SEC;
		printf("Read time");
		printf("%d\n", readtime); 
	//}
	return 0;
 }*/
	
static inline unsigned int getCycles ()
{
	unsigned int cycleCount;
 // Read CCNT register
	asm volatile ("MRC p15, 0, %0, c9, c13, 0\t\n": "=r"(cycleCount));
	return cycleCount;
}

static inline void initCounters ()
{
 // Enable user access to performance counter
	asm volatile ("MCR p15, 0, %0, C9, C14, 0\t\n" :: "r"(1));
 // Reset all counters to zero
	int MCRP15ResetAll = 23;
	asm volatile ("MCR p15, 0, %0, c9, c12, 0\t\n" :: "r"(MCRP15ResetAll));
 // Enable all counters:
	asm volatile ("MCR p15, 0, %0, c9, c12, 1\t\n" :: "r"(0x8000000f));
 // Disable counter interrupts
	asm volatile ("MCR p15, 0, %0, C9, C14, 2\t\n" :: "r"(0x8000000f));
 // Clear overflows:
	asm volatile ("MCR p15, 0, %0, c9, c12, 3\t\n" :: "r"(0x8000000f));
}

int main(void)
{
	static int array[8000];
	
	int baseAddress = 0;
	//volatile int *address = 0;
	//unsigned int input = 0;
	int readdata;
	int mode = 0;
	int count = 0;
	int i = 0;
	int fakeCounter = 0;
	int lostData = 0;
	
	initCounters ();

	printf("Enter 1 for FPGA on-chip \n 2 for FPGA SDRAM \n 3 for HPS DDR3 SDRAM \n 4 for HPS On-Chip Memory\n");
	scanf("%d", &mode);
	
	if (mode == 1)
		baseAddress = 0xC0000000;
	if (mode == 2)
		baseAddress = 0xC4000000;
	if (mode == 3)
		baseAddress = 0x00100000;
	if (mode == 4)
		baseAddress = 0xFFFF0000;
	
	volatile int *address = (int*) baseAddress;
	//*address = *baseAddress;
	
	unsigned int time = getCycles();
	for (count = 0; count < 8000; count++)
	{
		*(address) = count;
		address = address+1;
		array[count] = count;
		fakeCounter = fakeCounter + 1;
	}

	time = getCycles() - time;
	printf ("Write Time: %d cycles\n", time);
	//printf ("array is %d \n", array[0]);
	//printf ("array is %d \n", array[1]);
	//printf ("array is %d \n", array[1000]);
	//printf ("count is %d", count);
	address = baseAddress;	
	
	time = getCycles();	
	for ( i = 0; i < count; i++)
	{
		readdata = *(address + i);
		
		//printf ("read data is %d", readdata);
		if(readdata != array[i])
			lostData = lostData + 1;
	}
	time = getCycles() - time;
	printf ("Read Time: %d cycles\n", time);
	printf ("Lost Data is %d \n", lostData);
	//printf("The stored data is: %d", *(address*/
	
	return 0;

}

	
