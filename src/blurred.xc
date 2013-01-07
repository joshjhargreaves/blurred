/////////////////////////////////////////////////////////////////////////////////////////
//
// COMS20600 - WEEKS 9 to 12
// ASSIGNMENT 3
// CODE SKELETON
// TITLE: "Concurrent Image Filter"
//
/////////////////////////////////////////////////////////////////////////////////////////
typedef unsigned char uchar;

#include <platform.h>
#include <stdio.h>
#include "pgmIO.h"
#define IMHT 256
#define IMWD 400
#define noWorkers 4
#define bufferWidth (IMWD/noWorkers)+2
#define divided IMWD/noWorkers
char infname[] = "C:\\Users\\Josh\\Documents\\cimages\\BristolCathedral.pgm"; //put your input image path here
char outfname[] = "C:\\Users\\Josh\\Documents\\cimages\\output.pgm"; //put your output image path here
out port cled[4] = {PORT_CLOCKLED_0,PORT_CLOCKLED_1,PORT_CLOCKLED_2,PORT_CLOCKLED_3};
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port  buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

typedef struct {
	int p1,p2,p3,
		p4,p5,p6,
		p7,p8;
}pixels;

void buttonListener(in port buttons, chanend toDistributor) {
	//ABCD 14 13 11 7
	int buttonInput;            //button pattern currently pressed
	unsigned int running = 1;   //helper variable to determine system shutdown
	while (running) {
		buttons when pinsneq(15) :> buttonInput;
		///////////////////////////////////////////////////////////////////////
		//
		//   ADD YOUR CODE HERE TO ACT ON BUTTON INPUT
		//
		toDistributor <: buttonInput;
		toDistributor :> running;	//receives 1 unless shutdown (0)
		//waitMoment(25000000);       //ensures button press read once only; 25000000-50000000 works, 15000000 works best
		///////////////////////////////////////////////////////////////////////
	}
	printf("Button not running\n");
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void worker(chanend c_in, chanend c_out, int id) {
	int temp1 = 0;
	int running = 1;
	int result = 0;
	uchar tempArray[3][bufferWidth];
	int width = bufferWidth;
	int counter = 0;
	if(id==0 || id == noWorkers-1) {
		width--;
	}
	for(int j=0;j<IMHT;j++) {
		int plusOne = (j)%3;
		int minusOne = (j-2)%3;
		int currentLine = (j-1)%3;
		for(int k=0;k<width;k++) {
			c_in :> temp1;
			tempArray[j%3][k] = (uchar)temp1;
		}
		if(j>=2) {
			result = 0;
			for(int i=1;i<width-1;i++) {
				int temp = (i-1)%4;
				result = (int)tempArray[currentLine][i-1] + (int)tempArray[minusOne][i-1] + (int)tempArray[minusOne][i]
							+ (int)tempArray[minusOne][i+1] + (int)tempArray[currentLine][i+1] + (int)tempArray[plusOne][i+1]
							 + (int)tempArray[plusOne][i] + (int)tempArray[plusOne][i-1] + (int)tempArray[currentLine][i];
				c_out <: (uchar)(result/9);
			}
		}
	}
	//printf("worker done\n");
}
void collector(chanend fromWorkers[], chanend c_out) {
	uchar black = 0;
	int number = 0;
	uchar tempValue1, tempValue2;
	for(int i=0;i<IMWD;i++) {
		c_out <: black;
		number++;
	}
	for(int j=1;j<IMHT-1;j++) {
		int worker = 0;
		int total = divided;
		c_out <: black;
		for (int x = 0; x < IMWD-2; x++) {
			if(x == total-1 ) {
				worker++;
				total = (worker+1)*divided;
			}
			//printf("worker = %d\n", worker);
			fromWorkers[worker] :> tempValue1;
			c_out <: tempValue1;
		}
		c_out <: black;
	}
	for(int i=0;i<IMWD;i++) {
		c_out <: black;
	}
}
void DataInStream(char infname[], chanend c_out) {
	int res;
	uchar line[IMWD];
	printf("DataInStream:Start...\n");
	res = _openinpgm(infname, IMWD, IMHT);
	if (res) {
		printf("DataInStream:Error openening %s\n.", infname);
		return;
	}
	for (int y = 0; y < IMHT; y++) {
		_readinline(line, IMWD);
		for (int x=0; x<IMWD; x++) {
			c_out  <: line[ x ];
		//printf( "-%4.1d ", line[ x ] ); //uncomment to show image values
		}
	//printf( "\n" ); //uncomment to show image values
	}
	_closeinpgm();
	//printf( "DataInStream:Done...\n" );
	return;
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out[]) {
	uchar val;
	int currentLine = 1;
	uchar tempArray[3][IMWD];
	uchar tempValue;
	int flag = 0;
	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);
	//This code is to be replaced – it is a place holder for farming out the work...
	for (int y = 0; y < IMHT; y++) {
		int plusOne = (y)%3;
		int minusOne = (y-2)%3;
		int worker = 0, count = 0, total = 0;
		int workers = 0;
		currentLine = (y-1)%3;
		flag = 0;
		total = divided;
		for (int x = 0; x < IMWD; x++) {
			c_in :> tempValue;
			if(flag) {
				c_out[(workers)-1] <: (int)tempValue;
				flag = 0;
			}
			if(x+1 >= total && workers+1<noWorkers) {
				workers++;
				total = (workers+1)*divided;
				flag = 1;
			}
			c_out[workers] <: (int)tempValue;
			if(flag) {
				c_out[workers-1] <: (int)tempValue;

			}
			//c_out <: (uchar)( val ^ 0xFF ); //Need to cast
		}
	}
	/*for(int i=0;i<noWorkers;i++) {
		c_out[i] <: 1000;
	}*/
	printf( "ProcessImage:Done...\n" );
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in) {
	int res;
	uchar line[IMWD];
	printf("DataOutStream:Start...\n");
	res = _openoutpgm(outfname, IMWD, IMHT);
	if (res) {
		printf("DataOutStream:Error opening %s\n.", outfname);
		return;
	}
	for (int y = 0; y < IMHT; y++) {
		for (int x = 0; x < IMWD; x++) {
		c_in :> line[ x ];
		//printf( "+%4.1d ", line[ x ] );
	}
	//printf( "\n" );
	_writeoutline( line, IMWD );
}
	_closeoutpgm();
	printf( "DataOutStream:Done...\n" );
	return;
}
//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
	chan c_inIO, c_outIO; //extend your channel definitions here
	chan distributorToWorkers[noWorkers];
	chan workerToCollector[noWorkers];
	par //extend/change this par statement to implement your concurrent filter
	{
		on stdcore[1] : DataInStream( infname, c_inIO );
		on stdcore[1] : distributor( c_inIO, distributorToWorkers);
		on stdcore[3] : collector(workerToCollector, c_outIO);
		on stdcore[3]:DataOutStream( outfname, c_outIO );
		par (int k = 0; k<noWorkers; k++) {
			on stdcore[k%4]: worker(distributorToWorkers[k],workerToCollector[k], k);
		}

		//printf("Main:Done...\n");
	}
	return 0;
}
