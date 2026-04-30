#!/usr/bin/env bash
set -euo pipefail

# 建议在 workflow 的 make defconfig 后执行。
# 作用：如果 modem/baseband 包又被默认选项或 extra_packages 拉回来，直接让编译失败，避免你刷到假“去基带”固件。

echo "===== Verify no-modem config ====="

if [ ! -f .config ]; then
    echo "ERROR: .config not found. 请在 openwrt 源码目录执行。"
    exit 1
fi

BAD_RE='^CONFIG_PACKAGE_(kmod-qcom-rproc-modem|kmod-rpmsg-wwan-ctrl|kmod-bam-dmux|rmtfs|qmi-modem-410-init|modemmanager|modemmanager-rpcd|luci-app-modemmanager|luci-proto-modemmanager|libqmi|libqmi-glib|qmi-utils|qmi-utils-json|uqmi|luci-proto-qmi|libmbim|libmbim-glib|mbim-utils|umbim|luci-proto-mbim|libqrtr|libqrtr-glib|qrtr|qrtr-ns|wwan|chat|comgt|comgt-ncm|comgt-directip|DbusSmsForwardCPlus|luci-app-dbus-sms-forward|luci-app-sms-tool|sms-tool|kmod-usb-net-qmi-wwan|kmod-usb-net-cdc-mbim|kmod-usb-net-cdc-ncm|kmod-usb-net-huawei-cdc-ncm|kmod-usb-serial-option|kmod-usb-serial-wwan|kmod-usb-wdm)=(y|m)$'

if grep -E "$BAD_RE" .config; then
    echo "ERROR: modem/baseband packages are still enabled."
    exit 1
fi

if grep -E '^CONFIG_PACKAGE_qcom-msm8916-modem-openstick-.*-firmware=(y|m)$' .config; then
    echo "ERROR: MSM8916 OpenStick modem firmware is still enabled."
    exit 1
fi

if grep -E '^CONFIG_PACKAGE_.*modem.*firmware=(y|m)$' .config; then
    echo "ERROR: modem firmware-like package is still enabled."
    exit 1
fi

# Wi-Fi 必须还在。
if ! grep -Eq '^CONFIG_PACKAGE_kmod-wcn36xx=y$' .config; then
    echo "ERROR: kmod-wcn36xx not enabled. Wi-Fi may be broken."
    exit 1
fi

if ! grep -Eq '^CONFIG_PACKAGE_kmod-rproc-wcnss=y$' .config; then
    echo "ERROR: kmod-rproc-wcnss not enabled. WCNSS/Wi-Fi may be broken."
    exit 1
fi

echo "OK: no modem/baseband packages enabled; Wi-Fi/WCNSS still enabled."

echo "===== Verify DTS no-modem patch ====="
DTS_FOUND=0
for f in target/linux/msm89xx/dts/msm8916.dtsi target/linux/*/dts/msm8916.dtsi; do
    [ -f "$f" ] || continue
    DTS_FOUND=1
    echo "--- $f ---"
    grep -nA16 -B6 'mpss_mem: mpss@86800000' "$f" || true
    if ! grep -A20 -B2 'mpss_mem: mpss@86800000' "$f" | grep -q '0x0 0x86800000 0x0 0x0'; then
        echo "ERROR: mpss_mem size is not zero in $f"
        exit 1
    fi
    if ! grep -A25 -B2 'mpss_mem: mpss@86800000' "$f" | grep -q 'status = "disabled"'; then
        echo "ERROR: mpss_mem is not disabled in $f"
        exit 1
    fi
 done

if [ "$DTS_FOUND" -ne 1 ]; then
    echo "ERROR: msm8916.dtsi not found."
    exit 1
fi

echo "OK: DTS mpss_mem disabled and size set to 0."
