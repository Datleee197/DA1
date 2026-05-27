import numpy as np
import sys
import struct

def to_q15(val):
    # Truncate towards -infinity (floor)
    v = int(np.floor(val * 32768.0))
    if v > 32767: v = 32767
    if v < -32768: v = -32768
    return v

def generate_golden(test_name, input_re, input_im):
    c_in = np.array(input_re) + 1j * np.array(input_im)
    
    # Compute FFT
    c_out = np.fft.fft(c_in)
    
    # Total scale factor for 4 radix-2 stages = 1/16
    c_out_scaled = c_out / 16.0
    
    out_re = [to_q15(x.real) for x in c_out_scaled]
    out_im = [to_q15(x.imag) for x in c_out_scaled]
    
    # Different orderings
    natural = list(range(16))
    
    def bit_reverse(i):
        return int(f"{i:04b}"[::-1], 2)
    bit_reversed = [bit_reverse(i) for i in range(16)]
    
    def radix4_digit_reverse(i):
        # N=16, two radix-4 digits. i = d1*4 + d0 -> d0*4 + d1
        return (i % 4) * 4 + (i // 4)
    digit_reversed = [radix4_digit_reverse(i) for i in range(16)]
    
    # Save to files
    prefix = test_name.replace(" ", "_").replace(":", "").lower()
    
    with open(f"sim/{prefix}_in.hex", "w") as f:
        for i in range(16):
            re_hex = to_q15(c_in[i].real) & 0xFFFF
            im_hex = to_q15(c_in[i].imag) & 0xFFFF
            f.write(f"{re_hex:04x}{im_hex:04x}\n")
            
    with open(f"sim/{prefix}_out_nat.hex", "w") as f:
        for i in range(16):
            re_hex = out_re[natural[i]] & 0xFFFF
            im_hex = out_im[natural[i]] & 0xFFFF
            f.write(f"{re_hex:04x}{im_hex:04x}\n")
            
    with open(f"sim/{prefix}_out_br.hex", "w") as f:
        for i in range(16):
            re_hex = out_re[bit_reversed[i]] & 0xFFFF
            im_hex = out_im[bit_reversed[i]] & 0xFFFF
            f.write(f"{re_hex:04x}{im_hex:04x}\n")
            
    with open(f"sim/{prefix}_out_dr.hex", "w") as f:
        for i in range(16):
            re_hex = out_re[digit_reversed[i]] & 0xFFFF
            im_hex = out_im[digit_reversed[i]] & 0xFFFF
            f.write(f"{re_hex:04x}{im_hex:04x}\n")

def main():
    # 1. all zeros
    generate_golden("Test 1: All Zeros", np.zeros(16), np.zeros(16))
    
    # 2. impulse
    re = np.zeros(16); re[0] = 0.5
    generate_golden("Test 2: Impulse", re, np.zeros(16))
    
    # 3. DC constant
    generate_golden("Test 3: DC Constant", np.full(16, 0.25), np.zeros(16))
    
    # 4. single tone bin 1
    t = np.arange(16)
    re = 0.5 * np.cos(2 * np.pi * 1 * t / 16)
    im = 0.5 * np.sin(2 * np.pi * 1 * t / 16)
    generate_golden("Test 4: Tone Bin 1", re, im)
    
    # 5. single tone bin 3
    re = 0.25 * np.cos(2 * np.pi * 3 * t / 16)
    im = 0.25 * np.sin(2 * np.pi * 3 * t / 16)
    generate_golden("Test 5: Tone Bin 3", re, im)
    
    # 6. random
    np.random.seed(42)
    re = np.random.uniform(-0.5, 0.5, 16)
    im = np.random.uniform(-0.5, 0.5, 16)
    generate_golden("Test 6: Random", re, im)

if __name__ == "__main__":
    main()
