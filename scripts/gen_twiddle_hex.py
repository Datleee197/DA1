#!/usr/bin/env python3
"""gen_twiddle_hex.py
Generate twiddle-factor ROM hex files for the R2²SDF FFT-256.

Each file contains M entries of W_M^k = exp(-j*2*pi*k/M), k = 0 .. M-1,
quantized to signed Q1.15 fixed-point.

ROM word format (one 32-bit hex value per line):
    upper 16 bits = tw_re  (signed Q1.15)
    lower 16 bits = tw_im  (signed Q1.15)

Saturation: +1.0 is not exactly representable in Q1.15 (max = 32767/32768).
The coefficient +1.0 is saturated to 32767 = 0x7FFF.

Output files:
    tw256.hex  (256 entries, W_256)
    tw64.hex   ( 64 entries, W_64)
    tw16.hex   ( 16 entries, W_16)
"""

import math
import os
import sys


def float_to_q15(x: float) -> int:
    """Convert a float in [-1.0, +1.0] to signed Q1.15 (16-bit).
    
    Truncates toward zero (floor for positive, ceil for negative).
    Saturates +1.0 to 32767.
    """
    scaled = x * 32768.0
    # Truncate toward zero
    if scaled >= 0:
        val = int(math.floor(scaled))
    else:
        val = int(math.ceil(scaled))
    # Saturate
    if val > 32767:
        val = 32767
    if val < -32768:
        val = -32768
    return val


def to_unsigned16(val: int) -> int:
    """Convert a signed 16-bit integer to its unsigned 16-bit two's complement."""
    if val < 0:
        val = val + 65536
    return val & 0xFFFF


def generate_twiddle_hex(M: int, filename: str):
    """Generate a hex file with M twiddle factors W_M^k, k = 0 .. M-1."""
    with open(filename, 'w') as f:
        for k in range(M):
            angle = -2.0 * math.pi * k / M
            tw_re_f = math.cos(angle)
            tw_im_f = math.sin(angle)
            tw_re = float_to_q15(tw_re_f)
            tw_im = float_to_q15(tw_im_f)
            word = (to_unsigned16(tw_re) << 16) | to_unsigned16(tw_im)
            f.write(f"{word:08X}\n")
    print(f"Generated {filename}: {M} entries")


def print_known_values(M: int):
    """Print the expected Q1.15 values for cardinal points (for verification)."""
    print(f"\n  W_{M} cardinal points:")
    for k, label in [(0, "W^0 ~ 1+j0"),
                     (M//4, f"W^{M//4} ~ 0-j1"),
                     (M//2, f"W^{M//2} ~ -1+j0"),
                     (3*M//4, f"W^{3*M//4} ~ 0+j1")]:
        angle = -2.0 * math.pi * k / M
        tw_re_f = math.cos(angle)
        tw_im_f = math.sin(angle)
        tw_re = float_to_q15(tw_re_f)
        tw_im = float_to_q15(tw_im_f)
        word = (to_unsigned16(tw_re) << 16) | to_unsigned16(tw_im)
        print(f"    k={k:3d} ({label:20s}): re={tw_re:6d} (0x{to_unsigned16(tw_re):04X})"
              f"  im={tw_im:6d} (0x{to_unsigned16(tw_im):04X})"
              f"  word=0x{word:08X}")


def main():
    # Output directory: same as script location or specified
    if len(sys.argv) > 1:
        out_dir = sys.argv[1]
    else:
        out_dir = os.path.dirname(os.path.abspath(__file__))
        out_dir = os.path.join(out_dir, '..', 'rom')

    os.makedirs(out_dir, exist_ok=True)

    for M in [256, 64, 16]:
        filename = os.path.join(out_dir, f"tw{M}.hex")
        generate_twiddle_hex(M, filename)
        print_known_values(M)

    print("\nDone.")


if __name__ == "__main__":
    main()
