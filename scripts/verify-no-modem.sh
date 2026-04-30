#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-.config}"
DTS_FILE="${2:-target/linux/msm89xx/dts/msm8916.dtsi}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: config file not found: $CONFIG_FILE"
    exit 1
fi

BAD=0
FORBIDDEN_RE='^CONFIG_PACKAGE_(openstick-tweaks|kmod-qcom-rproc-modem|kmod-rpmsg-wwan-ctrl|kmod-bam-dmux|rmtfs|qmi-modem-410-init|modemmanager|modemmanager-rpcd|luci-app-modemmanager|luci-proto-modemmanager|libqmi|libqmi-glib|qmi-utils|qmi-utils-json|uqmi|luci-proto-qmi|libmbim|libmbim-glib|mbim-utils|umbim|luci-proto-mbim|libqrtr|libqrtr-glib|qrtr|qrtr-ns|wwan|chat|comgt|comgt-ncm|comgt-directip|DbusSmsForwardCPlus|luci-app-dbus-sms-forward|luci-app-sms-tool|luci-app-sms-tool-js|sms-tool|luci-app-3ginfo-lite|luci-proto-3g|luci-proto-ncm|modemband|fwupd|lpac|kmod-usb-net-qmi-wwan|kmod-usb-net-cdc-mbim|kmod-usb-net-cdc-ncm|kmod-usb-net-huawei-cdc-ncm|kmod-usb-serial-option|kmod-usb-serial-wwan|kmod-usb-wdm)=y'

if grep -E "$FORBIDDEN_RE" "$CONFIG_FILE"; then
    BAD=1
fi

if grep -E '^CONFIG_PACKAGE_qcom-msm8916-modem-openstick-.*-firmware=y' "$CONFIG_FILE"; then
    BAD=1
fi

if [ "$BAD" = "1" ]; then
    echo "ERROR: modem/baseband/openstick-tweaks packages are still enabled."
    exit 1
fi

echo "OK: modem/baseband/openstick-tweaks packages disabled."

echo "===== Wi-Fi/WCNSS entries ====="
grep -E '^CONFIG_PACKAGE_(kmod-rproc-wcnss|kmod-wcn36xx)=y' "$CONFIG_FILE" || true

if [ -f "$DTS_FILE" ]; then
    python3 - "$DTS_FILE" <<'PY_CHECK_DTS'
from pathlib import Path
import re
import sys
path = Path(sys.argv[1])
text = path.read_text()
m = re.search(r'mpss_mem:\s*mpss@86800000\s*\{.*?\};', text, re.S)
if not m:
    raise SystemExit("ERROR: mpss_mem node not found")
node = m.group(0)
print(node)
if not re.search(r'reg\s*=\s*<0x0\s+0x86800000\s+0x0\s+0x0>', node):
    raise SystemExit("ERROR: mpss_mem has not been changed to zero size")
if 'status = "disabled"' not in node:
    raise SystemExit("ERROR: mpss_mem is not disabled")
print("OK: mpss_mem zero-size patched and disabled.")
PY_CHECK_DTS
else
    echo "WARN: DTS file not found: $DTS_FILE"
fi
