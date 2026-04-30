#!/usr/bin/env bash
set -euo pipefail

# OpenWrt DIY script part 1
# Purpose:
#   Disable MSM8916 MPSS/modem reserved memory at DTS level.
#   This patches both the common msm8916.dtsi and device override DTSI files
#   such as msm8916-ufi.dtsi / msm8916-mifi.dtsi.
#
# Important:
#   This script must run inside the OpenWrt source directory before make defconfig.

echo "===== DIY PART1: no-modem DTS patch for MSM8916 ====="

OPENWRT_DIR="${OPENWRT_DIR:-$(pwd)}"
DTS_DIR="$OPENWRT_DIR/target/linux/msm89xx/dts"

echo "OPENWRT_DIR=$OPENWRT_DIR"
echo "DTS_DIR=$DTS_DIR"

if [ ! -d "$DTS_DIR" ]; then
    echo "ERROR: DTS directory not found: $DTS_DIR"
    echo "Make sure diy-part1.sh is executed inside the OpenWrt source tree."
    exit 1
fi

python3 - "$OPENWRT_DIR" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

openwrt = Path(sys.argv[1]).resolve()
dts_dir = openwrt / "target/linux/msm89xx/dts"

if not dts_dir.is_dir():
    raise SystemExit(f"ERROR: DTS dir not found: {dts_dir}")

targets = sorted(dts_dir.glob("msm8916*.dts*"))

if not targets:
    raise SystemExit(f"ERROR: no msm8916*.dts* files found under {dts_dir}")

def replace_blocks(text: str, start_regex: str, replacement: str) -> tuple[str, int]:
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    count = 0
    start_re = re.compile(start_regex)

    while i < len(lines):
        line = lines[i]

        if start_re.search(line):
            brace_delta = line.count("{") - line.count("}")
            j = i + 1

            while j < len(lines):
                brace_delta += lines[j].count("{") - lines[j].count("}")
                if brace_delta <= 0 and "};" in lines[j]:
                    break
                j += 1

            indent = re.match(r"^(\s*)", line).group(1)

            out.append(line)
            for body_line in replacement.splitlines():
                if body_line:
                    out.append(f"{indent}\t{body_line}\n")
                else:
                    out.append("\n")
            out.append(f"{indent}}};\n")

            i = j + 1
            count += 1
            continue

        out.append(line)
        i += 1

    return "".join(out), count

def patch_file(path: Path) -> tuple[bool, dict[str, int]]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    old = text
    stats: dict[str, int] = {}

    text, n = replace_blocks(
        text,
        r"^\s*mpss_mem:\s*mpss@86800000\s*\{",
        '/* MPSS/modem memory disabled by no-modem build. */\n'
        'reg = <0x0 0x86800000 0x0 0x0>;\n'
        'no-map;\n'
        'status = "disabled";'
    )
    stats["mpss_mem_label"] = n

    text, n = replace_blocks(
        text,
        r"^\s*&mpss_mem\s*\{",
        'reg = <0x0 0x86800000 0x0 0x0>;\n'
        'status = "disabled";'
    )
    stats["mpss_mem_ref"] = n

    text, n = replace_blocks(
        text,
        r"^\s*&mpss\s*\{",
        'status = "disabled";'
    )
    stats["mpss_ref"] = n

    text, n = replace_blocks(
        text,
        r"^\s*&mba_mem\s*\{",
        'status = "disabled";'
    )
    stats["mba_mem_ref"] = n

    text, n = replace_blocks(
        text,
        r"^\s*&bam_dmux\s*\{",
        'status = "disabled";'
    )
    stats["bam_dmux_ref"] = n

    text, n = replace_blocks(
        text,
        r"^\s*&bam_dmux_dma\s*\{",
        'status = "disabled";'
    )
    stats["bam_dmux_dma_ref"] = n

    text, n = replace_blocks(
        text,
        r"^\s*rmtfs@86700000\s*\{",
        'reg = <0x0 0x86700000 0x0 0x0>;\n'
        'no-map;\n'
        'status = "disabled";'
    )
    stats["rmtfs_label"] = n

    text, n = replace_blocks(
        text,
        r"^\s*rfsa@867e0000\s*\{",
        'reg = <0x0 0x867e0000 0x0 0x0>;\n'
        'no-map;\n'
        'status = "disabled";'
    )
    stats["rfsa_label"] = n

    text, n = replace_blocks(
        text,
        r"^\s*&rmtfs_mem\s*\{",
        'status = "disabled";'
    )
    stats["rmtfs_mem_ref"] = n

    text, n = replace_blocks(
        text,
        r"^\s*&rfsa_mem\s*\{",
        'status = "disabled";'
    )
    stats["rfsa_mem_ref"] = n

    if text != old:
        path.write_text(text, encoding="utf-8")
        return True, stats

    return False, stats

changed_any = False

for path in targets:
    changed, stats = patch_file(path)
    total = sum(stats.values())

    if changed:
        changed_any = True
        print(f"PATCHED: {path.relative_to(openwrt)} blocks={total} {stats}")
    elif total:
        print(f"CHECKED: {path.relative_to(openwrt)} blocks={total} no write needed")
    else:
        print(f"NOCHANGE: {path.relative_to(openwrt)}")

bad_patterns = [
    "0x5500000",
    "0x05500000",
]

bad_hits: list[str] = []

for path in targets:
    data = path.read_text(encoding="utf-8", errors="ignore")
    for pat in bad_patterns:
        if pat in data:
            for idx, line in enumerate(data.splitlines(), 1):
                if pat in line:
                    bad_hits.append(f"{path.relative_to(openwrt)}:{idx}: {line.strip()}")

if bad_hits:
    print("ERROR: non-zero MPSS/modem memory size still exists:")
    for h in bad_hits:
        print("  " + h)
    raise SystemExit(1)

print("===== Key DTS verification =====")
for p in [
    dts_dir / "msm8916.dtsi",
    dts_dir / "msm8916-ufi.dtsi",
    dts_dir / "msm8916-mifi.dtsi",
    dts_dir / "msm8916-sp970.dtsi",
]:
    if not p.exists():
        continue

    print(f"--- {p.relative_to(openwrt)} ---")
    data = p.read_text(encoding="utf-8", errors="ignore")

    for idx, line in enumerate(data.splitlines(), 1):
        if (
            "mpss_mem" in line
            or "mpss@86800000" in line
            or "&mpss" in line
            or "&bam_dmux" in line
            or "0x86800000" in line
        ):
            print(f"{idx}: {line}")

print("OK: MSM8916 MPSS/modem DTS memory override patched.")
PY

echo "===== Grep DTS modem-related result ====="
grep -RsnE 'mpss_mem|mpss@86800000|0x5500000|0x05500000|&mpss|&bam_dmux|bam_dmux' "$DTS_DIR"/msm8916*.dts* || true

echo "===== DIY PART1 done ====="
