////////////////////////////////////////////////////////////////////////////////
//
// Filename:	../auto-generated/board.h
//
// Project:	TinyZip, a demonstration project for the TinyFPGA B2 board
//
// DO NOT EDIT THIS FILE!
// Computer Generated: This file is computer generated by AUTOFPGA. DO NOT EDIT.
// DO NOT EDIT THIS FILE!
//
// CmdLine:	autofpga autofpga -o ../auto-generated global.txt bkram.txt buserr.txt pllclock.txt pic.txt pwrcount.txt version.txt hbconsole.txt gpio.txt dlyarbiter.txt zipbones.txt flexpress.txt
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
#ifndef	BOARD_H
#define	BOARD_H

// And, so that we can know what is and isn't defined
// from within our main.v file, let's include:
#include <design.h>

#include <design.h>
#include <cpudefs.h>

#define	_HAVE_ZIPBONES



#define BUSPIC(X) (1<<X)


//
// GPIO input wires
//
#define	GPIO_BTN	0x00001
// GPIO output wires
//
#define	GPIO_IN(WIRE)	(((WIRE)>>16)&1)
#define	GPIO_SET(WIRE)	(((WIRE)<<16)|(WIRE))
#define	GPIO_CLR(WIRE)	 ((WIRE)<<16)
//
#define	GPIO_LED		0x000000001
//
#define	GPIO_LED_SET	GPIO_SET(GPIO_LED)
#define	GPIO_LED_CLR	GPIO_CLR(GPIO_LED)
//


#define	CLKFREQHZ	25000000


typedef struct  CONSOLE_S {
	unsigned	u_setup;
	unsigned	u_fifo;
	unsigned	u_rx, u_tx;
} CONSOLE;



#ifdef	BUSTIMER_ACCESS
#define	_BOARD_HAS_BUSTIMER
static volatile unsigned *const _bustimer = ((unsigned *)0x00200000);
#endif	// BUSTIMER_ACCESS
#define	_BOARD_HAS_BUSERR
static volatile unsigned *const _buserr = ((unsigned *)4194304);
#ifdef	BUSPIC_ACCESS
#define	_BOARD_HAS_BUSPIC
static volatile unsigned *const _buspic = ((unsigned *)0x00400004);
#endif	// BUSPIC_ACCESS
#ifdef	GPIO_ACCESS
#define	_BOARD_HAS_GPIO
static volatile unsigned *const _gpio = ((unsigned *)4194312);
#endif	// GPIO_ACCESS
#ifdef	BKRAM_ACCESS
#define	_BOARD_HAS_BKRAM
extern char	_bkram[0x00002000];
#endif	// BKRAM_ACCESS
#define	_BOARD_HAS_VERSION
#ifdef	BUSCONSOLE_ACCESS
#define	_BOARD_HAS_BUSCONSOLE
static volatile CONSOLE *const _uart = ((CONSOLE *)0x00300000);
#endif	// BUSCONSOLE_ACCESS
#ifdef	FLASH_ACCESS
#define	_BOARD_HAS_FLASH
extern char _flash[0x00800000];
#endif	// FLASH_ACCESS
//
// Interrupt assignments (2 PICs)
//
// PIC: cpu_reset
#define	CPU_RESET_RESET	CPU_RESET(0)
#define	CPU_RESET_WATCHDOG	CPU_RESET(1)
// PIC: buspic
#define	BUSPIC_BUSTIMER	BUSPIC(0)
#define	BUSPIC_GPIO	BUSPIC(1)
#define	BUSPIC_UARTTXF	BUSPIC(2)
#define	BUSPIC_UARTRXF	BUSPIC(3)
#endif	// BOARD_H
