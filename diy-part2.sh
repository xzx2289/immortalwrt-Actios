#!/usr/bin/env bash
set -euo pipefail

echo "===== DIY PART2: no-modem cleanup for MSM8916/OpenStick ====="

if [ ! -f .config ]; then
    echo "ERROR: .config not found. Run this script inside the OpenWrt source tree after loading config/<profile>.config."
    exit 1
fi

# Optional: switch LuCI theme to Argon when possible.
sed -i 's/luci-theme-material/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

# The previous build failed because openstick-tweaks was still selected while
# qmi-modem-410-init and luci-proto-modemmanager had already been removed.
# Patch its Makefile dependencies as a safety net, then also disable the package.
for f in \
    feeds/openstick/utils/openstick-tweaks/Makefile \
    package/feeds/openstick/openstick-tweaks/Makefile
do
    if [ -f "$f" ]; then
        echo "Patch openstick-tweaks dependency list: $f"
        sed -i -E 's/\+qmi-modem-410-init([[:space:]\\]|$)/\1/g' "$f" || true
        sed -i -E 's/\+luci-proto-modemmanager([[:space:]\\]|$)/\1/g' "$f" || true
        sed -i -E 's/\+modemmanager([[:space:]\\]|$)/\1/g' "$f" || true
        sed -i -E 's/\+libqmi([[:space:]\\]|$)/\1/g' "$f" || true
        sed -i -E 's/\+libmbim([[:space:]\\]|$)/\1/g' "$f" || true
    fi
done

# Remove openstick-tweaks from target default package lists so make defconfig
# does not bring it back as a device default.
if [ -d target/linux/msm89xx ]; then
    grep -RIl 'openstick-tweaks' target/linux/msm89xx 2>/dev/null | while IFS= read -r f; do
        echo "Remove openstick-tweaks from device defaults: $f"
        sed -i -E 's/(^|[[:space:]])openstick-tweaks([[:space:]\\]|$)/\1\2/g' "$f" || true
    done
fi

# Remove package source directories that are only for cellular modem/SIM/SMS.
# Do not remove WCNSS/Wi-Fi packages.
for d in \
    package/DbusSmsForwardCPlus \
    package/feeds/*/DbusSmsForwardCPlus \
    package/feeds/*/luci-app-dbus-sms-forward \
    package/feeds/*/luci-app-sms-tool \
    package/feeds/*/luci-app-sms-tool-js \
    package/feeds/*/sms-tool \
    package/feeds/*/luci-app-3ginfo-lite \
    package/feeds/*/luci-proto-3g \
    package/feeds/*/luci-proto-ncm \
    package/feeds/*/modemband
do
    rm -rf $d 2>/dev/null || true
done

# Disable packages in .config. This function removes both PACKAGE and DEFAULT
# entries, then appends explicit "not set" lines.
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

# Auto-disable any already-selected modem firmware package not listed above.
AUTO_DISABLE_SYMBOLS="$(grep -E '^CONFIG_(PACKAGE|DEFAULT)_(qcom-msm8916-modem-openstick-.*-firmware|.*modem.*|.*qmi.*|.*mbim.*|.*wwan.*|.*rmtfs.*|.*bam-dmux.*|.*sms.*|.*3ginfo.*)=(y|m)' .config 2>/dev/null \
    | sed -E 's/^CONFIG_(PACKAGE|DEFAULT)_//' \
    | sed -E 's/=(y|m)$//' \
    | sort -u || true)"

for p in $AUTO_DISABLE_SYMBOLS; do
    echo "Disable auto-detected modem/baseband symbol: $p"
    disable_pkg "$p"
done

# Keep Wi-Fi/WCNSS. These are not modem/MPSS and are required for wireless.
for p in kmod-rproc-wcnss kmod-wcn36xx; do
    sed -i \
        -e "/^CONFIG_PACKAGE_${p}=.*/d" \
        -e "/^# CONFIG_PACKAGE_${p} is not set/d" \
        .config 2>/dev/null || true
    printf 'CONFIG_PACKAGE_%s=y\n' "$p" >> .config
done

# Keep whatever wpad variant the profile selected; only avoid accidentally disabling it.
sed -i '/^# CONFIG_PACKAGE_wpad-basic/d' .config 2>/dev/null || true
sed -i '/^# CONFIG_PACKAGE_wpad-basic-openssl/d' .config 2>/dev/null || true
sed -i '/^# CONFIG_PACKAGE_wpad-basic-wolfssl/d' .config 2>/dev/null || true

echo "===== Final Wi-Fi/WCNSS entries ====="
grep -Ei 'wcnss|wcn36xx|wpad-basic' .config || true

echo "===== Final modem/baseband related entries after cleanup ====="
grep -Ei 'openstick-tweaks|modem|qmi|mbim|wwan|qrtr|bam-dmux|rmtfs|sms|3ginfo|DbusSms' .config || true

echo "===== DIY PART2 done ====="
