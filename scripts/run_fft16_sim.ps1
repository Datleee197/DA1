# scripts/run_fft16_sim.ps1

Write-Host "============================================"
Write-Host "    Running FFT-16 Simulation Sandbox       "
Write-Host "============================================"

# Ensure build directory exists
if (-Not (Test-Path "sim/build")) {
    New-Item -ItemType Directory -Force -Path "sim/build" | Out-Null
}

Write-Host "1. Generating test vectors..."
python scripts/golden_fft16.py

Write-Host "2. Compiling RTL and Testbench..."
iverilog -g2012 -o sim/build/fft16.vvp rtl/*.sv sim/tb_fft16_r22sdf_top.sv

Write-Host "3. Running Simulation..."
# Must run from project root so that $readmemh paths (e.g., sim/test_data/...) are valid
vvp sim/build/fft16.vvp

Write-Host "4. Moving generated VCD to sim/build/..."
if (Test-Path "tb_fft16_r22sdf_top.vcd") {
    Move-Item -Path "tb_fft16_r22sdf_top.vcd" -Destination "sim/build/" -Force
}

Write-Host "Simulation complete!"
