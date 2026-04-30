#!/usr/bin/env bash
set -euo pipefail

echo "===== DIY PART2: remove MSM8916 modem/baseband packages ====="

if [ ! -f .config ]; then
    echo "ERROR: .config not found."
    echo "Make sure workflow has copied config/<profile>.config to openwrt/.config before running diy-part2.sh"
    exit 1
fi

echo "===== Replace default LuCI theme if possible ====="
sed -i 's/luci-theme-material/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

echo "===== Remove SMS/modem related package source directories ====="
rm -rf package/DbusSmsForwardCPlus 2>/dev/null || true
rm -rf package/feeds/*/DbusSmsForwardCPlus 2>/dev/null || true
rm -rf package/feeds/*/luci-app-dbus-sms-forward 2>/dev/null || true
rm -rf package/feeds/*/luci-app-sms-tool 2>/dev/null || true
rm -rf package/feeds/*/sms-tool 2>/dev/null || true

rm -rf package/feeds/*/modemmanager 2>/dev/null || true
rm -rf package/feeds/*/modemmanager-rpcd 2>/dev/null || true
rm -rf package/feeds/*/luci-app-modemmanager 2>/dev/null || true
rm -rf package/feeds/*/luci-proto-modemmanager 2>/dev/null || true

rm -rf package/feeds/*/uqmi 2>/dev/null || true
rm -rf package/feeds/*/umbim 2>/dev/null || true
rm -rf package/feeds/*/qmi-utils 2>/dev/null || true
rm -rf package/feeds/*/mbim-utils 2>/dev/null || true
rm -rf package/feeds/*/libqmi 2>/dev/null || true
rm -rf package/feeds/*/libmbim 2>/dev/null || true
rm -rf package/feeds/*/luci-proto-qmi 2>/dev/null || true
rm -rf package/feeds/*/luci-proto-mbim 2>/dev/null || true

rm -rf package/feeds/*/rmtfs 2>/dev/null || true
rm -rf package/feeds/*/qmi-modem-410-init 2>/dev/null || true

disable_pkg() {
    local p="$1"

    sed -i \
        -e "/^CONFIG_PACKAGE_${p}=.*/d" \
        -e "/^# CONFIG_PACKAGE_${p} is not set/d" \
        -e "/^CONFIG_DEFAULT_${p}=.*/d" \
        -e "/^# CONFIG_DEFAULT_${p} is not set/d" \
        .config 2>/dev/null || true

    printf '# CONFIG_PACKAGE_%s is not set\n' "$p" >> .config
    printf '# CONFIG_DEFAULT_%s is not set\n' "$p" >> .config
}

echo "===== Disable fixed modem/baseband package list ====="

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
sms-tool
kmod-usb-net-qmi-wwan
kmod-usb-net-cdc-mbim
kmod-usb-net-cdc-ncm
kmod-usb-net-huawei-cdc-ncm
kmod-usb-serial-option
kmod-usb-serial-wwan
kmod-usb-wdm
"

for p in $DISABLE_PKGS; do
    disable_pkg "$p"
done

echo "===== Auto-disable modem firmware/packages already found in .config ====="

AUTO_DISABLE_SYMBOLS="$(
    grep -E '^CONFIG_(PACKAGE|DEFAULT)_(qcom-msm8916-modem-openstick-.*-firmware|.*modem.*firmware|.*modem.*|.*qmi.*|.*mbim.*|.*wwan.*|.*rmtfs.*|.*bam-dmux.*)=(y|m)' .config 2>/dev/null \
        | sed -E 's/^CONFIG_(PACKAGE|DEFAULT)_//' \
        | sed -E 's/=(y|m)$//' \
        | sort -u || true
)"

for p in $AUTO_DISABLE_SYMBOLS; do
    echo "Disable auto-detected modem/baseband package: $p"
    disable_pkg "$p"
done

echo "===== Disable known OpenStick MSM8916 modem firmware packages ====="

for p in \
qcom-msm8916-modem-openstick-ufi003-firmware \
qcom-msm8916-modem-openstick-ufi001c-firmware \
qcom-msm8916-modem-openstick-ufi001b-firmware \
qcom-msm8916-modem-openstick-ufi103s-firmware \
qcom-msm8916-modem-openstick-jz02v10-firmware \
qcom-msm8916-modem-openstick-qrzl903-firmware \
qcom-msm8916-modem-openstick-w001-firmware \
qcom-msm8916-modem-openstick-uz801-firmware \
qcom-msm8916-modem-openstick-mf32-firmware \
qcom-msm8916-modem-openstick-mf601-firmware \
qcom-msm8916-modem-openstick-wf2-firmware \
qcom-msm8916-modem-openstick-sp970v10-firmware \
qcom-msm8916-modem-openstick-sp970v11-firmware
do
    disable_pkg "$p"
done

echo "===== Keep Wi-Fi/WCNSS packages ====="

KEEP_WIFI_PKGS="
kmod-rproc-wcnss
kmod-wcn36xx
"

for p in $KEEP_WIFI_PKGS; do
    sed -i \
        -e "/^CONFIG_PACKAGE_${p}=.*/d" \
        -e "/^# CONFIG_PACKAGE_${p} is not set/d" \
        .config 2>/dev/null || true

    printf 'CONFIG_PACKAGE_%s=y\n' "$p" >> .config
done

# Do not force-disable wpad. Keep whatever OpenWrt selected.
sed -i '/^# CONFIG_PACKAGE_wpad-basic/d' .config 2>/dev/null || true
sed -i '/^# CONFIG_PACKAGE_wpad-basic-wolfssl/d' .config 2>/dev/null || true

echo "===== Final Wi-Fi/WCNSS entries ====="
grep -Ei 'wcnss|wcn36xx|wpad-basic' .config || true

echo "===== Final modem/baseband related entries after cleanup ====="
grep -Ei 'modem|qmi|mbim|wwan|qrtr|bam-dmux|rmtfs|sms|DbusSms' .config || true

echo "===== DIY PART2 done ====="