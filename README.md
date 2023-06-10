# A314-1000 gateware

A314-1000 is a variant of A314 for the Amiga 1000.

This repository contains the gateware for the Trion T8 FPGA on the A314-1000 board.

The hardware can be found here:
[https://github.com/Eriond/A314-1000-PCB/](https://github.com/Eriond/A314-1000-PCB/).

The software is available in the `a314-1000` branch in the A314 repository:
[https://github.com/niklasekstrom/a314/tree/a314-1000](https://github.com/niklasekstrom/a314/tree/a314-1000).

The HDL for A314-1000 is available in the [a314-1000](a314-1000) subdirectory.

In the [flash-connect](flash-connect) subdirectory there is a simple HDL that lets
the Raspberry Pi connect directly to the flash memory chip on the PCB. This is used
to program a new configuration to the flash memory chip. When the FPGA is reset it
loads the configuration from the flash memory.

## Compiling

The projects are compiled using a recent version of Efinity which is available for free here:
[https://www.efinixinc.com/products-efinity.html](https://www.efinixinc.com/products-efinity.html).
The compiled binary files are available in the release for this repository.

The Python script [hextobin.py](hextobin.py) is used to convert the output from Efinity,
which is in hex format, to a binary format that is used by the programming software.

## Programming

The programming is done from the Raspberry Pi on the A314-1000 board.

The programming is done in two steps. In the first step, the flash-connect configuration
is written to the FPGA using the JTAG interface. In the second step, the a314-1000
configuration is written to the flash memory using a SPI interface.
After this, the FPGA will load the configuration from the flash memory on reset.

A modified version of [openFPGALoader](https://trabucayre.github.io/openFPGALoader/) is
available that can perform both steps described above.
The source for the modified version of openFPGALoader is available here:
[https://github.com/niklasekstrom/openFPGALoader/tree/a314-1000-spi](https://github.com/niklasekstrom/openFPGALoader/tree/a314-1000-spi).

The bash script [program_flash.sh](program_flash.sh) will perform both steps.
Both openFPGALoader and the script use `libgpiod` to toggle GPIO pins.
Install libgpiod with: `sudo apt install libgpiod-dev`.

Note that a314d must be stopped before programming!
Shutdown a314d first using the command `sudo systemctl stop a314d`.
After the programming is done you restart it with `sudo systemctl start a314d`.
