////////////////////////////////////////////////////////////////////////////////
//
// Filename:	flashid.cpp
//
// Project:	TinyZip, a demonstration project for the TinyFPGA B2 board
//
// Purpose:	Read the ID from the flash as a test of whether or not the
//		DUALFLEXPRESS controller is working or not.
//
//
// Creator:	Dan Gisselquist, Ph.D.
//		Gisselquist Technology, LLC
//
////////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2018, Gisselquist Technology, LLC
//
// This program is free software (firmware): you can redistribute it and/or
// modify it under the terms of  the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTIBILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
// for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program.  (It's in the $(ROOT)/doc directory.  Run make with no
// target there if the PDF file isn't present.)  If not, see
// <http://www.gnu.org/licenses/> for a copy.
//
// License:	GPL, v3, as defined and found on www.gnu.org,
//		http://www.gnu.org/licenses/gpl.html
//
//
////////////////////////////////////////////////////////////////////////////////
//
//
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "regdefs.h"
#include "hexbus.h"
#include "flashdrvr.h"

FPGA	*m_fpga;

void	usage(void) {
	printf("USAGE: flashid [-n host] [-p port]\n"
"\n"
"\t[-n host]\tAttempt to connect, via TCP/IP, to host named [host].\n"
"\t\tThe default host is \'%s\'\n"
"\n"
"\t-p [port]\tAttempt to connect, via TCP/IP, to port number [port].\n"
"\t\tThe default port is \'%d\'\n"
"\n", FPGAHOST, FPGAPORT);
}

int main(int argc, char **argv) {
#ifdef	R_FLASHCFG
	const char *host = FPGAHOST;
	int	port=FPGAPORT;

	for(int argn=1; argn<argc; argn++) {
		if (argv[argn][0] == '-') {
			if (argv[argn][1] == 'h') {
				usage();
				exit(EXIT_SUCCESS);
			} else if (argv[argn][1] == 'n') {
				if (argn+1 >= argc) {
					fprintf(stderr, "ERR: No network host given\n");
					exit(EXIT_SUCCESS);
				}
				host = argv[argn+1];
				printf("HOST = %s\n", host);
				argn++;
			} else if (argv[argn][1] == 'p') {
				if (argn+1 >= argc) {
					fprintf(stderr, "ERR: No network port # given\n");
					exit(EXIT_SUCCESS);
				}
				port = strtoul(argv[argn+1], NULL, 0);
				printf("PORT = %d\n", port);
				argn++;
			} else {
				usage();
				exit(EXIT_SUCCESS);
			}
		} else {
			usage();
			exit(EXIT_FAILURE);
		}
	}

	m_fpga = new FPGA(new NETCOMMS(host, port));

	// Make sure we start with the flash in idle
	m_fpga->writeio(R_FLASHCFG, 0x100);
#ifdef	R_FLEXSCOPE
	m_fpga->writeio(R_SPIXSCOPE, 124);
#endif
	FLASHDRVR::take_offline(m_fpga);

	m_fpga->writeio(R_FLASHCFG, F_END);
	m_fpga->writeio(R_FLASHCFG, F_MFRID);
	m_fpga->writeio(R_FLASHCFG, F_EMPTY);
	printf("ID:");
	for(int i=0; i<12; i++) {
		unsigned	id;
		id = m_fpga->readio(R_FLASHCFG);
		printf("%c%02x", (i==0)?' ':':', id&0x0ff);
		m_fpga->writeio(R_FLASHCFG, F_EMPTY);
	} printf("\n");
	m_fpga->writeio(R_FLASHCFG, F_END);

	FLASHDRVR::restore_dualio(m_fpga);


	delete	m_fpga;
#else
	printf("ERR: NO FLASH CONFIGURATION REGISTER DEFINED!\n");
#endif
}

