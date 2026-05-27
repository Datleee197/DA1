import numpy as np
import os
import random

def to_q15(val):
    v = int(round(val * 32768.0))
    if v > 32767: v = 32767
    if v < -32768: v = -32768
    return v

def bit_reverse(n, bits):
    return int('{:0{width}b}'.format(n, width=bits)[::-1], 2)

def digit_reverse_radix4(n, digits):
    # Reverse base-4 digits
    res = 0
    for _ in range(digits):
        res = (res << 2) | (n & 3)
        n >>= 2
    return res

def generate_test(test_id, name, x, N=256):
    os.makedirs('sim/test_data', exist_ok=True)
    
    # Write input hex
    with open(f'sim/test_data/fft256_in_{test_id}.hex', 'w') as f:
        for i in range(N):
            re = to_q15(x[i].real) & 0xFFFF
            im = to_q15(x[i].imag) & 0xFFFF
            f.write(f"{re:04x}_{im:04x}\n")

    # Compute FFT
    X = np.fft.fft(x)

    # Scale 1/256
    X_scaled = X / 256.0

    # Write Natural order
    with open(f'sim/test_data/fft256_out_nat_{test_id}.hex', 'w') as f:
        for i in range(N):
            re = to_q15(X_scaled[i].real) & 0xFFFF
            im = to_q15(X_scaled[i].imag) & 0xFFFF
            f.write(f"{re:04x}_{im:04x}\n")

    # Write Bit-Reversed order
    with open(f'sim/test_data/fft256_out_br_{test_id}.hex', 'w') as f:
        for i in range(N):
            idx = bit_reverse(i, 8)
            re = to_q15(X_scaled[idx].real) & 0xFFFF
            im = to_q15(X_scaled[idx].imag) & 0xFFFF
            f.write(f"{re:04x}_{im:04x}\n")
            
    # Write Digit-Reversed order
    with open(f'sim/test_data/fft256_out_dr_{test_id}.hex', 'w') as f:
        for i in range(N):
            idx = digit_reverse_radix4(i, 4)
            re = to_q15(X_scaled[idx].real) & 0xFFFF
            im = to_q15(X_scaled[idx].imag) & 0xFFFF
            f.write(f"{re:04x}_{im:04x}\n")

def main():
    N = 256
    # 1. All Zeros
    x1 = np.zeros(N, dtype=complex)
    generate_test(1, "Zeros", x1)

    # 2. Impulse
    x2 = np.zeros(N, dtype=complex)
    x2[0] = 0.5
    generate_test(2, "Impulse", x2)

    # 3. DC Constant
    x3 = np.full(N, 0.25, dtype=complex)
    generate_test(3, "DC", x3)

    # 4. Tone bin 1
    t = np.arange(N)
    x4 = 0.25 * np.exp(2j * np.pi * 1 * t / N)
    generate_test(4, "ToneBin1", x4)

    # 5. Tone bin 7
    x5 = 0.25 * np.exp(2j * np.pi * 7 * t / N)
    generate_test(5, "ToneBin7", x5)

    # 6. Tone bin 31
    x6 = 0.25 * np.exp(2j * np.pi * 31 * t / N)
    generate_test(6, "ToneBin31", x6)

    # 7. Random
    np.random.seed(42)
    re_rand = np.random.uniform(-0.1, 0.1, N)
    im_rand = np.random.uniform(-0.1, 0.1, N)
    x7 = re_rand + 1j * im_rand
    generate_test(7, "Random", x7)

if __name__ == "__main__":
    main()
