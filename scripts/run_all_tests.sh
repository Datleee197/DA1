#!/bin/bash
# scripts/run_all_tests.sh

echo "============================================"
echo "    Running Full Verification Regression    "
echo "============================================"

# Make scripts executable if they aren't
chmod +x scripts/*.sh

echo ""
echo ">>> STEP 1: Running Module-level Tests <<<"
bash scripts/run_module_tests.sh

echo ""
echo ">>> STEP 2: Running FFT-16 Sandbox <<<"
bash scripts/run_fft16_sim.sh

echo ""
echo ">>> STEP 3: Running FFT-256 Full Architecture <<<"
bash scripts/run_fft256_sim.sh

echo ""
echo "============================================"
echo "    All Verification Suites Completed!      "
echo "============================================"
