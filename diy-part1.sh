#!/usr/bin/env bash
set -euo pipefail

echo "===== DIY PART1: no-modem DTS patch for MSM8916 ====="
OPENWRT_DIR="${OPENWRT_DIR:-$(pwd)}"
PATCHER="${GITHUB_WORKSPACE:-$(pwd)}/scripts/patches/disable-msm8916-modem.py"

echo "GITHUB_WORKSPACE=${GITHUB_WORKSPACE:-unset}"
echo "OPENWRT_DIR=$OPENWRT_DIR"

if [ ! -f "$PATCHER" ]; then
  echo "ERROR: patcher not found: $PATCHER"
  exit 1
fi

python3 "$PATCHER" "$OPENWRT_DIR"

echo "===== DTS patch result ====="
DTS="$OPENWRT_DIR/target/linux/msm89xx/dts/msm8916.dtsi"
if [ -f "$DTS" ]; then
  grep -nA16 -B4 'mpss_mem: mpss@86800000' "$DTS" || true
  grep -nA8 -B4 'rmtfs@86700000' "$DTS" || true
else
  echo "WARNING: $DTS not found after patch."
fi

echo "===== DIY PART1 done ====="
