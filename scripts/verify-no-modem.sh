#!/usr/bin/env bash
set -euo pipefail

if [ ! -f .config ]; then
  echo "ERROR: .config not found. Please run in OpenWrt source directory."
  exit 1
fi

echo "===== Verify no-modem config ====="
BAD_RE='^CONFIG_(PACKAGE|DEFAULT)_(kmod-qcom-rproc-modem|kmod-rpmsg-wwan-ctrl|kmod-bam-dmux|rmtfs|qmi-modem-410-init|modemmanager|modemmanager-rpcd|luci-app-modemmanager|luci-proto-modemmanager|libqmi|libqmi-glib|qmi-utils|qmi-utils-json|uqmi|luci-proto-qmi|libmbim|libmbim-glib|mbim-utils|umbim|luci-proto-mbim|libqrtr|libqrtr-glib|qrtr|qrtr-ns|wwan|chat|comgt|comgt-ncm|comgt-directip|DbusSmsForwardCPlus|luci-app-dbus-sms-forward|luci-app-sms-tool|sms-tool|kmod-usb-net-qmi-wwan|kmod-usb-net-cdc-mbim|kmod-usb-net-cdc-ncm|kmod-usb-net-huawei-cdc-ncm|kmod-usb-serial-option|kmod-usb-serial-wwan|kmod-usb-wdm)=(y|m)$'
if grep -E "$BAD_RE" .config; then
  echo "ERROR: modem/baseband packages are still enabled."
  exit 1
fi

if grep -E '^CONFIG_(PACKAGE|DEFAULT)_qcom-msm8916-modem-openstick-.*-firmware=(y|m)$' .config; then
  echo "ERROR: MSM8916 OpenStick modem firmware is still enabled."
  exit 1
fi

if grep -E '^CONFIG_(PACKAGE|DEFAULT)_.*modem.*firmware=(y|m)$' .config; then
  echo "ERROR: modem firmware-like package is still enabled."
  exit 1
fi

if ! grep -Eq '^CONFIG_PACKAGE_kmod-wcn36xx=y$' .config; then
  echo "ERROR: kmod-wcn36xx not enabled. Wi-Fi may be broken."
  exit 1
fi

if ! grep -Eq '^CONFIG_PACKAGE_kmod-rproc-wcnss=y$' .config; then
  echo "ERROR: kmod-rproc-wcnss not enabled. Wi-Fi remoteproc may be broken."
  exit 1
fi

echo "OK: modem/baseband packages disabled; Wi-Fi/WCNSS still enabled."

echo "===== Verify DTS no-modem patch ====="
python3 <<'PYVERIFY'
from pathlib import Path
import re
import sys

path = Path("target/linux/msm89xx/dts/msm8916.dtsi")
if not path.exists():
    sys.exit("ERROR: target/linux/msm89xx/dts/msm8916.dtsi not found")
text = path.read_text()
m = re.search(r'mpss_mem:\s*mpss@86800000\s*\{.*?\n\s*\};', text, re.S)
if not m:
    sys.exit("ERROR: mpss_mem node not found")
node = m.group(0)
print(node)
if not re.search(r'reg\s*=\s*<0x0\s+0x86800000\s+0x0\s+0x0>', node):
    sys.exit("ERROR: mpss_mem has not been changed to zero size")
if 'status = "disabled"' not in node:
    sys.exit("ERROR: mpss_mem is not disabled")
print("OK: mpss_mem zero-size patched.")
PYVERIFY
