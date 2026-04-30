#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Patch MSM8916/OpenStick DTS to disable MPSS/modem reserved memory.

Why use a patcher instead of replacing the whole msm8916.dtsi?
- 上游 DTS 可能更新，整文件覆盖容易引入旧内容。
- 这里只改 modem/MPSS 相关块，保留 Wi-Fi/WCNSS、USB、CPU OPP 等上游改动。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def find_matching_brace(text: str, open_brace: int) -> int:
    depth = 0
    i = open_brace
    n = len(text)
    in_line_comment = False
    in_block_comment = False
    in_string = False
    escape = False

    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if in_line_comment:
            if c == "\n":
                in_line_comment = False
            i += 1
            continue

        if in_block_comment:
            if c == "*" and nxt == "/":
                in_block_comment = False
                i += 2
                continue
            i += 1
            continue

        if in_string:
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == '"':
                in_string = False
            i += 1
            continue

        if c == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if c == "/" and nxt == "*":
            in_block_comment = True
            i += 2
            continue
        if c == '"':
            in_string = True
            i += 1
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1

    raise ValueError("matching brace not found")


def patch_named_block(text: str, start_pattern: str, patch_func, *, required: bool = False) -> tuple[str, int]:
    count = 0
    pos = 0
    regex = re.compile(start_pattern, re.M)

    while True:
        m = regex.search(text, pos)
        if not m:
            break
        open_brace = text.find("{", m.start(), m.end() + 200)
        if open_brace < 0:
            pos = m.end()
            continue
        close_brace = find_matching_brace(text, open_brace)
        block = text[m.start(): close_brace + 1]
        new_block = patch_func(block)
        if new_block != block:
            text = text[:m.start()] + new_block + text[close_brace + 1:]
            pos = m.start() + len(new_block)
            count += 1
        else:
            pos = close_brace + 1

    if required and count == 0:
        raise RuntimeError(f"required block not patched: {start_pattern}")
    return text, count


def add_or_replace_status_disabled(block: str) -> str:
    if re.search(r'\bstatus\s*=\s*"[^"]*"\s*;', block):
        block = re.sub(r'\bstatus\s*=\s*"[^"]*"\s*;', 'status = "disabled";', block, count=1)
    else:
        # 插到最后一个 } 之前，缩进用 tab/4空格都无所谓，dtc 可以识别。
        idx = block.rfind("}")
        block = block[:idx] + '\n\t\t\tstatus = "disabled";' + block[idx:]
    return block


def patch_mpss_reserved(block: str) -> str:
    # 把 MPSS 预留内存长度改成 0，并禁用该 reserved-memory 子节点。
    # 原来通常是 0x5500000 左右，约 85MB。
    if re.search(r'\breg\s*=\s*<[^;]+>\s*;', block, flags=re.S):
        block = re.sub(
            r'\breg\s*=\s*<[^;]+>\s*;',
            'reg = <0x0 0x86800000 0x0 0x0>;',
            block,
            count=1,
            flags=re.S,
        )
    else:
        idx = block.rfind("}")
        block = block[:idx] + '\n\t\t\treg = <0x0 0x86800000 0x0 0x0>;' + block[idx:]
    return add_or_replace_status_disabled(block)


def patch_small_modem_reserved(block: str) -> str:
    # rmtfs/rfsa 是 modem 相关小块，禁用并改 size 0。
    # 这两块总量不大，但一起处理更干净。
    block = re.sub(r'\breg\s*=\s*<([^>]+)>\s*;', lambda m: shrink_reg_to_zero(m.group(0)), block, count=1, flags=re.S)
    return add_or_replace_status_disabled(block)


def shrink_reg_to_zero(reg_stmt: str) -> str:
    nums = re.findall(r'0x[0-9a-fA-F]+|\d+', reg_stmt)
    if len(nums) >= 4:
        return f'reg = <{nums[0]} {nums[1]} 0x0 0x0>;'
    return 'reg = <0x0 0x0 0x0 0x0>;'


def patch_remoteproc_block(block: str) -> str:
    # 只禁用 MPSS/MSS PIL，也就是 modem remoteproc；不要碰 WCNSS/WCN36xx Wi-Fi。
    if "qcom,msm8916-mss-pil" in block or "qcom,msm8916-mss-pas" in block:
        return add_or_replace_status_disabled(block)
    return block


def patch_file(path: Path) -> bool:
    old = path.read_text(encoding="utf-8", errors="ignore")
    text = old

    text, mpss_count = patch_named_block(
        text,
        r'\bmpss_mem\s*:\s*mpss@86800000\s*\{',
        patch_mpss_reserved,
        required=True,
    )

    # 小块 modem 预留内存；找不到不报错，因为不同上游可能没有这些节点。
    text, rmtfs_count = patch_named_block(
        text,
        r'\brmtfs@86700000\s*\{',
        patch_small_modem_reserved,
        required=False,
    )
    text, rfsa_count = patch_named_block(
        text,
        r'\brfsa@867e0000\s*\{',
        patch_small_modem_reserved,
        required=False,
    )

    # 禁用 modem remoteproc 节点。此处按块扫描含 mss-pil/mss-pas 的节点。
    changed_remote = 0
    for compat in ("qcom,msm8916-mss-pil", "qcom,msm8916-mss-pas"):
        idx = 0
        while True:
            hit = text.find(compat, idx)
            if hit < 0:
                break
            # 向前找这个属性所在节点的 {。这里用最近的 {，再向前扩展到节点名行起点。
            open_brace = text.rfind("{", 0, hit)
            if open_brace < 0:
                idx = hit + len(compat)
                continue
            line_start = text.rfind("\n", 0, open_brace) + 1
            close_brace = find_matching_brace(text, open_brace)
            block = text[line_start: close_brace + 1]
            new_block = patch_remoteproc_block(block)
            if new_block != block:
                text = text[:line_start] + new_block + text[close_brace + 1:]
                idx = line_start + len(new_block)
                changed_remote += 1
            else:
                idx = close_brace + 1

    if text != old:
        backup = path.with_suffix(path.suffix + ".bak-before-nomodem")
        backup.write_text(old, encoding="utf-8")
        path.write_text(text, encoding="utf-8")
        print(f"PATCHED: {path}")
        print(f"  mpss_mem={mpss_count}, rmtfs={rmtfs_count}, rfsa={rfsa_count}, remoteproc={changed_remote}")
        return True

    print(f"UNCHANGED: {path}")
    return False


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: disable-msm8916-modem.py /path/to/openwrt", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    candidates = []
    for rel in (
        "target/linux/msm89xx/dts/msm8916.dtsi",
        "target/linux/msm8916/dts/msm8916.dtsi",
    ):
        p = root / rel
        if p.exists():
            candidates.append(p)

    candidates.extend(root.glob("target/linux/*/dts/msm8916.dtsi"))
    # 去重保持顺序
    seen = set()
    unique = []
    for p in candidates:
        rp = p.resolve()
        if rp not in seen:
            unique.append(p)
            seen.add(rp)

    if not unique:
        print("ERROR: cannot find msm8916.dtsi under target/linux/*/dts/", file=sys.stderr)
        return 1

    ok = False
    for p in unique:
        ok = patch_file(p) or ok

    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
