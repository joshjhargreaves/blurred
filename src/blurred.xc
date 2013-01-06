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
#define bufferWidth (IMHT/noWorkers)+2
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
	while(running) {
		for(int i=0;i<9;i++) {
			int temp2;
			c_in :> temp2;
			if(temp2 == 1000)
				break;
			temp1 = (temp1 + temp2);
		}
		c_out <: (uchar)(temp1/9);
		temp1 = 0;
	}
}
void collector(chanend fromWorkers[], chanend c_out) {
	uchar black = 0;
	int number = 0;
	for(int i=0;i<IMWD;i++) {
		c_out <: black;
		number++;
	}
	for(int j=1;j<IMHT-1;j++) {
		c_out <: black;
		number++;
		for(int i=1;i<IMWD-1;i++) {
			uchar temp = black;
			fromWorkers[(i-1)%4] :> temp;
			c_out <: temp;
			number++;
		}
		c_out <: black;
		number++;
		//printf("Number of pixels written %d\n", number);
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
	uchar tempArray[3][IMWD];
	int currentLine = 1;
	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);
	//This code is to be replaced – it is a place holder for farming out the work...
	for (int y = 0; y < IMHT; y++) {
		int plusOne = (y)%3;
		int minusOne = (y-2)%3;
		currentLine = (y-1)%3;
		for (int x = 0; x < IMWD; x++) {
			c_in :> tempArray[y%3][x];

			//c_out <: (uchar)( val ^ 0xFF ); //Need to cast
		}
		if(y >= 2) {
			for(int i=1;i<IMWD-1;i++) {
				int temp = (i-1)%4;
				c_out[temp] <: (int)tempArray[currentLine][i-1];
				c_out[temp] <: (int)tempArray[minusOne][i-1];
				c_out[temp] <: (int)tempArray[minusOne][i];
				c_out[temp] <: (int)tempArray[minusOne][i+1];
				c_out[temp] <: (int)tempArray[currentLine][i+1];
				c_out[temp] <: (int)tempArray[plusOne][i+1];
				c_out[temp] <: (int)tempArray[plusOne][i];
				c_out[temp] <: (int)tempArray[plusOne][i-1];
				c_out[temp] <: (int)tempArray[currentLine][i];
			}
			currentLine = (currentLine + 1)%3;
		}
	}
	for(int i=0;i<noWorkers;i++) {
		c_out[i] <: 1000;
	}
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
