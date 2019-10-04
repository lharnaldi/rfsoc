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

#ifndef _MAIN_H_
#define _MAIN_H_

#include <signal.h>
#include <string.h>
#include <time.h>

#define _GNU_SOURCE

#include "zynq_io.h"
#include "globaldefs.h"

int  main(int argc, char *argv[]);
void signal_handler(int sig);
void show_usage(char *progname);
void StrcpyS(char *szDst, size_t cchDst, const char *szSrc); 
int  parse_param(int argc, char *argv[]);  

#endif
