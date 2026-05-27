# scripts/open_fft256_gtkwave.ps1

$VCD_FILE = "sim\build\tb_fft256_r22sdf_top.vcd"
$GTKW_FILE = "scripts\debug_fft256.gtkw"

if (-Not (Test-Path $VCD_FILE)) {
    Write-Host "Error: VCD file not found at $VCD_FILE." -ForegroundColor Red
    Write-Host "Please run 'powershell -File scripts/run_fft256_sim.ps1' first."
    exit 1
}

if (Test-Path $GTKW_FILE) {
    Write-Host "Opening GTKWave with saved layout ($GTKW_FILE)..."
    Start-Process gtkwave -ArgumentList $GTKW_FILE
} else {
    Write-Host "Opening GTKWave with generated VCD ($VCD_FILE)..."
    Start-Process gtkwave -ArgumentList $VCD_FILE
}
