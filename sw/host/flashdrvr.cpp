////////////////////////////////////////////////////////////////////////////////
//
// Filename: 	flashdrvr.cpp
//
// Project:	ZBasic, a generic toplevel impl using the full ZipCPU
//
// Purpose:	Flash driver.  Encapsulates the erasing and programming (i.e.
//		writing) necessary to set the values in a flash device.
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
#include <stdint.h>
#include <unistd.h>
#include <strings.h>
#include <ctype.h>
#include <string.h>
#include <signal.h>
#include <assert.h>

#include "port.h"
#include "regdefs.h"
#include "ttybus.h"
#include "flashdrvr.h"
#include "byteswap.h"

const	bool	HIGH_SPEED = false;

#define	CFG_USERGRANT
#define	CFG_USERREQUEST
#define	CFG_CS_N
#define	CFG_MISO
#define	CFG_MOSI
#define	CFG_SCK

uint32_t	FLASHDRVR::getbus(void) {
	s = m_fpga->readio(R_FLASHCFG);
	if ((s&CFG_USERREQUEST)==0) {
		m_fpga->writeio(R_FLASHCFG, s | CFG_CS_N | CFG_SCK);
		s = m_fpga->readio(R_FLASHCFG);
	} do
		s = m_fpga->readio(R_FLASHCFG);
	while((s&CFG_USERGRANT)==0);

	return s;
}


char	FLASHDRVR::sendspibyte(char d) {
	char		r = 0;
	uint32_t	s;

	s = getbus();
	m_fpga->writeio(R_FLASHCFG, 0);

	for(int i=0; i<8; i++) {
		mosi = (d>>7)&1;
		d <<= 1;
		m_fpga->writeio(R_FLASHCFG, CFG_MOSI);
		m_fpga->writeio(R_FLASHCFG, CFG_MOSI | CFG_SCK);
		s = m_fpga->readio(R_FLASHCFG);
		r = (r<<1)| ((s&CFG_MISO)?1:0);
	}

	return r;
}

uint32_t	FLASHDRVR::sendspi32(uint32_t d) {
	char		r = 0;
	uint32_t	s;

	s = getbus();
	m_fpga->writeio(R_FLASHCFG, 0);

	for(int i=0; i<32; i++) {
		mosi = (d>>31)&1;
		d <<= 1;
		m_fpga->writeio(R_FLASHCFG, CFG_MOSI);
		m_fpga->writeio(R_FLASHCFG, CFG_MOSI | CFG_SCK);
		s = m_fpga->readio(R_FLASHCFG);
		r = (r<<1)| ((s&CFG_MISO)?1:0);
	}

	return r;
}

uint32_t	FLASHDRVR::take_offline(void) {
	uint32_t	s = getbus();

	// Take us out of any dual SPI mode
	m_fpga->writeio(R_FLASHCFG, CMD_CS_N | CMD_SCK);
	m_fpga->writeio(R_FLASHCFG, CMD_SCK);
	for(int k=0; k<32; i++) {
		m_fpga->writeio(R_FLASHCFG, 0);
		m_fpga->writeio(R_FLASHCFG, CMD_SCK);
	}
	m_fpga->writeio(R_FLASHCFG, CMD_CS_N | CMD_SCK);

	// Take us out of any deep power down mode
	start();
	sendspibyte(0x0ab);
	stop();
}

uint32_t	FLASHDRVR::restore_online(void) {
	// Remove the user request
	//
	// start();
	// sendspibyte(0xbb);
	// sendspibyte(0);
	// sendspibyte(0);
	// sendspibyte(0);
	// sendspibyte(0x20);	// SHORT-CIRCUIT!!!
	// stop();
	m_fpga->WRITEIO(R_FLASHCFG, CFG_USERREQUEST);
}

uint32_t	FLASHDRVR::start(void) {
	m_fpga->writeio(R_FLASHCFG, CFG_SCK);
	m_fpga->writeio(R_FLASHCFG, 0);
}

uint32_t	FLASHDRVR::stop(void) {
	m_fpga->writeio(R_FLASHCFG, CFG_SCK);
	m_fpga->writeio(R_FLASHCFG, CFG_SCK|CFG_CS_N);
} 
uint32_t	FLASHDRVR::release(void) {
	m_fpga->writeio(R_FLASHCFG, CFG_USERREQUEST | CFG_SCK | CFG_CS_N);
}

void	FLASHDRVR::flwait(void) {
	uint32_t	s;

	s = m_fpga->readio(R_FLASHCFG);
	assert((s & CFG_USERGRANT)==0);

	start();
	sendspibyte(CMD_READSTATUS);
	do {
		s = sendspibyte(CMD_READSTATUS);
	} while(s & 0x01);

	stop();
}

void	FLASHDRVR::bytecmd(int cmd) {
	start();
	sendspibyte(cmd);
	stop();
}
	
void	FLASHDRVR::write_enable(void) {
	bytecmd(CMD_WRITEENABLE);
}

void	FLASHDRVR::write_disable(void) {
	bytecmd(CMD_WRITEDISABLE);
}

void	FLASHDRVR::readi(const uint32_t base, const uint32_t ln,
		uint32_t *buf) {

	m_fpga->readi(base, ln>>2, (uint32_t *)sbuf);
	start();
	sendspibyte(CMD_READARRAY); // 0x03
	sendspibyte((base>>16)&0x0ff);
	sendspibyte((base>> 8)&0x0ff);
	sendspibyte((base    )&0x0ff);

	for(k=0;  k<ln; k++) {
		uint32_t	r;
		r = sendspibyte(0)&0x0ff;
		r = (r<<8) | ((sendspibyte(0)&0x0ff);
		r = (r<<8) | ((sendspibyte(0)&0x0ff);
		r = (r<<8) | ((sendspibyte(0)&0x0ff);
		buf[k] = r;
	}
}

bool	FLASHDRVR::erase_sector(const unsigned sector, const bool verify_erase) {
	if (m_debug) printf("Erasing sector: %08x\n", sector);
	write_enable();
	start();
	sendspibyte(CMD_ERASESECTOR);
	sendspibyte((sector>>16)&0x0ff);
	sendspibyte((sector>> 8)&0x0ff);
	sendspibyte((sector    )&0x0ff);
	stop();

	// Wait for the erase to finish
	flwait();

	DEVBUS::BUSW	page[SZPAGEW];

	// Now, let's verify that we erased the sector properly
	if (verify_erase) {
		for(int i=0; i<NPAGES; i++) {
			uint32_t	addr = sector + i*SZPAGEW;
			// Send the read + address command

			readi(sector, SZPAGEW, page);

			for(int i=0; i<SZPAGEW; i++)
				if (page[i] != 0xffffffff)
					return false;
		}
	}

	return true;
}

bool	FLASHDRVR::page_program(const unsigned addr, const unsigned len,
		const char *data, const bool verify_write) {
	DEVBUS::BUSW	buf[SZPAGEW], bswapd[SZPAGEW];

	assert(len > 0);
	assert(len <= PGLENB);
	assert(PAGEOF(addr)==PAGEOF(addr+len-1));

	if (len <= 0)
		return true;

	bool	empty_page = true;
	for(unsigned i=0; i<len; i+=4) {
		uint32_t v;
		v = data[i];
		if ((v&0x0ff) != 0x0ff) {
			empty_page = false;
			break;
		}
	}

	if (!empty_page) {
		// Write the page
		write_enable();
		start();
		sendspibyte(CMD_PAGEPROGRAM);	// 0x02
		sendspibyte((addr>>16)&0x0ff);
		sendspibyte((addr>> 8)&0x0ff);
		sendspibyte((addr    )&0x0ff);

		for(unsigned i=0; i<len; i++)
			sendspibyte(data[i]);
	
		flwait();
	}

	if (verify_write) {
		// readi(addr, len, page);
		start();
		sendspibyte(CMD_READARRAY); // 0x03
		sendspibyte((sector>>16)&0x0ff);
		sendspibyte((sector>> 8)&0x0ff);
		sendspibyte((sector    )&0x0ff);

		for(k=0;  k<len; k++) {
			uint32_t	r;
			r = sendspibyte(0)&0x0ff;
			if (((r^data[k])&0x0ff)!=0) {
				printf("\nVERIFY FAILS[%d]: %08x\n", k, k+addr);
				printf("\t(Flash[%d]) %02x != %02x (Goal[%02x])\n", 
					k, buf[k], data[k], k+addr);
				return false;
			}
		}

	} return true;
}

bool	FLASHDRVR::write(const unsigned addr, const unsigned len,
		const char *data, const bool verify) {
	take_offline();

	// Work through this one sector at a time.
	// If this buffer is equal to the sector value(s), go on
	// If not, erase the sector

	for(unsigned s=SECTOROF(addr); s<SECTOROF(addr+len+SECTORSZB-1);
			s+=SECTORSZB) {
		// Do we need to erase?
		bool	need_erase = false, need_program = false;
		unsigned newv = 0; // (s<addr)?addr:s;
		{
			char *sbuf = new char[SECTORSZB];
			const char *dp;	// pointer to our "desired" buffer
			unsigned	base,ln;

			base = (addr>s)?addr:s;
			ln=((addr+len>s+SECTORSZB)?(s+SECTORSZB):(addr+len))-base;
			readi(base, ln>>2, (uint32_t *)sbuf);
			byteswapbuf(ln>>2, (uint32_t *)sbuf);

			dp = &data[base-addr];

			for(unsigned i=0; i<ln; i++) {
				if ((sbuf[i]&dp[i]) != dp[i]) {
					if (m_debug) {
						printf("\nNEED-ERASE @0x%08x ... %08x != %08x (Goal)\n", 
							i+base-addr, sbuf[i], dp[i]);
					}
					need_erase = true;
					newv = (i&-4)+base;
					break;
				} else if ((sbuf[i] != dp[i])&&(newv == 0))
					newv = (i&-4)+base;
			}
		}

		if (newv == 0)
			continue; // This sector already matches

		// Erase the sector if necessary
		if (!need_erase) {
			if (m_debug) printf("NO ERASE NEEDED\n");
		} else {
			printf("ERASING SECTOR: %08x\n", s);
			if (!erase_sector(s, verify)) {
				printf("SECTOR ERASE FAILED!\n");
				return false;
			} newv = (s<addr) ? addr : s;
		}

		// Now walk through all of our pages in this sector and write
		// to them.
		for(unsigned p=newv; (p<s+SECTORSZB)&&(p<addr+len); p=PAGEOF(p+PGLENB)) {
			unsigned start = p, len = addr+len-start;

			// BUT! if we cross page boundaries, we need to clip
			// our results to the page boundary
			if (PAGEOF(start+len-1)!=PAGEOF(start))
				len = PAGEOF(start+PGLENB)-start;
			if (!page_program(start, len, &data[p-addr], verify)) {
				printf("WRITE-PAGE FAILED!\n");
				return false;
			}
		} if ((need_erase)||(need_program))
			printf("Sector 0x%08x: DONE%15s\n", s, "");
	}

	write_disable(); // Re-enable write protection

	restore_online();

	return true;
}

