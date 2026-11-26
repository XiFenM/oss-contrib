#!/usr/bin/env python3
"""Sync open-source research plans and completed summaries between PlanA and oss-contrib.

Single-writer ownership:
  - PlanA/开源贡献/调研报告/*.md   ->  oss-contrib/plans/*.md            (pull-plans)
  - oss-contrib/summaries/*.md    ->  PlanA/开源贡献/成果总结/*.md       (push-summaries)

Files named README.md or starting with '_' (templates) are excluded from sync.
"""

from __future__ import annotations

import argparse
import hashlib
import shutil
import sys
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def list_syncable_md(directory: Path) -> dict[str, Path]:
    if not directory.is_dir():
        return {}
    result: dict[str, Path] = {}
    for p in sorted(directory.glob("*.md")):
        if p.name == "README.md" or p.name.startswith("_"):
            continue
        result[p.name] = p
    return result


def compare_dirs(src_dir: Path, dst_dir: Path) -> tuple[list[str], list[str], list[str], list[str]]:
    src_files = list_syncable_md(src_dir)
    dst_files = list_syncable_md(dst_dir)
    to_add: list[str] = []
    to_update: list[str] = []
    in_sync: list[str] = []
    extra_in_dst: list[str] = []

    for name, src_path in src_files.items():
        dst_path = dst_files.get(name)
        if dst_path is None:
            to_add.append(name)
        elif sha256_file(src_path) != sha256_file(dst_path):
            to_update.append(name)
        else:
            in_sync.append(name)

    for name in dst_files:
        if name not in src_files:
            extra_in_dst.append(name)

    return to_add, to_update, in_sync, extra_in_dst


def sync_one_way(label: str, src_dir: Path, dst_dir: Path, dry_run: bool) -> int:
    if not src_dir.is_dir():
        print(f"[ERROR] Source directory does not exist: {src_dir}", file=sys.stderr)
        return 2

    to_add, to_update, in_sync, extra_in_dst = compare_dirs(src_dir, dst_dir)
    mode = "DRY-RUN" if dry_run else "SYNC"
    print(f"[{mode}] {label}: {src_dir} -> {dst_dir}")

    if not to_add and not to_update:
        print(f"  All up to date ({len(in_sync)} file(s) in sync).")
    else:
        if not dry_run:
            dst_dir.mkdir(parents=True, exist_ok=True)
        for name in to_add:
            print(f"  + ADD    {name}")
            if not dry_run:
                shutil.copy2(src_dir / name, dst_dir / name)
        for name in to_update:
            print(f"  ~ UPDATE {name}")
            if not dry_run:
                shutil.copy2(src_dir / name, dst_dir / name)
        if in_sync:
            print(f"  = UNCHANGED ({len(in_sync)} file(s))")

    if extra_in_dst:
        print(f"  ! Note: {len(extra_in_dst)} extra file(s) only in destination (not deleted):")
        for name in extra_in_dst:
            print(f"      - {name}")
    return 0


def print_status(plana_root: Path, oss_root: Path) -> int:
    pairs = [
        ("Plans (PlanA -> oss-contrib)", plana_root / "开源贡献" / "调研报告", oss_root / "plans"),
        ("Summaries (oss-contrib -> PlanA)", oss_root / "summaries", plana_root / "开源贡献" / "成果总结"),
    ]
    exit_code = 0
    for label, src_dir, dst_dir in pairs:
        print(f"=== {label} ===")
        if not src_dir.is_dir():
            print(f"  [MISSING SOURCE] {src_dir}")
            exit_code = 2
            continue
        to_add, to_update, in_sync, extra = compare_dirs(src_dir, dst_dir)
        print(f"  source: {src_dir}")
        print(f"  target: {dst_dir}")
        print(f"  in-sync={len(in_sync)}, to-add={len(to_add)}, to-update={len(to_update)}, extra-in-target={len(extra)}")
        for name in to_add:
            print(f"    + pending add:    {name}")
        for name in to_update:
            print(f"    ~ pending update: {name}")
        for name in extra:
            print(f"    ! extra target:   {name}")
    return exit_code


def main() -> int:
    oss_root = Path(__file__).resolve().parent.parent
    default_plana = oss_root.parent / "PlanA"

    parser = argparse.ArgumentParser(description="Sync plans and summaries between PlanA and oss-contrib.")
    parser.add_argument(
        "--plana",
        type=Path,
        default=default_plana,
        help=f"Path to PlanA repository (default: {default_plana})",
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status", help="Show sync status for both directions.")

    p_pull = sub.add_parser("pull-plans", help="Sync PlanA/开源贡献/调研报告/*.md -> oss-contrib/plans/.")
    p_pull.add_argument("--dry-run", action="store_true", help="Preview without copying files.")

    p_push = sub.add_parser("push-summaries", help="Sync oss-contrib/summaries/*.md -> PlanA/开源贡献/成果总结/.")
    p_push.add_argument("--dry-run", action="store_true", help="Preview without copying files.")

    args = parser.parse_args()
    plana_root = args.plana.resolve()

    if not plana_root.is_dir():
        print(f"[ERROR] PlanA directory not found: {plana_root}", file=sys.stderr)
        return 2

    if args.cmd == "status":
        return print_status(plana_root, oss_root)
    if args.cmd == "pull-plans":
        return sync_one_way(
            "Plans",
            plana_root / "开源贡献" / "调研报告",
            oss_root / "plans",
            args.dry_run,
        )
    if args.cmd == "push-summaries":
        return sync_one_way(
            "Summaries",
            oss_root / "summaries",
            plana_root / "开源贡献" / "成果总结",
            args.dry_run,
        )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
