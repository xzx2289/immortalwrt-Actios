#!/usr/bin/env bash
set -euo pipefail

# OpenWrt DIY script part 2
# 执行时机：feeds install 之后、make defconfig 之前。
# 目标：从 .config 里清掉 modem/QMI/MBIM/WWAN/短信/蜂窝网络相关包；保留 Wi-Fi/WCNSS。

echo "===== DIY PART2: remove MSM8916 modem/baseband packages ====="

if [ ! -f .config ]; then
    echo "ERROR: .config not found."
    echo "请确认 workflow 已经把 config/机型.config 移动到 openwrt/.config"
    exit 1
fi

# 主题替换，可失败，不影响编译。
sed -i 's/luci-theme-material/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true
sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile 2>/dev/null || true

# 删除常见短信/蜂窝相关包目录，避免 feeds 重新选中。
rm -rf package/DbusSmsForwardCPlus package/feeds/*/DbusSmsForwardCPlus 2>/dev/null || true

# 明确禁用的蜂窝/基带相关包。
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

for p in $DISABLE_PKGS; do
    disable_pkg "$p"
done

# 自动禁用所有 openstick modem firmware，覆盖不同机型：ufi003/ufi001c/uz801/mf32 等。
AUTO_DISABLE_SYMBOLS="$(
    grep -E '^CONFIG_(PACKAGE|DEFAULT)_(qcom-msm8916-modem-openstick-.*-firmware|.*modem.*firmware)=(y|m)' .config 2>/dev/null \
        | sed -E 's/^CONFIG_(PACKAGE|DEFAULT)_//' \
        | sed -E 's/=(y|m)$//' \
        | sort -u || true
)"

for p in $AUTO_DISABLE_SYMBOLS; do
    echo "Disable modem firmware/package from existing config: $p"
    disable_pkg "$p"
done

# 兜底：明确列出常见 MSM8916/OpenStick modem 固件包名。
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

# 重要：保留 Wi-Fi。骁龙410的 Wi-Fi 是 WCNSS/WCN36xx，不是 MPSS modem。
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

# 不强制 wpad 变体，避免和上游默认的 wpad-basic-mbedtls/wolfssl 冲突；只禁止把 wpad-basic 全部关掉。
sed -i '/^# CONFIG_PACKAGE_wpad-basic/d' .config 2>/dev/null || true

# 输出检查结果。
echo "===== Wi-Fi/WCNSS packages kept ====="
grep -Ei 'wcnss|wcn36xx|wpad-basic' .config || true

echo "===== Modem/baseband related config after cleanup ====="
grep -Ei 'modem|qmi|mbim|wwan|qrtr|bam-dmux|rmtfs|sms|DbusSms' .config || true

echo "===== DIY PART2 done ====="
