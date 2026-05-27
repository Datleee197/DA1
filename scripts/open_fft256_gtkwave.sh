#!/bin/bash
# scripts/open_fft256_gtkwave.sh

VCD_FILE="sim/build/tb_fft256_r22sdf_top.vcd"
GTKW_FILE="scripts/debug_fft256.gtkw"

if [ ! -f "$VCD_FILE" ]; then
    echo "Error: VCD file not found at $VCD_FILE."
    echo "Please run 'bash scripts/run_fft256_sim.sh' first."
    exit 1
fi

if [ -f "$GTKW_FILE" ]; then
    echo "Opening GTKWave with saved layout ($GTKW_FILE)..."
    gtkwave "$GTKW_FILE" &
else
    echo "Opening GTKWave with generated VCD ($VCD_FILE)..."
    gtkwave "$VCD_FILE" &
fi
