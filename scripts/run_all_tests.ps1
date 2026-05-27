# scripts/run_all_tests.ps1

Write-Host "============================================"
Write-Host "    Running Full Verification Regression    "
Write-Host "============================================"

Write-Host ""
Write-Host ">>> STEP 1: Running Module-level Tests <<<"
& bash scripts/run_module_tests.sh

Write-Host ""
Write-Host ">>> STEP 2: Running FFT-16 Sandbox <<<"
powershell -ExecutionPolicy Bypass -File scripts/run_fft16_sim.ps1

Write-Host ""
Write-Host ">>> STEP 3: Running FFT-256 Full Architecture <<<"
powershell -ExecutionPolicy Bypass -File scripts/run_fft256_sim.ps1

Write-Host ""
Write-Host "============================================"
Write-Host "    All Verification Suites Completed!      "
Write-Host "============================================"
