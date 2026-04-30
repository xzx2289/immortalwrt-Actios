#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-.config}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: config file not found: $CONFIG_FILE"
    exit 1
fi

disable_pkg() {
    local p="$1"
    sed -i \
        -e "/^CONFIG_PACKAGE_${p}=.*/d" \
        -e "/^# CONFIG_PACKAGE_${p} is not set/d" \
        -e "/^CONFIG_DEFAULT_${p}=.*/d" \
        -e "/^# CONFIG_DEFAULT_${p} is not set/d" \
        "$CONFIG_FILE" 2>/dev/null || true
    printf '# CONFIG_PACKAGE_%s is not set\n' "$p" >> "$CONFIG_FILE"
    printf '# CONFIG_DEFAULT_%s is not set\n' "$p" >> "$CONFIG_FILE"
}

DISABLE_PKGS="
kmod-qcom-rproc-modem
kmod-rpmsg-wwan-ctrl
kmod-bam-dmux
rmtfs
qmi-modem-410-init
modemmanager
modemmanager-rpcd
luci-app-modemmanager
luci-proto-modemmanager
libqmi
libqmi-glib
qmi-utils
qmi-utils-json
uqmi
luci-proto-qmi
libmbim
libmbim-glib
mbim-utils
umbim
luci-proto-mbim
libqrtr
libqrtr-glib
qrtr
qrtr-ns
wwan
chat
comgt
comgt-ncm
comgt-directip
DbusSmsForwardCPlus
luci-app-dbus-sms-forward
luci-app-sms-tool
luci-app-sms-tool-js
sms-tool
luci-app-3ginfo-lite
luci-proto-3g
luci-proto-ncm
modemband
fwupd
lpac
kmod-usb-net-qmi-wwan
kmod-usb-net-cdc-mbim
kmod-usb-net-cdc-ncm
kmod-usb-net-huawei-cdc-ncm
kmod-usb-serial-option
kmod-usb-serial-wwan
kmod-usb-wdm
openstick-tweaks
qcom-msm8916-modem-openstick-ufi003-firmware
qcom-msm8916-modem-openstick-ufi001c-firmware
qcom-msm8916-modem-openstick-ufi001b-firmware
qcom-msm8916-modem-openstick-ufi103s-firmware
qcom-msm8916-modem-openstick-jz02v10-firmware
qcom-msm8916-modem-openstick-qrzl903-firmware
qcom-msm8916-modem-openstick-w001-firmware
qcom-msm8916-modem-openstick-uz801-firmware
qcom-msm8916-modem-openstick-mf32-firmware
qcom-msm8916-modem-openstick-mf601-firmware
qcom-msm8916-modem-openstick-wf2-firmware
qcom-msm8916-modem-openstick-sp970v10-firmware
qcom-msm8916-modem-openstick-sp970v11-firmware
"

for p in $DISABLE_PKGS; do
    disable_pkg "$p"
done

AUTO_DISABLE_SYMBOLS="$(grep -E '^CONFIG_(PACKAGE|DEFAULT)_(qcom-msm8916-modem-openstick-.*-firmware|.*modem.*|.*qmi.*|.*mbim.*|.*wwan.*|.*rmtfs.*|.*bam-dmux.*|.*sms.*|.*3ginfo.*)=(y|m)' "$CONFIG_FILE" 2>/dev/null \
    | sed -E 's/^CONFIG_(PACKAGE|DEFAULT)_//' \
    | sed -E 's/=(y|m)$//' \
    | sort -u || true)"

for p in $AUTO_DISABLE_SYMBOLS; do
    disable_pkg "$p"
done

for p in kmod-rproc-wcnss kmod-wcn36xx; do
    sed -i \
        -e "/^CONFIG_PACKAGE_${p}=.*/d" \
        -e "/^# CONFIG_PACKAGE_${p} is not set/d" \
        "$CONFIG_FILE" 2>/dev/null || true
    printf 'CONFIG_PACKAGE_%s=y\n' "$p" >> "$CONFIG_FILE"
done

sed -i '/^# CONFIG_PACKAGE_wpad-basic/d' "$CONFIG_FILE" 2>/dev/null || true
sed -i '/^# CONFIG_PACKAGE_wpad-basic-openssl/d' "$CONFIG_FILE" 2>/dev/null || true
sed -i '/^# CONFIG_PACKAGE_wpad-basic-wolfssl/d' "$CONFIG_FILE" 2>/dev/null || true

echo "OK: no-modem config cleanup applied to $CONFIG_FILE"
