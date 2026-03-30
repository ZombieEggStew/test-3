#!/usr/bin/env python3
"""
rename_wallpaper_projects.py

扫描 Wallpaper Engine 本地项目目录（默认：
D:\\Steam\\steamapps\\common\\wallpaper_engine\\projects\\myprojects），
将每个项目文件夹重命名为对应 project.json 中的 title 字段。

用法示例：
  python rename_wallpaper_projects.py --path "D:\\Steam\\steamapps\\common\\wallpaper_engine\\projects\\myprojects" --dry-run

注意：脚本会对 title 做 Windows 文件名安全过滤，并在目标已存在时添加数字后缀避免冲突。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
from typing import Optional


INVALID_CHARS = r"[<>:\\""/\\|?*]"


def sanitize_windows_filename(name: str, maxlen: int = 240) -> str:
    # Remove invalid characters
    name = re.sub(INVALID_CHARS, "", name)
    # Strip trailing dots and spaces
    name = name.rstrip(" .")
    # Replace control chars
    name = "".join(ch for ch in name if ord(ch) >= 32)
    # Collapse whitespace
    name = re.sub(r"\s+", " ", name).strip()
    if not name:
        return ""
    # Truncate to safe length
    if len(name) > maxlen:
        name = name[:maxlen].rstrip()
    return name


def find_project_json(folder: str) -> Optional[str]:
    candidates = [os.path.join(folder, "project.json"), os.path.join(folder, "Project.json")]
    for c in candidates:
        if os.path.isfile(c):
            return c
    return None


def read_title_from_project_json(path: str) -> Optional[str]:
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
        title = data.get("title") or data.get("Title")
        if isinstance(title, str):
            return title
    except Exception:
        return None
    return None


def unique_target_path(parent: str, base_name: str) -> str:
    candidate = os.path.join(parent, base_name)
    if not os.path.exists(candidate):
        return candidate
    # append suffix (n)
    i = 1
    while True:
        suffix = f" ({i})"
        cand = os.path.join(parent, base_name + suffix)
        if not os.path.exists(cand):
            return cand
        i += 1


def rename_projects(root: str, dry_run: bool = True, verbose: bool = True):
    root = os.path.abspath(root)
    if not os.path.isdir(root):
        raise FileNotFoundError(f"路径不存在或不是目录: {root}")

    for name in sorted(os.listdir(root)):
        cur_path = os.path.join(root, name)
        if not os.path.isdir(cur_path):
            continue

        pj = find_project_json(cur_path)
        if not pj:
            if verbose:
                print(f"跳过（无 project.json）: {cur_path}")
            continue

        title = read_title_from_project_json(pj)
        if not title:
            if verbose:
                print(f"跳过（无法读取 title）: {cur_path}")
            continue

        safe = sanitize_windows_filename(title)
        if not safe:
            if verbose:
                print(f"跳过（title 为空或被移除）: {cur_path} -> raw title: {title!r}")
            continue

        target_path = os.path.join(root, safe)
        # if same path (case-insensitive on Windows) consider it unchanged
        if os.path.normcase(os.path.abspath(cur_path)) == os.path.normcase(os.path.abspath(target_path)):
            if verbose:
                print(f"已命名正确（无需改名）: {cur_path}")
            continue

        # Ensure unique target
        final_target = target_path
        if os.path.exists(final_target):
            final_target = unique_target_path(root, safe)

        if verbose:
            print(f"{cur_path} -> {final_target}")

        if not dry_run:
            try:
                os.rename(cur_path, final_target)
            except Exception as e:
                print(f"重命名失败: {cur_path} -> {final_target}: {e}")


def parse_args():
    p = argparse.ArgumentParser(description="将 Wallpaper Engine 本地项目目录按 project.json 的 title 字段重命名文件夹")
    p.add_argument("--path", "-p", default=r"D:\\Steam\\steamapps\\common\\wallpaper_engine\\projects\\myprojects",
                   help="本地项目目录（默认 Wallpaper Engine myprojects 目录）")
    p.add_argument("--dry-run", action="store_true", help="只打印将要执行的操作（默认不执行）")
    p.add_argument("--yes", "-y", action="store_true", help="直接执行，不交互（与 --dry-run 互斥）")
    p.add_argument("--no-verbose", action="store_true", help="静默模式，减少输出")
    return p.parse_args()


def main():
    args = parse_args()
    dry = args.dry_run or (not args.yes)
    verbose = not args.no_verbose
    if args.dry_run:
        print("运行模式：仅显示（dry-run）")
    elif args.yes:
        print("运行模式：立即执行重命名")
    else:
        # default: dry-run to be safe
        print("默认模式：仅显示（dry-run）。如需执行请加 --yes")

    rename_projects(args.path, dry_run=dry, verbose=verbose)


if __name__ == "__main__":
    main()
