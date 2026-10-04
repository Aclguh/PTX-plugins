#!/usr/bin/env python3
"""PTX-plugins/pack.py - 本地插件开发打包工具
将 PTX-plugins/plugin-source/ 下含 plugin.json 的插件目录打包为 .ptx
(ZIP, Deflate), 产物输出到 PTX-plugins/dist/<plugin_id>.ptx。
sample_plugins/pack.py 只覆盖官方样例目录, 本脚本是其插件开发空间的对应物。

用法:
    python PTX-plugins/pack.py             # 打包全部插件
    python PTX-plugins/pack.py qr_tool     # 打包指定插件
"""

import sys
import os
import zipfile
import json

EXCLUDED_FILES = {".DS_Store", "Thumbs.db", "desktop.ini"}


def is_excluded(rel_path: str) -> bool:
    parts = rel_path.replace(os.sep, "/").split("/")
    for part in parts:
        if not part:
            continue
        # 隐藏文件/目录与 vim 交换文件等开发临时文件一律跳过
        if part.startswith(".") or part.endswith(".swp"):
            return True
        if part in EXCLUDED_FILES:
            return True
    return False


def pack_plugin(plugin_dir: str, output_dir: str) -> bool:
    manifest_path = os.path.join(plugin_dir, "plugin.json")
    if not os.path.isfile(manifest_path):
        return False

    with open(manifest_path, "r", encoding="utf-8") as f:
        manifest = json.load(f)

    plugin_id = manifest["id"]
    if plugin_id != os.path.basename(plugin_dir):
        print(f"  [跳过] {plugin_dir}: plugin.id 与目录名不一致")
        return False

    os.makedirs(output_dir, exist_ok=True)
    out_ptx = os.path.join(output_dir, f"{plugin_id}.ptx")
    print(f"  正在打包 {manifest.get('name', plugin_id)} "
          f"(v{manifest.get('version')}) -> {out_ptx}")

    with zipfile.ZipFile(out_ptx, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for root, _dirs, files in os.walk(plugin_dir):
            for file in files:
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, plugin_dir)
                if is_excluded(rel_path):
                    continue
                # ZIP 规范要求条目路径使用正斜杠, 否则 Android 端
                # archive.findFile('ui/main.ui.json') 之类查找会失败
                zip_path = rel_path.replace(os.sep, "/")
                zf.write(full_path, zip_path)

    size_kb = os.path.getsize(out_ptx) / 1024
    print(f"  [成功] {out_ptx} ({size_kb:.1f} KB)")
    return True


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    source_dir = os.path.join(here, "plugin-source")
    dist_dir = os.path.join(here, "dist")
    target = sys.argv[1] if len(sys.argv) > 1 else None

    print("========================================")
    print(" PluginToolbox PTX-plugins 打包工具")
    print("========================================")

    entries = [target] if target else sorted(os.listdir(source_dir))
    packed = 0
    for entry in entries:
        plugin_dir = os.path.join(source_dir, entry)
        if os.path.isdir(plugin_dir) and pack_plugin(plugin_dir, dist_dir):
            packed += 1

    if not target:
        print(f"\n全部完成，共打包 {packed} 个插件至 {dist_dir}")
    elif packed == 0:
        print(f"错误: 未找到可打包的插件目录: {target}")
        sys.exit(1)


if __name__ == "__main__":
    main()
