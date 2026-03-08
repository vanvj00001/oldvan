#!/usr/bin/env python3
"""Bulk import local text/markdown files into Hugo posts."""

from __future__ import annotations

import argparse
import re
import shutil
import unicodedata
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


SUPPORTED_EXTS = {".md", ".markdown", ".txt"}


@dataclass
class ImportResult:
    source: Path
    target: Path
    archived: Path | None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Import .md/.markdown/.txt files into Hugo content/posts."
    )
    parser.add_argument(
        "--source",
        default="imports/inbox",
        help="Source directory for raw files. Default: imports/inbox",
    )
    parser.add_argument(
        "--target",
        default="content/posts",
        help="Destination directory for Hugo posts. Default: content/posts",
    )
    parser.add_argument(
        "--archive",
        default="imports/done",
        help="Archive directory for processed files. Default: imports/done",
    )
    parser.add_argument(
        "--default-tag",
        default="导入",
        help="Default tag for files without front matter. Default: 导入",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview operations without writing files.",
    )
    parser.add_argument(
        "--no-archive",
        action="store_true",
        help="Keep source files in place after import.",
    )
    return parser.parse_args()


def decode_text(path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-8", "gb18030"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    return path.read_text(encoding="latin-1")


def has_front_matter(text: str) -> bool:
    if text.startswith("---\n"):
        return bool(re.search(r"\n---\n", text[4:]))
    if text.startswith("+++\n"):
        return bool(re.search(r"\n\+\+\+\n", text[4:]))
    return False


def pick_title(path: Path, text: str) -> str:
    m = re.search(r"^#\s+(.+)$", text, flags=re.MULTILINE)
    if m:
        return m.group(1).strip()
    stem = path.stem.replace("_", " ").replace("-", " ").strip()
    return stem if stem else "Untitled"


def slugify(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text).strip().lower()
    normalized = re.sub(r"[^\w\u4e00-\u9fff\s-]", "", normalized)
    normalized = re.sub(r"[\s_]+", "-", normalized)
    normalized = re.sub(r"-{2,}", "-", normalized).strip("-")
    return normalized or "post"


def unique_path(path: Path) -> Path:
    if not path.exists():
        return path
    idx = 2
    while True:
        candidate = path.with_name(f"{path.stem}-{idx}{path.suffix}")
        if not candidate.exists():
            return candidate
        idx += 1


def build_front_matter(title: str, dt: datetime, default_tag: str) -> str:
    timestamp = dt.strftime("%Y-%m-%dT%H:%M:%S%z")
    if len(timestamp) == 24:
        timestamp = f"{timestamp[:-2]}:{timestamp[-2:]}"
    escaped_title = title.replace('"', '\\"')
    escaped_tag = default_tag.replace('"', '\\"')
    return (
        "+++\n"
        f'title = "{escaped_title}"\n'
        f"date = {timestamp}\n"
        "draft = false\n"
        f'tags = ["{escaped_tag}"]\n'
        "+++\n\n"
    )


def import_one(
    src: Path, source_root: Path, target_root: Path, archive_root: Path, args: argparse.Namespace
) -> ImportResult:
    raw = decode_text(src)
    stat = src.stat()
    dt = datetime.fromtimestamp(stat.st_mtime).astimezone()

    title = pick_title(src, raw)
    slug = slugify(src.stem)
    month_dir = dt.strftime("%Y-%m")
    target_dir = target_root / month_dir
    target_path = unique_path(target_dir / f"{slug}.md")

    if has_front_matter(raw):
        content = raw
    else:
        content = build_front_matter(title, dt, args.default_tag) + raw.lstrip()

    archive_path = None
    if not args.no_archive:
        archive_path = archive_root / src.relative_to(source_root)

    if not args.dry_run:
        target_path.parent.mkdir(parents=True, exist_ok=True)
        target_path.write_text(content, encoding="utf-8")
        if archive_path:
            archive_path.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(archive_path))

    return ImportResult(source=src, target=target_path, archived=archive_path)


def main() -> int:
    args = parse_args()
    source_root = Path(args.source).resolve()
    target_root = Path(args.target).resolve()
    archive_root = Path(args.archive).resolve()

    if not source_root.exists():
        print(f"Source not found: {source_root}")
        return 1

    files = sorted(
        p for p in source_root.rglob("*") if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS
    )
    if not files:
        print(f"No files found in {source_root} with extensions: {', '.join(sorted(SUPPORTED_EXTS))}")
        return 0

    results: list[ImportResult] = []
    for src in files:
        result = import_one(src, source_root, target_root, archive_root, args)
        results.append(result)
        msg = f"IMPORTED: {src} -> {result.target}"
        if result.archived:
            msg += f" | archived -> {result.archived}"
        if args.dry_run:
            msg = f"DRY-RUN: {msg}"
        print(msg)

    print(f"\nDone. {len(results)} file(s) processed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
