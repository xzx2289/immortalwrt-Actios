#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


def find_dts(arg: str) -> Path:
    p = Path(arg).resolve()
    if p.is_file():
        return p
    if not p.exists():
        raise SystemExit(f"ERROR: path not found: {p}")
    candidates = sorted(p.glob("target/linux/*/dts/msm8916.dtsi"))
    if not candidates:
        candidates = sorted(p.glob("target/linux/**/msm8916.dtsi"))
    if not candidates:
        raise SystemExit(f"ERROR: cannot find msm8916.dtsi under {p}/target/linux/*/dts/")
    return candidates[0]


def replace_reserved_node(text: str, node_start_regex: str, replacement_body: str) -> tuple[str, int]:
    pattern = re.compile(rf"(?ms)(\n\s*{node_start_regex}\s*\{{).*?(\n\s*\}};)")

    def repl(m: re.Match[str]) -> str:
        indent = re.match(r"\n(\s*)", m.group(1)).group(1)
        body = "\n".join(indent + "\t" + line if line else "" for line in replacement_body.splitlines())
        return f"{m.group(1)}\n{body}{m.group(2)}"

    return pattern.subn(repl, text, count=1)


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: disable-msm8916-modem.py /path/to/openwrt-or-msm8916.dtsi", file=sys.stderr)
        return 2

    dts = find_dts(sys.argv[1])
    text = dts.read_text(encoding="utf-8")
    original = text

    text, rfsa_count = replace_reserved_node(
        text,
        r"rfsa@867e0000",
        'reg = <0x0 0x867e0000 0x0 0x0>;\nno-map;\nstatus = "disabled";',
    )
    text, rmtfs_count = replace_reserved_node(
        text,
        r"rmtfs@86700000",
        'reg = <0x0 0x86700000 0x0 0x0>;\nno-map;\nstatus = "disabled";',
    )
    text, mpss_count = replace_reserved_node(
        text,
        r"mpss_mem:\s*mpss@86800000",
        '/* MPSS/modem memory disabled by no-modem build. */\nreg = <0x0 0x86800000 0x0 0x0>;\nno-map;\nstatus = "disabled";',
    )

    mpss_node = re.search(r"(?ms)(\n\s*mpss:\s*remoteproc@4080000\s*\{.*?)(\n\s*\};)", text)
    remoteproc_count = 0
    if mpss_node and 'status = "disabled"' not in mpss_node.group(0):
        text = text[:mpss_node.start(2)] + '\n\t\t\tstatus = "disabled";' + text[mpss_node.start(2):]
        remoteproc_count = 1

    if mpss_count != 1:
        raise SystemExit("ERROR: failed to patch mpss_mem: mpss@86800000")

    if text != original:
        dts.write_text(text, encoding="utf-8")

    print(f"PATCHED: {dts}")
    print(f"  mpss_mem={mpss_count}, rmtfs={rmtfs_count}, rfsa={rfsa_count}, remoteproc={remoteproc_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
