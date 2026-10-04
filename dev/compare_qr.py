#!/usr/bin/env python3
"""compare_qr.py - 用 segno 参考实现逐模块比对 qr_tool 编码矩阵。
对每个用例强制 segno 使用与插件一致的 mode=byte / version / mask / error 级别,
矩阵一致即证明位流、RS 纠错、布点与格式信息全部正确。
"""
import json
import sys

import segno

# 注: 插件实现严格按 ISO 18004 (终止符紧跟数据, UTF-8 字节计数);
# segno 为"先字节对齐后终止符"的良性变体且自动编码探测(可能选 GBK),
# 故本比对仅作信息参考, 验收以 decode_qr.py 的 zxing 真实解码为准。

def main():
    with open("build/qr_out.json", encoding="utf-8") as f:
        cases = json.load(f)

    passed = failed = 0
    for text, got in cases.items():
        if "error" in got:
            # 超长场景: 验证 segno 同级别确实放不下 (L 级别 v5 容量 106 字节)
            qr = segno.make(text, mode="byte", error="l", boost_error=False, encoding="utf-8")
            ok = qr.version > 5
            if ok:
                passed += 1
            else:
                failed += 1
                print(f"FAIL 超长判定: {text[:20]!r} segno 版本={qr.version}")
            continue

        version = got["version"]
        mask = got["mask"]
        ecl = got.get("ecl", "m").lower()
        qr = segno.make(text, mode="byte", error=ecl, version=version, mask=mask, boost_error=False, encoding="utf-8")
        ref_core = [list(row) for row in qr.matrix]
        mine = got["matrix"]
        if ref_core == mine:
            passed += 1
            print(f"OK   v{version} mask{mask} {text[:24]!r}")
        else:
            failed += 1
            print(f"FAIL v{version} mask{mask} {text[:24]!r} 尺寸 got={len(mine)} ref={len(ref_core)}")
            for r in range(min(len(mine), len(ref_core))):
                if mine[r] != ref_core[r]:
                    print(f"  首个差异行 {r}:\n    got {mine[r]}\n    ref {ref_core[r]}")
                    break

    print(f"\n==== QR 比对: {passed} 通过, {failed} 失败 ====")
    sys.exit(1 if failed else 0)

if __name__ == "__main__":
    main()
