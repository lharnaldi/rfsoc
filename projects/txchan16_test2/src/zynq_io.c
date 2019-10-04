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

#include "zynq_io.h"

int intc_fd, cfg_fd, sts_fd, xadc_fd, mem_fd;
void *intc_ptr, *cfg_ptr, *sts_ptr, *xadc_ptr, *mem_ptr;
int dev_size;

void dev_write(void *dev_base, uint32_t offset, int32_t value)
{
				*((volatile unsigned *)(dev_base + offset)) = value;
}

uint32_t dev_read(void *dev_base, uint32_t offset)
{
				return *((volatile unsigned *)(dev_base + offset));
}

/*int dev_init(int n_dev)
	{
	char *uiod; = "/dev/uio1";

	printf("Initializing device...\n");

// open the UIO device file to allow access to the device in user space
cfg_fd = open(uiod, O_RDWR);
if (cfg_fd < 1) {
printf("cfg_init: Invalid UIO device file:%s.\n", uiod);
return -1;
}

dev_size = get_memory_size("/sys/class/uio/uio1/maps/map0/size");

// mmap the cfgC device into user space
cfg_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, cfg_fd, 0);
if (cfg_ptr == MAP_FAILED) {
printf("cfg_init: mmap call failure.\n");
return -1;
}

return 0;
}*/

int32_t rd_reg_value(int n_dev, uint32_t reg_off)
{
				int32_t reg_val;
				switch(n_dev)
				{
								case 0:
												reg_val = dev_read(intc_ptr, reg_off);
												break;
								case 1:
												reg_val = dev_read(cfg_ptr, reg_off);
												break;
								case 2:
												reg_val = dev_read(sts_ptr, reg_off);
												break;
								case 3:
												reg_val = dev_read(xadc_ptr, reg_off);
												break;
								default:
												printf("Invalid option: %d\n", n_dev);
												return -1;
				}
				printf("Complete. Received data 0x%08x\n", reg_val);
				//printf("Complete. Received data %d\n", reg_val);

				return reg_val;
}

int32_t wr_reg_value(int n_dev, uint32_t reg_off, int32_t reg_val)
{
				switch(n_dev)
				{
								case 0:
												//dev_write(intc_ptr, reg_off, reg_val);
												break;
								case 1:
												dev_write(cfg_ptr, reg_off, reg_val);
												break;
								case 2:
												dev_write(sts_ptr, reg_off, reg_val);
												break;
								case 3:
												//dev_write(xadc_ptr, reg_off, reg_val);
												break;
								default:
												printf("Invalid option: %d\n", n_dev);
												return -1;
				}
				printf("Complete. Data written: 0x%08x\n", reg_val);
				//printf("Complete. Data written: %d\n", reg_val);

				return 0;
}

int32_t rd_cfg_status(void)
{

				printf("#K_p constant = %d\n", dev_read(cfg_ptr, CFG_KP_OFFSET));
				printf("#K_i constant = %d\n", dev_read(cfg_ptr, CFG_KI_OFFSET));
				printf("#X_value      = %.9f\n", dev_read(cfg_ptr, CFG_X_VALUE_OFFSET)/pow(2,31));
				printf("#Output freq  = %.3f Hz\n", dev_read(cfg_ptr, CFG_F_VALUE_OFFSET)/pow(2,8));
				printf("\n");
				printf("Status from registers complete!\n");
				return 0;
}

static uint32_t get_memory_size(char *sysfs_path_file)
{
				FILE *size_fp;
				uint32_t size;

				// open the file that describes the memory range size that is based on
				// the reg property of the node in the device tree
				size_fp = fopen(sysfs_path_file, "r");

				if (!size_fp) {
								printf("unable to open the uio size file\n");
								exit(-1);
				}

				// get the size which is an ASCII string such as 0xXXXXXXXX and then be
				// stop using the file
				if(fscanf(size_fp, "0x%08X", &size) == EOF){
								printf("unable to get the size of the uio size file\n");
								exit(-1);
				}
				fclose(size_fp);

				return size;
}

/*int intc_init(void)
{
				char *uiod = "/dev/uio0";

				//printf("Initializing INTC device...\n");

				// open the UIO device file to allow access to the device in user space
				intc_fd = open(uiod, O_RDWR);
				if (intc_fd < 1) {
								printf("intc_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio0/maps/map0/size");

				// mmap the INTC device into user space
				intc_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, intc_fd, 0);
				if (intc_ptr == MAP_FAILED) {
								printf("intc_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}*/

int cfg_init(void)
{
				char *uiod = "/dev/uio1";

				//printf("Initializing CFG device...\n");

				// open the UIO device file to allow access to the device in user space
				cfg_fd = open(uiod, O_RDWR);
				if (cfg_fd < 1) {
								printf("cfg_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio1/maps/map0/size");

				// mmap the cfgC device into user space
				cfg_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, cfg_fd, 0);
				if (cfg_ptr == MAP_FAILED) {
								printf("cfg_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

int sts_init(void)
{
				char *uiod = "/dev/uio2";

				//printf("Initializing STS device...\n");

				// open the UIO device file to allow access to the device in user space
				sts_fd = open(uiod, O_RDWR);
				if (sts_fd < 1) {
								printf("sts_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio2/maps/map0/size");

				// mmap the STS device into user space
				sts_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, sts_fd, 0);
				if (sts_ptr == MAP_FAILED) {
								printf("sts_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

/*int xadc_init(void)
{
				char *uiod = "/dev/uio3";

				//printf("Initializing XADC device...\n");

				// open the UIO device file to allow access to the device in user space
				xadc_fd = open(uiod, O_RDWR);
				if (xadc_fd < 1) {
								printf("xadc_init: Invalid UIO device file:%s.\n", uiod);
								return -1;
				}

				dev_size = get_memory_size("/sys/class/uio/uio3/maps/map0/size"); 

				// mmap the XADC device into user space
				xadc_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, xadc_fd, 0);
				if (xadc_ptr == MAP_FAILED) {
								printf("xadc_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

int mem_init(void)
{
				char *mem_name = "/dev/mem";

				//printf("Initializing mem device...\n");

				// open the UIO device file to allow access to the device in user space
				mem_fd = open(mem_name, O_RDWR);
				if (mem_fd < 1) {
								printf("mem_init: Invalid device file:%s.\n", mem_name);
								return -1;
				}

				dev_size = 2048*sysconf(_SC_PAGESIZE);

				// mmap the mem device into user space 
				mem_ptr = mmap(NULL, dev_size, PROT_READ|PROT_WRITE, MAP_SHARED, mem_fd, 0x1E000000);
				if (mem_ptr == MAP_FAILED) {
								printf("mem_init: mmap call failure.\n");
								return -1;
				}

				return 0;
}

float get_voltage(uint32_t offset)
{
				int16_t value;
				value = (int16_t) dev_read(xadc_ptr, offset);
				//  printf("The Voltage is: %lf V\n", (value>>4)*XADC_CONV_VAL);
				return ((value>>4)*XADC_CONV_VAL);
} */      

/*void set_voltage(uint32_t offset, int32_t value)
{       
				//fit after calibration. See file data_calib.txt in /ramp_test directory 
				// y = a*x + b
				//a               = 0.0382061     
				//b               = 4.11435   
				uint32_t dac_val;
				float a = 0.0382061, b = 4.11435; 

				dac_val = (uint32_t)(value - b)/a;

				dev_write(cfg_ptr, offset, dac_val);
				printf("The Voltage is: %d mV\n", value);
				printf("The DAC value is: %d DACs\n", dac_val);
}
*/

/*void set_voltage(uint32_t offset, int32_t value)
{       
				//fit after calibration. See file data_calib2.txt in /ramp_test directory 
				// y = a*x + b
				//a               = 0.0882006     
				//b               = 7.73516   
				uint32_t dac_val;
				float a = 0.0882006, b = 7.73516; 

				dac_val = (uint32_t)(value - b)/a;

				dev_write(cfg_ptr, offset, dac_val);
				printf("The Voltage is: %d mV\n", value);
				printf("The DAC value is: %d DACs\n", dac_val);
}

float get_temp_AD592(uint32_t offset)
{
				float value;
				value = get_voltage(offset);
				return ((value*1000)-273.15);
} */      

//System initialization
int init_system(void)
{
				uint32_t reg_val;

				// reset pps_gen, fifo and trigger modules
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val & ~1);

				//FIXME: replace hardcoded values for defines
				// set K_p constant default value
				//dev_write(cfg_ptr,CFG_KP_OFFSET,2097152); //2^21

				// set K_i constant default value
				//dev_write(cfg_ptr,CFG_KI_OFFSET,32);

				// set X_value value
				//dev_write(cfg_ptr,CFG_X_VALUE_OFFSET,(pow(0.999998994,30))); //x = 0.999998994, f_c = 10 Hz   
				//dev_write(cfg_ptr,CFG_X_VALUE_OFFSET,2147051914); //x = 0.999998994, f_c = 10 Hz   
				//reg_val = dev_read(cfg_ptr, CFG_X_VALUE_OFFSET);
				//printf("Read x : %d \n", reg_val);
				//printf("Put x: %lf \n", pow(0.999998994,30));
				//
				// set frequency
				set_frequency(CFG_F_VALUE_OFFSET, 10000.0);  // 10kHz default
				set_kconstant(CFG_KP_OFFSET, 2097152); // 2^21 default
				set_kconstant(CFG_KI_OFFSET, 32);      // 2^5 default
				set_xvalue(CFG_X_VALUE_OFFSET, 0.999998994);      // 2^5 default


				// enter normal mode for pps_gen, fifo and trigger modules
				reg_val = dev_read(cfg_ptr, CFG_RESET_GRAL_OFFSET);
				dev_write(cfg_ptr,CFG_RESET_GRAL_OFFSET, reg_val | 1); 

				return 0;
}

void set_frequency(uint32_t offset, float value)
{
        float f_val;

        f_val = value * pow(2,8);

        dev_write(cfg_ptr, offset, f_val);
        printf("The output frequency is now: %.3f Hz\n", value);
        //printf("The frequency value is: %.3f \n", f_val);
}

void set_kconstant(uint32_t offset, uint32_t value)
{
        uint32_t k_val;

        k_val = value;

        dev_write(cfg_ptr, offset, k_val);
        printf("The value of k constant is: %d \n", value);
        //printf("The value is: %d \n", k_val);
}

void set_xvalue(uint32_t offset, float value)
{
        float f_val;

        f_val = value * pow(2,31);

        dev_write(cfg_ptr, offset, f_val);
        printf("The value of X is now: %.9f \n", dev_read(cfg_ptr, CFG_X_VALUE_OFFSET)/pow(2,31));
        //printf("The frequency value is: %.3f \n", f_val);
}

/*int enable_interrupt(void)
{
				// steps to accept interrupts -> as pg. 26 of pg099-axi-intc.pdf
				//1) Each bit in the IER corresponding to an interrupt must be set to 1.
				dev_write(intc_ptr,XIL_AXI_INTC_IER_OFFSET, 1);
				//2) There are two bits in the MER. The ME bit must be set to enable the
				//interrupt request outputs.
				dev_write(intc_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK | XIL_AXI_INTC_MER_HIE_MASK);
				//dev_write(dev_ptr,XIL_AXI_INTC_MER_OFFSET, XIL_AXI_INTC_MER_ME_MASK);

				//The next block of code is to test interrupts by software
				//3) Software testing can now proceed by writing a 1 to any bit position
				//in the ISR that corresponds to an existing interrupt input.
				//        dev_write(intc_ptr,XIL_AXI_INTC_IPR_OFFSET, 1);

				//					for(a=0; a<10; a++)
				//					{
				//					wait_for_interrupt(fd, dev_ptr);
				//					dev_write(dev_ptr,XIL_AXI_INTC_ISR_OFFSET, 1); //regenerate interrupt
				//					}
				//
				return 0;

}*/

/*int disable_interrupt(void)
{
				uint32_t value;
				//Disable interrupt INTC0
				dev_write(intc_ptr,XIL_AXI_INTC_IER_OFFSET, 0);
				//disable IRQ
				value = dev_read(intc_ptr, XIL_AXI_INTC_MER_OFFSET);
				dev_write(intc_ptr,XIL_AXI_INTC_MER_OFFSET, value | ~1);
				//Acknowledge any previous interrupt
				dev_write(intc_ptr, XIL_AXI_INTC_IAR_OFFSET, 1);

				return 0;
}*/

