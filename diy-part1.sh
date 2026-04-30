#!/bin/bash
set -e

echo "===== DIY PART1: feeds + no-modem DTS patch ====="

# 如果你需要 small-package，再打开这一行
# echo 'src-git smpackage https://github.com/kenzok8/small-package' >> feeds.conf.default

# 如果上游 feeds 需要替换，可以保留这一行
sed -i 's|src-git-full openstick https://github.com/lkiuyu/openstick-feeds.git|src-git-full openstick https://github.com/xuxin1955/openstick-feeds|g' feeds.conf.default 2>/dev/null || true

# 真正释放 modem/MPSS 预留内存的关键：替换 msm8916.dtsi
if [ -f "$GITHUB_WORKSPACE/scripts/dts/msm8916.dtsi" ]; then
    echo "Copy no-modem msm8916.dtsi into target/linux/msm89xx/dts/"
    mkdir -p target/linux/msm89xx/dts
    cp -f "$GITHUB_WORKSPACE/scripts/dts/msm8916.dtsi" target/linux/msm89xx/dts/msm8916.dtsi
else
    echo "ERROR: $GITHUB_WORKSPACE/scripts/dts/msm8916.dtsi not found"
    exit 1
fi

echo "===== Check modem reserved memory in DTS ====="
grep -nA12 -B4 'mpss_mem: mpss@86800000' target/linux/msm89xx/dts/msm8916.dtsi || true
