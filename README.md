## Tiny FPGA

This design is currently a work in progress.  The goal is to place a
[ZipCPU](http://zipcpu.com/about/zipcpu.html)
onto a [TinyFPGA-BX](http://tinyfpga.com) board.

## Vision

My goals for this project are briefly to demonstrate the
[ZipCPU](http://zipcpu.com/about/zipcpu.html)
with a small supporting set of peripherals:

1. [SPI Dual](rtl/dualflexpress.v), with support for

   - Dual flash I/O mode (34 clocks per read),

   - Successive dual flash reads (18 clocks per read)

   - GPIO override--so the design doesn't need the flash write capability,
     but yet can still write

   All of this functionality currently works and has been formally proven

2. USB UART port (pair?)

3. [GPIO](rtl/wbgpio.v), to provide access to the external ports

4. Some other TBD peripheral--to be added to the design using [AutoFPGA](https://github.com/ZipCPU/autofpga)

Planned internal peripherals include:

1. [Block RAM](rtl/memdev.v)

2. [Timer](rtl/cpu/ziptimer.v)

3. [Watchdog interrupt](rtl/cpu/ziptimer.v)

4. [(Bus-based) Interrupt controller](rtl/cpu/icontrol.v)

Further, the project will be built using
[yosys](http://www.clifford.at/yosys/),
and simulated via
[Verilator](https://www.veripool.org/wiki/verilator/)--especially if I can
figure out how to simulate the USB port with
[Verilator](https://www.veripool.org/wiki/verilator/).

## Status

20180810 - Both the [cputest](sw/board/cputest.c) and
[Hello world](sw/board/hello.c) work in the [simulator](sim/verilated).  There
are just a couple of known issues with the design:

- When using [AutoFPGA](https://github.com/ZipCPU/autofpga), the linker script
  that it produces is messed up.  There's just not enough RAM to use that
  script.  [boardflash.ld](sw/board/boardflash.ld) should work, just don't
  overload your memory requests.

- The flash bring-up may be inappropriate for the TinyFPGA board.

- I haven't tested the flash driver necessary for programming the flash (yet)

- There's no support for USB serial in either the design or the
  simulation ... yet.

Well, that and the obvious that it currently only works in simulation and
hasn't seen the actual hardware yet.  Given that the current design only
uses 4427 elements (so far), there should be plenty of room for adding
full USB support back in. (I'm told that's only about 1k LUTs or so.)

## License

This project is released under the terms of the [GPL v3](doc/gpl-3.0.pdf).
