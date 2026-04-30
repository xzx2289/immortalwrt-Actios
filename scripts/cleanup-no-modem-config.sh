#!/usr/bin/env bash
set -euo pipefail

echo "===== cleanup-no-modem-config: remove modem and known broken packages ====="

if [ ! -f .config ]; then
    echo "ERROR: .config not found."
    exit 1
fi

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
sms-tool
kmod-usb-net-qmi-wwan
kmod-usb-net-cdc-mbim
kmod-usb-net-cdc-ncm
kmod-usb-net-huawei-cdc-ncm
kmod-usb-serial-option
kmod-usb-serial-wwan
kmod-usb-wdm
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
ddns-go
luci-app-ddns-go
"

for p in $DISABLE_PKGS; do
    echo "Disable: $p"
    disable_pkg "$p"
done

# Keep Wi-Fi/WCNSS. Do not disable these.
for p in kmod-rproc-wcnss kmod-wcn36xx; do
    sed -i \
        -e "/^CONFIG_PACKAGE_${p}=.*/d" \
        -e "/^# CONFIG_PACKAGE_${p} is not set/d" \
        .config 2>/dev/null || true
    printf 'CONFIG_PACKAGE_%s=y\n' "$p" >> .config
done

echo "===== Check remaining modem/ddns entries ====="
grep -Ei 'modem|qmi|mbim|wwan|qrtr|bam-dmux|rmtfs|sms|DbusSms|ddns-go' .config || true

echo "===== cleanup-no-modem-config done ====="
