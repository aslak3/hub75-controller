# HUB75 controller in Verilog

These notes are preliminary. More details, timing diagrams etc, to follow.

This is a HUB75 64x32 LED panel controller written in Verilog.

It is used by my [matrix-display](https://github.com/aslak3/matrix-display) project as an alternative to driving the HUB75 screen using the Pi Pico W board's [PIO function](https://blues.com/blog/raspberry-pi-pico-pio/) for flicker-free operation, though naturally it could eeasily be incorporated into other projects.

In terms of FPGAs used, my board uses an iCE40UP5 in QFN48 and the constraints.pcf file reflects my board, which will shortly be documented in its own repo. The Open Source lattice tools, critically yosys and nextpnr, are used to produce the bitstream.

The protocol used between the host controller and the HUB75 controller is SPI. The image format is currently fixed at 64 x 32 pixels, with 32 bits per pixel in the form RGBx, where the last byte in the quad is not used. Data is latched in on the rising clock.

The controller uses a pseudo dual port RAM: the writing side is attached to the SPI slave controller with the HUB75 signals being derived from the outputs of the reading side. This RAM is inferred by the code

The RAM is also configured in a double buffered arrangement. While the SPI slave interface is being fed frames from the host, the reading side is showing the previously recieved frame. Switching between buffers is accomplished by the host side toggling the SPI "Slave Select" line. Thus the host should send a frame, flip the SS line, send the next frame, flip the SS line, etc.

Whilst the host to controller image format is fixed at 64 x 32 at 32bpp, the image format used internally is configurable via the Makefile's only config option: BITS_PER_PIXEL. I use 16bpp, as this is the largest bit depth that will fit in the iCE40UP5 on my display interface board. It is the SPI component which will discard the lower bits from each byte recieved.

A fairly complete set of tests has been produced including one which will driive the controller for a single frame. The output from this test can be fed into the unscaled-to-image Go script to produce a BMP file of the output. Another Go script, image-to-raw, can be used to turn a BMP into a data file for feeding to the controller testbench. Tests are also available for the SPI slave interface and the dual port video memory.
