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
#define bufferWidth (IMWD/noWorkers)+2
#define selection (IMWD/noWorkers)
#define divided IMWD/noWorkers
#define SHUTDOWN 1000000
#define noBlurs 20
#define INIT 12341234
//#define USB
char infname[] = "C:\\Users\\Josh\\Documents\\cimages\\test0.pgm"; //put your input image path here
char outfname[] = "C:\\Users\\Josh\\Documents\\cimages\\output.pgm"; //put your output image path here
char tempFile1[] = "C:\\Users\\Josh\\Documents\\cimages\\temp1.pgm";
char tempFile2[] = "C:\\Users\\Josh\\Documents\\cimages\\temp2.pgm";
out port cled[4] = {PORT_CLOCKLED_0,PORT_CLOCKLED_1,PORT_CLOCKLED_2,PORT_CLOCKLED_3};
out port cledG = PORT_CLOCKLED_SELG;
out port cledR = PORT_CLOCKLED_SELR;
in port  buttons = PORT_BUTTON;
out port speaker = PORT_SPEAKER;

//DISPLAYS an LED pattern in one quadrant of the clock LEDs
void showLED(out port p, chanend fromDataIn) {
	unsigned int lightUpPattern;
	unsigned int running = 1;
	while (running) {
		select {
		case fromDataIn :> lightUpPattern: //read LED pattern from visualiser process
			if (lightUpPattern == SHUTDOWN)
				running = 0;
			else p <: lightUpPattern;          //send pattern to LEDs
			break;
		default:
			break;
		}
	}
}

//Waits a specified amount of time
void waitMoment(uint myTime) {
	timer Timer;
	uint waitTime;
	Timer :> waitTime;
	waitTime += myTime;
	Timer when timerafter(waitTime) :> void;
}

//displays the progress of the blur on the lights on the board
void visualiser(chanend c_in, chanend toQuadrant[]) {
	int progress = 0, running = 1, i;
	//sets the colour to red
	cledR <: 1;
	//the visualiser keeps running until it reads a shutdown
	while (running) {
		c_in :> i;
		if (i == SHUTDOWN) {
			running = 0;
		} else {
			//works out how many leds to light up proportionate to
			//how much of the image has been processed
			progress = 12 * i/IMHT;
			i = (1 << progress) - 1;
			//sends the correct light up pattern to the corrects quadrants
			for (int j = 0; j < 4; j++) {
				toQuadrant[j] <: (((i>> (3 * j)) & 0b111)) << 4;
			}
		}
	}
	//tells all quadrants to shutdown
	for (int j = 0; j < 4; j++) {
		toQuadrant[j] <: SHUTDOWN;
	}
}

//READ BUTTONS and send commands to Distributor
void buttonListener(in port buttons, chanend toDistributor) { //ABCD 14 13 11 7
	int buttonInput;            //button pattern currently pressed
	unsigned int running = 1;
	while (running) {
		buttons when pinsneq(15) :> buttonInput;
		toDistributor <: buttonInput;
		toDistributor :> running;
		if (running == SHUTDOWN)
			running = 0;
		waitMoment(15000000);
	}
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from pgm file with path and name infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void worker(chanend c_in, chanend c_out, int id) {
	int temp1 = 0;
	int result = 0;
	uchar tempArray[3][bufferWidth];
	int width = bufferWidth;
	int overflowCount = 0;
	//the first worker and the last worker get one less pixel to blur
	if(id==0 || id == noWorkers-1) {
		width--;
	}
	//loops the number of times the image should be blurred
	for(int l=0;l<noBlurs;l++) {
		//gets the correct number of pixels from the distributor
		for(int j=0;j<IMHT;j++) {
			//gets the line pixel by pixel;
			for(int k=0;k<width;k++) {
				c_in :> temp1;
				tempArray[j%3][k] = (uchar)temp1;
				//as soon as the worker has enough information it can start working out the averages straight away
				if((j>=2) && (k>=2)) {
					result = tempArray[0][k-2] + tempArray[0][k-1] + tempArray[0][k] +
							tempArray[1][k-2] + tempArray[1][k-1] + tempArray[1][k] + tempArray[2][k-2] + tempArray[2][k-1] + tempArray[2][k];
					c_out <: (uchar)(result/9);
				}
			}
		}
	}
	//waits to be told to shutdown
	c_in :> temp1;
	c_out <: SHUTDOWN;
}

void collector(chanend fromWorkers[], chanend c_out, chanend toVisualiser) {
	int number = 0;
	uchar black = 0;
	int width = IMWD/noWorkers;
	uchar w0[selection-1], w1[selection], w2[selection], w3[selection-1];
	for(int l = 0; l<noBlurs; l++) {
		toVisualiser <: 1;
		//writes a line of black at the top of the image
		for(int i=0;i<IMWD;i++) {
			c_out <: black;
			number++;
		}
		//loops through the lines in the image
		for(int j=1;j<IMHT-1;j++) {
			int worker = 0;
			int total = divided;
			//puts a black pixel at the beginning of the line
			c_out <: black;
			//recieves from each of the four workers in parallel
			//needed to 'hard code' this for four workers as each
			//thread needs it's own individual variable to store in
			par {
					{
						for (int j = 0; j < selection-1; j++) {
							fromWorkers[0] :> w0[j];
							//outputs pixels from first worker straight away to save having loop on outside
							c_out <: w0[j];
						}
					}
					{
						for (int j = 0; j < (selection); j++) {
							fromWorkers[1] :> w1[j];
						}
					}
					{
						for (int j = 0; j < (selection); j++) {
							fromWorkers[2] :> w2[j];
						}
					}
					{
						for (int j = 0; j < (selection-1); j++) {
							fromWorkers[3] :> w3[j];
						}
					}
			}
			//outputs all the pixels from the workers in order
			for(int j = 0;j < selection;j++) {
				c_out <: w1[j];
			}
			for(int j = 0;j < selection;j++) {
				c_out <: w2[j];
			}
			for(int j = 0; j< selection-1; j++) {
				c_out <: w3[j];
			}
			c_out <: black;
			toVisualiser <: j+1;
		}
		toVisualiser <: IMHT;
		//writes a line of black
		for(int i=0;i<IMWD;i++) {
			c_out <: black;
		}
	}
	//waits for all the workers to tell it to shutdown
	for(int i=0; i<noWorkers;i++) {
		fromWorkers[i] :> number;
	}
	toVisualiser <: SHUTDOWN;
}
//gets a one line filled up at a time from by the pgm c files and then sends each pixel one at a time to the
//distributor
void DataInStream(char infname[], chanend c_out, chanend fromButtons, chanend toDataOut, chanend toTimer) {
	int res;
	uchar line[IMWD];
	int button = 0;
	int value = 0;
	//waits for the start buttons to be pressed
	while(button != 14) {
		fromButtons :> button;
		fromButtons <: 1;
	}
	printf("DataInStream:Start...\n");
	//tells the timer to start counting the start time from 'now'
	toTimer <: INIT;
	for(int l=0;l<noBlurs;l++) {
		int ack;
		//if the number of blurs is more than one than temporary files need to be used
		//as you can't read and write to the same file
		if(l == 0)
			res = _openinpgm(infname, IMWD, IMHT);
		else if((l%2))
			res = _openinpgm(tempFile1, IMWD, IMHT);
		else
			res = _openinpgm(tempFile2, IMWD, IMHT);
		if (res) {
			printf("DataInStream:Error openening %s\n.", infname);
			return;
		}
		for (int y = 0; y < IMHT; y++) {
			//attempt at time how long it takes to read in a line
			toTimer <: 0;
			//if USB is defined the it acts as normal, otherwise it just sends dummy values
			//to test the speed of the system without usb
			#ifdef USB
				_readinline(line, IMWD);
			#endif
			toTimer <: 0;
			for (int x=0; x<IMWD; x++) {
				select {
					case fromButtons :> value:
						fromButtons <: 1;
						if(value == 13) {
							printf("paused\n");
							//when paused it waits to be unpaused and only beaks loop if button
							//pressed again
							while(1) {
								fromButtons :> value;
								fromButtons <: 1;
								if(value == 13) {
									printf("unpaused\n");
									break;
								}
							}
						}
						break;
					 default:
						break;
				}
				master {
					//if USB undefined just sends 0 as dummy value
					#ifdef USB
						c_out  <: (int)line[ x ];
					#else
						c_out <: 0;
					#endif
				}
			}
		}
		_closeinpgm();
		//waits for the dataout to tell this thread when it has finished writing to a file (for multiple blurs)
		toDataOut :> ack;
	}
	//waits to be told to shutdown
	while(1) {
		fromButtons :> button;
		if(button == 11) {
			fromButtons <: 0;
			break;
		} else {
			fromButtons <: 1;
		}
	}
	c_out <: SHUTDOWN;
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
	int tempValue;
	int flag = 0;
	printf("ProcessImage:Start, size = %dx%d\n", IMHT, IMWD);
	//This code is to be replaced – it is a place holder for farming out the work...
	for(int l=0;l<noBlurs;l++) {
		for (int y = 0; y < IMHT; y++) {
			int count = 0, total = 0;
			int workers = 0;
			currentLine = (y-1)%3;
			flag = 0;
			total = divided;
			for (int x = 0; x < IMWD; x++) {
				//async channel, gains slight speed up
				slave {
					c_in :> tempValue;
				}
				//works out if it should send pixel to two workers
				//i.e overlapping columns
				if(flag) {
					c_out[(workers)-1] <: tempValue;
					flag = 0;
				}
				if(x+1 >= total && workers+1<noWorkers) {
					workers++;
					total = (workers+1)*divided;
					flag = 1;
				}
				c_out[workers] <: tempValue;
				if(flag) {
					c_out[workers-1] <: tempValue;

				}
				//c_out <: (uchar)( val ^ 0xFF ); //Need to cast
			}
		}
	}
	do {
		c_in :> tempValue;
	} while (tempValue != SHUTDOWN);
	for(int i = 0; i<noWorkers; i++) {
		c_out[i] <: SHUTDOWN;
	}
}
/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to pgm image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in, chanend dataoutToTimer, chanend toDataIn) {
	int res;
	uchar line[IMWD];
	printf("DataOutStream:Start...\n");
	for(int l=0;l<noBlurs;l++) {
		if(l == (noBlurs-1))
			res = _openoutpgm(outfname, IMWD, IMHT);
		else if(!(l % 2))
			res = _openoutpgm(tempFile1, IMWD, IMHT);
		else
			res = _openoutpgm(tempFile2, IMWD, IMHT);
		if (res) {
			return;
		}
		for (int y = 0; y < IMHT; y++) {
			for (int x = 0; x < IMWD; x++) {
				c_in :> line[ x ];
			//printf( "+%4.1d ", line[ x ] );
			}
		//printf( "\n" );
			dataoutToTimer <: INIT;
			#ifdef USB
				_writeoutline( line, IMWD );
			#endif
			dataoutToTimer <: INIT;
		}

		_closeoutpgm();
		toDataIn <: 1;
	}
	dataoutToTimer <: 0;
	dataoutToTimer <: SHUTDOWN;
	return;
}
//Timer inspired by a timer written for the arudueno board
void Timer(chanend fromDataOut, chanend fromDataIn) {
	/* OverflowFlag tells you if the Timer is in the 'second half' of the integer
	 * This means that once this flag is set, you can tell if the timer has
	 * Overflowed i.e if the timer then gives a timer which is in the first half
	 * of an integer. I.e less than 2147483647 and the flag is set, then you
	 * have an overflow
	 */
	uint currentTime, startTime, val, value, overflowCount = 0;
	int running = 1, overflowFlag = 0;
	int onceFlag = 0;
	int flag = 0, dataoutFlag = 0;
	uint readinTime = 0, start = 0, dataStart = 0, dataReadinTime = 0;
	timer Timer;
	Timer :> currentTime;
	//the timer counts in nanoseconds, so to stop it overflowing in such a short
	//period we're going to change the resolution to microseconds
	startTime = currentTime/100;
	if (currentTime > 2147483647) overflowFlag = 1;
	while (running) {
		select {
			case fromDataOut :> value:
			{
				if (value == SHUTDOWN) running = 0;
				else {
					Timer :> val;
					//checks for overflow whenever a time is requested
					if (val > 2147483647) overflowFlag = 1;
					if (overflowFlag && val < 2147483647) {
						overflowFlag = 0;
						overflowCount++;
					}
					/*The time we return is going to be the number of times the timer has
					 * overflowed * by the number of microseconds that occur during one overflow of the nanosecond uint
					 * counter, multiplied by the latest value from the timer - the start time
					 * Obviously to accurately count in microseconds we need to be 10x10^7 right until the last
					 * calculation
					 */
					val = overflowCount * 42949673 + val/100 - startTime;
					if(value != INIT) {
						printf("The throughput including usb is %d pixels per second\n", (IMHT*IMWD)/(val/1000000));
						printf("Process took %u minutes %u.%06us\n", val/1000000/60, (val/1000000)%60, val%1000000);
						/*printf("ReadinTime = %u minutes %u.%06us\n", readinTime/1000000/60, (readinTime/1000000)%60, readinTime%1000000);
						printf("DataReadinTime = %u minutes %u.%06us\n", dataReadinTime/1000000/60, (dataReadinTime/1000000)%60, dataReadinTime%1000000);
						printf("Process without usb took %u minutes %u.%06us\n", (val-readinTime- dataReadinTime)/1000000/60, ((val-readinTime-dataReadinTime)/1000000)%60, (val-readinTime-dataReadinTime)%1000000);
						printf("The throughput w/o usb is %u pixels per second\n", ((IMHT*IMWD)/(val-readinTime-dataReadinTime)/1000000));*/
					} else if(!dataoutFlag) {
						dataStart = val;
						dataoutFlag = 1;
					} else {
						dataReadinTime = dataReadinTime+(val-dataStart);
						dataoutFlag = 0;
					}
				}
				break;
			}
			case fromDataIn :> value:
			{
				Timer :> val;
				//checks for overflow whenever a time is requested
				if (val > 2147483647) overflowFlag = 1;
				if (overflowFlag && val < 2147483647) {
					overflowFlag = 0;
					overflowCount++;
				}
				if(value == INIT)
					startTime = overflowCount * 42949673 + val/100;
				else if(!flag) {
					start = overflowCount * 42949673 + val/100;
					flag = 1;
				} else {
					readinTime = (overflowCount * 42949673) + val/100 - start + readinTime;
					flag = 0;
				}
				break;
			}
			case Timer when timerafter(currentTime + 1000000000) :> void:
			{
				Timer :> currentTime;
				if (currentTime > 2147483647) overflowFlag = 1;
				if (overflowFlag && currentTime < 2147483647) {
					overflowCount++;
					overflowFlag = 0;
				}
				break;
			}
			default:
				break;
		}
	}
}

//MAIN PROCESS defining channels, orchestrating and starting the threads
int main() {
	chan c_inIO, c_outIO; //extend your channel definitions here
	chan distributorToWorkers[noWorkers];
	chan workerToCollector[noWorkers];
	chan toVisualiser;
	chan buttonsToDataIn;
	chan dataOutToDataIn;
	chan quadrant[4];
	chan dataoutToTimer;
	chan datainToTimer;
	par //extend/change this par statement to implement your concurrent filter
	{
		on stdcore[0] : visualiser(toVisualiser, quadrant);
		on stdcore[0] : buttonListener(buttons, buttonsToDataIn);
		on stdcore[0] : Timer(dataoutToTimer, datainToTimer);
		on stdcore[1] : DataInStream(infname, c_inIO, buttonsToDataIn, dataOutToDataIn, datainToTimer);
		on stdcore[1] : distributor( c_inIO, distributorToWorkers);
		on stdcore[3] : collector(workerToCollector, c_outIO, toVisualiser);
		on stdcore[3] : DataOutStream( outfname, c_outIO, dataoutToTimer, dataOutToDataIn);
		par (int k = 0; k<noWorkers; k++) {
			on stdcore[k%4]: worker(distributorToWorkers[k],workerToCollector[k], k);
		}
		par (int k=0;k<4;k++) {
			on stdcore[k%4]: showLED(cled[k],quadrant[k]);
		}

		//printf("Main:Done...\n");
	}
	return 0;
}
