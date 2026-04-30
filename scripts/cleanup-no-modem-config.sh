#!/usr/bin/env bash
set -euo pipefail

if [ ! -f .config ]; then
  echo "ERROR: .config not found. Please run this script in the OpenWrt source directory."
  exit 1
fi

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
"

disable_pkg() {
  local p="$1"

  sed -i \
    -e "/^CONFIG_PACKAGE_${p}=.*/d" \
    -e "/^# CONFIG_PACKAGE_${p} is not set/d" \
    -e "/^CONFIG_DEFAULT_${p}=.*/d" \
    -e "/^# CONFIG_DEFAULT_${p} is not set/d" \
    .config 2>/dev/null || true

  if [ -x ./scripts/config ]; then
    ./scripts/config --disable "PACKAGE_${p}" 2>/dev/null || true
    ./scripts/config --disable "DEFAULT_${p}" 2>/dev/null || true
  fi

  printf '# CONFIG_PACKAGE_%s is not set\n' "$p" >> .config
  printf '# CONFIG_DEFAULT_%s is not set\n' "$p" >> .config
}

for p in $DISABLE_PKGS; do
  disable_pkg "$p"
done

AUTO_DISABLE_SYMBOLS="$(grep -E '^CONFIG_(PACKAGE|DEFAULT)_(qcom-msm8916-modem-openstick-.*-firmware|.*modem.*firmware)=(y|m)' .config 2>/dev/null \
  | sed -E 's/^CONFIG_(PACKAGE|DEFAULT)_//' \
  | sed -E 's/=(y|m)$//' \
  | sort -u || true)"

for p in $AUTO_DISABLE_SYMBOLS; do
  echo "Disable modem firmware/package from existing config: $p"
  disable_pkg "$p"
done

KEEP_WIFI_PKGS="
kmod-rproc-wcnss
kmod-wcn36xx
"

for p in $KEEP_WIFI_PKGS; do
  sed -i \
    -e "/^CONFIG_PACKAGE_${p}=.*/d" \
    -e "/^# CONFIG_PACKAGE_${p} is not set/d" \
    .config 2>/dev/null || true
  if [ -x ./scripts/config ]; then
    ./scripts/config --enable "PACKAGE_${p}" 2>/dev/null || true
  fi
  printf 'CONFIG_PACKAGE_%s=y\n' "$p" >> .config
done

sed -i '/^# CONFIG_PACKAGE_wpad-basic/d' .config 2>/dev/null || true

awk '
  /^CONFIG_/ || /^# CONFIG_/ {
    line=$0
    key=line
    sub(/^# /, "", key)
    sub(/ is not set$/, "", key)
    sub(/=.*/, "", key)
    a[key]=line
    next
  }
  { other[++n]=$0 }
  END {
    for (i=1;i<=n;i++) print other[i]
    for (k in a) print a[k]
  }
' .config > .config.nomodem.tmp
mv .config.nomodem.tmp .config

true
