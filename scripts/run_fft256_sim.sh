#!/bin/bash
# scripts/run_fft256_sim.sh

echo "============================================"
echo "    Running FFT-256 Simulation Suite        "
echo "============================================"

# Ensure build directory exists
mkdir -p sim/build

echo "1. Generating test vectors..."
python scripts/golden_fft256.py

echo "2. Compiling RTL and Testbench..."
iverilog -g2012 -o sim/build/fft256.vvp rtl/*.sv sim/tb_fft256_r22sdf_top.sv

echo "3. Running Simulation..."
# Must run from project root so that $readmemh paths (e.g., sim/test_data/...) are valid
vvp sim/build/fft256.vvp

echo "4. Moving generated VCD to sim/build/..."
if [ -f "tb_fft256_r22sdf_top.vcd" ]; then
    mv tb_fft256_r22sdf_top.vcd sim/build/
fi

echo "Simulation complete!"
