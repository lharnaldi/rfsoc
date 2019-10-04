/*
 * Copyright (C) 2017-2018 L. Horacio Arnaldi
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "lia_rp.h"

//Globals
int n_dev;
uint32_t reg_off;
int32_t reg_val;
int limit;
int current;

int fReadReg, fGetCfgStatus, fInitSystem, fWriteReg,
    fSetCfgReg, fToFile, fToStdout, fFile, fCount, fByte, fRegValue, 
    fshowversion, fx_val, fkp_val, fki_val, ff_val;

char charAction[MAXCHRLEN], scRegister[MAXCHRLEN], charReg[MAXCHRLEN],
     charFile[MAXCHRLEN], charCurrentFile[MAXCHRLEN], charCount[MAXCHRLEN],
     scByte[MAXCHRLEN], charRegValue[MAXCHRLEN], charCurrentMetaData[MAXCHRLEN];

//FILE        *fhin = NULL;
FILE         *fhout = NULL;
FILE         *fhmtd = NULL;
struct FLContext  *handle = NULL;

int interrupted = 0;

int main(int argc, char *argv[])
{
				int position;
				int16_t I_sig, Q_sig;

				//Check the arguments
				if (!parse_param(argc, argv)) {
								show_usage(argv[0]);
								return 1;
				}

				//initialize devices. TODO: add error checking
				cfg_init();
				sts_init();

				//Check if it is the first time we access the PL
				//This is for initial configuration
				if (dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET) == 0) //first time access
				{
								printf("Initializing registers...\n");
								init_system();
				}

				signal(SIGINT, signal_handler);

				if(fReadReg) {
								rd_reg_value(n_dev, reg_off);  // Read single register
				}
				else if (fWriteReg) {
								wr_reg_value(n_dev, reg_off, reg_val);  // Write single register
				}
				else if (fSetCfgReg) {
								if (ff_val) set_frequency(reg_off, atof(charRegValue)); 
								else if (fx_val) set_xvalue(reg_off, atof(charRegValue));
								else wr_reg_value(1,reg_off, atoi(charRegValue)); 
				}
				else if (fGetCfgStatus) {
								rd_cfg_status();        // Get registers status
				}
				else if (fInitSystem) {
								printf("Initializing registers...\n");
								init_system();
				}
				else if (fToFile || fToStdout) {

								// enter normal mode for pps_gen, fifo and trigger modules
								reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 1);

								//FIXME: here we should enable interrupts
								while(!interrupted){
								// read writer position 
								position = dev_read(sts_ptr, STS_STATUS_OFFSET);
								I_sig = (position & 0xFFFF);
								Q_sig = (position>>16 & 0xFFFF);
								printf("%5d %5d %.9lf %.9lf %.9f %.9f\n", I_sig, Q_sig, I_sig/pow(2,13), Q_sig/pow(2,13), sqrt(pow(I_sig/pow(2,13),2)+pow(Q_sig/pow(2,13),2)), (180/M_PI)*atan(Q_sig/I_sig));
								sleep(1);

												// alarm(2);   // setting 1 sec timeout
												// read writer position
												//position = dev_read(sts_ptr, STS_STATUS_OFFSET);
												//wait_for_interrupt(intc_fd, intc_ptr);
												//read_buffer(position, bmp);
												// alarm(0);   // cancelling 1 sec timeout
								}
								// reset pps_gen, fifo and trigger modules
								//reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
								//dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~1);

				}

				// unmap and close the devices
				munmap(cfg_ptr, sysconf(_SC_PAGESIZE));
				munmap(sts_ptr, sysconf(_SC_PAGESIZE));

				close(cfg_fd);
				close(sts_fd);

				return 0;

}

void signal_handler(int sig)
{
				interrupted = 1;
}

void show_usage(char *progname)
{
				if (fshowversion) {
								printf("Digital Lock-in Amplifier (LIA) BRC v%dr%d data v%d\n",VERSION,REVISION,DATAVERSION);
				} else {
								printf("\tDigital Lock-in Amplifier\n");
								printf("\t(c) 2018, LabDPR, http://labdpr.cab.cnea.gov.ar\n");
								printf("\n\tDPR Lab. 2018\n");
								printf("\tH. Arnaldi, lharnaldi@gmail.com\n");
								printf("\t%s v%dr%d comms soft\n\n",EXP,VERSION,REVISION);
								printf("Usage: %s <action> <register> <value> [options]\n", progname);

								printf("\n\tActions:\n");
								//  printf("\t-r\t\t\t\tGet a single register value\n");
								//  printf("\t-p\t\t\t\tSet a value into a single register\n");
								printf("\t-a\t\t\t\tGet all registers status\n");
								printf("\t-s\t\t\t\tSet registers\n");
								//printf("\t-f\t\t\t\tStart LIA and save data to file\n");
								printf("\t-o\t\t\t\tStart LIA and send data to stdout\n");
								printf("\t-i\t\t\t\tInitialise registers to default values\n");
								printf("\t-v\t\t\t\tShow LIA version\n");

								printf("\n\tRegisters:\n");
								printf("\tkp, ki, xv, fv\t\t\tSpecify register values\n");

								//printf("\n\tOptions:\n");
								//printf("\t-f <filename>\t\t\tSpecify file name\n");
								//printf("\t-c <# bytes>\t\t\tNumber of bytes to read/write\n");
								//printf("\t-b <byte>\t\t\tValue to load into register\n");

								printf("\n\n");
				}
}

//TODO: change this function to just strncpy
void StrcpyS(char *szDst, size_t cchDst, const char *szSrc)
{

#if defined (WIN32)

				strcpy_s(szDst, cchDst, szSrc);

#else

				if ( 0 < cchDst ) {

								strncpy(szDst, szSrc, cchDst - 1);
								szDst[cchDst - 1] = '\0';
				}
#endif
}

int parse_param(int argc, char *argv[])
{

				int    arg;

				// Initialize default flag values
				fReadReg    = 0;
				fWriteReg    = 0;
				fGetCfgStatus = 0;
				fSetCfgReg = 0;
				fToFile    = 0;
				fToStdout  = 0;
				fFile      = 0;
				fCount     = 0;
				fByte      = 0;
				fx_val     = 0;
				fkp_val    = 0;
				fki_val    = 0;
				ff_val     = 0;

				// Ensure sufficient paramaters. Need at least program name and action
				// flag
				if (argc < 2)
				{
								return 0;
				}

				// The first parameter is the action to perform. Copy the first
				// parameter into the action string.
				StrcpyS(charAction, MAXCHRLEN, argv[1]);
				if(strcmp(charAction, "-r") == 0) {
								fReadReg = 1;
				}
				else if( strcmp(charAction, "-w") == 0) {
								fWriteReg = 1;
				}
				else if( strcmp(charAction, "-a") == 0) {
								fGetCfgStatus = 1;
								return 1;
				}
				else if( strcmp(charAction, "-v") == 0) {
								fshowversion = 1;
								return 0;
				}
				else if( strcmp(charAction, "-s") == 0) {
								fSetCfgReg = 1;
				}
				/*else if( strcmp(charAction, "-f") == 0) {
								fToFile = 1;
				}*/
				else if( strcmp(charAction, "-o") == 0) {
								fToStdout = 1;
								return 1;
				}
				else if( strcmp(charAction, "-i") == 0) {
								fInitSystem = 1;
								return 1;
				}
				else { // unrecognized action
								return 0;
				}

				// Second paramater is target register on device. Copy second paramater
				// to the register string
				if((fReadReg == 1) || (fWriteReg == 1)) {
								StrcpyS(charReg, MAXCHRLEN, argv[2]);
								if(strcmp(charReg, "cfg") == 0) {
												n_dev = 1;
								}
								else if(strcmp(charReg, "sts") == 0) {
												n_dev = 2;
								}
								else { // unrecognized device to set
												return 0;
								}
								reg_off = strtoul(argv[3],NULL, 16);
								//FIXME: see if this can be done better
								if (fWriteReg) reg_val = strtoul(argv[4],NULL,16);
								return 1;
				}

				else if(fSetCfgReg) {
								StrcpyS(charReg, MAXCHRLEN, argv[2]);
								// Registers 
								if(strcmp(charReg, "kp") == 0) {
												reg_off = CFG_KP_OFFSET;
								}
								else if(strcmp(charReg, "ki") == 0) {
												reg_off = CFG_KI_OFFSET;
								}
								else if(strcmp(charReg, "xv") == 0) {
												reg_off = CFG_X_VALUE_OFFSET;
								}
								else if(strcmp(charReg, "fv") == 0) {
												reg_off = CFG_F_VALUE_OFFSET;
								}
								// Unrecognized
								else { // unrecognized register to set
												return 0;
								}
	              StrcpyS(charRegValue, 16, argv[3]);
                if((strncmp(charReg, "fv", 2) == 0)) {
                        if (atof(charRegValue)>8400000) {
                                printf ("Error: maximum frequency is 8.4 MHz\n");
                                exit(1);
                        }
                        ff_val = 1;
                }
                if((strncmp(charReg, "kp", 2) == 0)) {
                        if (atoi(charRegValue)>pow(2,31)) {
                                printf ("Error: maximum value is 2^31\n");
                                exit(1);
                        }
                        fkp_val = 1;
                }
                if((strncmp(charReg, "ki", 2) == 0)) {
                        if (atoi(charRegValue)>pow(2,31)) {
                                printf ("Error: maximum value is 2^31\n");
                                exit(1);
                        }
                        fki_val = 1;
                }
                if((strncmp(charReg, "xv", 2) == 0)) {
                        if (atoi(charRegValue)>pow(2,31)) {
                                printf ("Error: maximum value is 2^31\n");
                                exit(1);
                        }
                        fx_val = 1;
                }

				}
				/*else if(fToFile) {
								if(argv[2] != NULL) {
												StrcpyS(charFile, MAXFILENAMELEN, argv[2]);
												fFile = 1;
								}
								else {
												return 0;
								}
				}*/
				else {
								StrcpyS(scRegister, MAXCHRLEN, argv[2]);

								// Parse the command line parameters.
								arg = 3;
								while(arg < argc) {

												// Check for the -f parameter used to specify the
												// input/output file name.
												if (strcmp(argv[arg], "-f") == 0) {
																arg += 1;
																if (arg >= argc) {
																				return 0;
																}
																StrcpyS(charFile, 16, argv[arg++]);
																fFile = 1;
												}

												// Check for the -c parameter used to specify the number
												// of bytes to read/write from file.
												/*else if (strcmp(argv[arg], "-c") == 0) {
																arg += 1;
																if (arg >= argc) {
																				return 0;
																}
																StrcpyS(charCount, 16, argv[arg++]);
																fCount = 1;
												}*/

												// Check for the -b paramater used to specify the value
												// of a single data byte to be written to the register
												/*else if (strcmp(argv[arg], "-b") == 0) {
																arg += 1;
																if (arg >= argc) {
																				return 0;
																}
																StrcpyS(scByte, 16, argv[arg++]);
																fByte = 1;
												}*/

												// Not a recognized parameter
												else {
																return 0;
												}
								} // End while

								// Input combination validity checks
								if( fWriteReg && !fByte ) {
												printf("Error: No byte value provided\n");
												return 0;
								}
								if( (fToFile ) && !fFile ) {
												printf("Error: No filename provided\n");
												return 0;
								}

								return 1;
				}
				return 1;
}

