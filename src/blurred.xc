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
#define IMHT 16
#define IMWD 16
#define noWorkers 4
#define bufferWidth (IMHT/noWorkers)+2
char infname[] = "C:\\Users\\Josh\\Documents\\cimages\\test0.pgm"; //put your input image path here
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
	int buffer[bufferWidth][IMWD];
	int temp = bufferWidth-1;
	if(id == 0 || id == (noWorkers-1)) {
		int temp = bufferWidth-1;
	}
	for(int i=0;i<temp;i++) {
		for(int j=0;j<IMWD;j++) {
			c_in :> buffer[i][j];
		}
	}
	temp--;
	for(int i=1;i<temp;i++) {
		for(int j = 1;j<IMWD-1;j++) {
			c_out <: (buffer[i][j-1] + buffer[i-1][j-1] + buffer[i-1][j] + buffer[i-1][j+1]
								 + buffer[i][j+1] + buffer[i+1][j+1] + buffer[i+1][j] + buffer[i+1][j-1])/8;
		}
	}
}
void collector(chanend fromWorkers[], chanend c_out) {

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
		for (int x = 0; x < IMWD; x++) {
			c_out  <: line[ x ];
		//printf( "-%4.1d ", line[ x ] ); //uncomment to show image values
	}
	//printf( "\n" ); //uncomment to show image values
}
_closeinpgm();
printf( "DataInStream:Done...\n" );
return;
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to farm out parts of the image...
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend c_out[]) {
	uchar val;
	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);
	//This code is to be replaced – it is a place holder for farming out the work...
	for (int y = 0; y < IMHT; y++) {
		for (int x = 0; x < IMWD; x++) {
			c_in :> val;
			//c_out <: (uchar)( val ^ 0xFF ); //Need to cast
		}
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
		on stdcore[0] : DataInStream( infname, c_inIO );
		on stdcore[0] : distributor( c_inIO, distributorToWorkers);
		on stdcore[3] : collector(workerToCollector, c_outIO);
		on stdcore[0]:DataOutStream( outfname, c_outIO );
		par (int k = 0; k<noWorkers; k++) {
			on stdcore[k%4]: worker(distributorToWorkers[k],workerToCollector[k], k);
		}

		//printf("Main:Done...\n");
	}
	return 0;
}
