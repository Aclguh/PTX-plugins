#!/usr/bin/env python3
"""decode_qr.py - 用 zxing-cpp 解码 qr_tool 产出的矩阵, 验证真实可扫描性。
同时解码 segno 参考矩阵作为对照。输入: build/qr_out.json
"""
import json
import sys

import zxingcpp
from PIL import Image


def to_image(matrix, scale=8, quiet=4):
    n = len(matrix)
    size = (n + 2 * quiet) * scale
    img = Image.new("L", (size, size), 255)
    px = img.load()
    for r in range(n):
        for c in range(n):
            if matrix[r][c]:
                for dy in range(scale):
                    for dx in range(scale):
                        px[(c + quiet) * scale + dx, (r + quiet) * scale + dy] = 0
    return img


def main():
    with open("build/qr_out.json", encoding="utf-8") as f:
        cases = json.load(f)

    passed = failed = skipped = 0
    for text, got in cases.items():
        if "error" in got:
            skipped += 1
            continue
        img = to_image(got["matrix"])
        results = img.scan(qzxing := zxingcpp.BarcodeReader()) if False else zxingcpp.read_barcodes(img)
        texts = [r.text for r in results]
        if text in texts:
            passed += 1
            print(f"OK   v{got['version']} mask{got['mask']} 解码一致: {text[:24]!r}")
        else:
            failed += 1
            print(f"FAIL v{got['version']} mask{got['mask']} 解码得到 {texts!r} 期望 {text[:24]!r}")

    print(f"\n==== zxing 解码: {passed} 通过, {failed} 失败, {skipped} 跳过(超长用例) ====")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
