## Tiny FPGA

This design is currently a work in progress.  The goal is to place a
[ZipCPU](http://zipcpu.com/about/zipcpu.html)
onto a [TinyFPGA-B2](http://tinyfpga.com) board.

## Vision

My goals for this project are briefly to demonstrate the
[ZipCPU](http://zipcpu.com/about/zipcpu.html)
with a small supporting set of peripherals:

1. SPI Dual, accomplished by modifying the [qflashxpress](https://github.com/ZipCPU/s6soc/blob/master/rtl/qflashxpress.v) module for

   - Dual flash I/O, and

   - GPIO override--so the design doesn't need the flash write capability,
     but yet can still write

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

## License

This project is released under the terms of the [GPL v3](doc/gpl-3.0.pdf).
