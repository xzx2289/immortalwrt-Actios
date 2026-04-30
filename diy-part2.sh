#!/usr/bin/env bash
set -euo pipefail

echo "===== DIY PART2: remove MSM8916 modem/baseband packages ====="

if [ ! -f .config ]; then
  echo "ERROR: .config not found. Please confirm workflow copied config/<profile>.config to openwrt/.config first."
  exit 1
fi

sed -i 's/luci-theme-material/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
rm -rf package/DbusSmsForwardCPlus package/feeds/*/DbusSmsForwardCPlus 2>/dev/null || true

CLEANUP="${GITHUB_WORKSPACE:-$(pwd)}/scripts/cleanup-no-modem-config.sh"
chmod +x "$CLEANUP" 2>/dev/null || true
"$CLEANUP"

echo "===== Wi-Fi/WCNSS packages kept ====="
grep -Ei 'wcnss|wcn36xx|wpad-basic' .config || true

echo "===== Modem/baseband related config after cleanup ====="
grep -Ei 'modem|qmi|mbim|wwan|qrtr|bam-dmux|rmtfs|sms|DbusSms' .config || true

echo "===== DIY PART2 done ====="
