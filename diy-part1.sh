#!/usr/bin/env bash
set -euo pipefail

# OpenWrt DIY script part 1
# 执行时机：clone OpenWrt 源码之后、feeds update 之前。
# 目标：修改 MSM8916/骁龙410 DTS，禁用 MPSS/modem 预留内存，避免基带启动。

ROOT="${GITHUB_WORKSPACE:-$(pwd)}"
OPENWRT_DIR="$(pwd)"
PATCHER="$ROOT/scripts/patches/disable-msm8916-modem.py"

echo "===== DIY PART1: no-modem DTS patch for MSM8916 ====="
echo "GITHUB_WORKSPACE=$ROOT"
echo "OPENWRT_DIR=$OPENWRT_DIR"

# 你原项目里已有的 openstick feeds 替换逻辑，保留。
sed -i 's|src-git-full openstick https://github.com/lkiuyu/openstick-feeds.git|src-git-full openstick https://github.com/xuxin1955/openstick-feeds|g' feeds.conf.default 2>/dev/null || true

if [ ! -f "$PATCHER" ]; then
    echo "ERROR: patcher not found: $PATCHER"
    echo "请确认仓库里存在 scripts/patches/disable-msm8916-modem.py"
    exit 1
fi

python3 "$PATCHER" "$OPENWRT_DIR"

echo "===== DTS patch result ====="
for f in \
    target/linux/msm89xx/dts/msm8916.dtsi \
    target/linux/*/dts/msm8916.dtsi
 do
    [ -f "$f" ] || continue
    echo "--- $f ---"
    grep -nA16 -B6 'mpss_mem: mpss@86800000' "$f" || true
    grep -nA12 -B4 'qcom,msm8916-mss-pil\|qcom,msm8916-mss-pas' "$f" || true
 done

echo "===== DIY PART1 done ====="
