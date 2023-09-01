#!/bin/bash

OFL_BIN=./openFPGALoader`getconf LONG_BIT`

if [ ! -f ${OFL_BIN} ]; then
echo "The binary ${OFL_BIN} does not exist"
exit 1
fi

if [ ! -f "flash-connect.hex.bin" ]; then
echo "File flash-connect.hex.bin does not exist"
exit 1
fi

if [ ! -f "a314-1000.hex.bin" ]; then
echo "File a314-1000.hex.bin does not exist"
exit 1
fi

set -x

# Set all pins as inputs.
gpioget gpiochip0 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27

# Reset FPGA with SS low.
gpioset gpiochip0 19=0 8=0 2=0
sleep 0.1
gpioset gpiochip0 19=1
sleep 0.1
gpioget gpiochip0 2
sleep 0.1
gpioget gpiochip0 19 8

# Write flash-connect configuration through JTAG interface.
gpioset gpiochip0 3=0
sleep 0.1
${OFL_BIN} -v -c libgpiod --pins 12:16:5:7 -m flash-connect.hex.bin
sleep 0.1
gpioget gpiochip0 3

# Write a314-1000 configuration to flash memory through SPI interface.
sleep 0.1
gpioset gpiochip0 17=1
sleep 0.1
${OFL_BIN} -v -b a314-1000-spi a314-1000.hex.bin

# Restore all pins as inputs.
gpioget gpiochip0 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27

# Reset FPGA with SS high.
gpioset gpiochip0 19=0 8=1 2=0
sleep 0.1
gpioset gpiochip0 19=1
sleep 0.1
gpioget gpiochip0 2
sleep 0.1
gpioget gpiochip0 19 8
