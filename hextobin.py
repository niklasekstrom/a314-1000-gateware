#!/usr/bin/env python3
import sys

if len(sys.argv) < 2 or not sys.argv[1].endswith('.hex'):
    print(f'Usage: {sys.argv[0]} <hexfile>')
    print('  where filename <hexfile> must have .hex file extension')
    exit(0)

hex_name = sys.argv[1]
bin_name = hex_name[:-3] + 'bin'

with open(hex_name, 'rt') as f:
    text = f.read()

lines = text.split('\n')
output = bytes([int(l, 16) for l in lines if l != ''])

with open(bin_name, 'wb') as f:
    f.write(output)
