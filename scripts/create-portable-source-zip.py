#!/usr/bin/env python3
"""Create a metadata-free, UTF-8, deterministic ZIP from one source root."""

from __future__ import annotations

import pathlib
import shutil
import stat
import sys
import zipfile


FIXED_TIMESTAMP = (2026, 1, 1, 0, 0, 0)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("Usage: create-portable-source-zip.py <source-root> <output.zip>", file=sys.stderr)
        return 2
    source_root = pathlib.Path(argv[0])
    output_path = pathlib.Path(argv[1])
    if (
        not source_root.is_dir()
        or source_root.is_symlink()
        or output_path.exists()
        or output_path.is_symlink()
        or output_path.suffix != ".zip"
    ):
        print("Source ZIP inputs are missing, unsafe or already exist.", file=sys.stderr)
        return 1
    files = sorted(
        path
        for path in source_root.rglob("*")
        if path.is_file() and not path.is_symlink()
    )
    if not files:
        print("Source root contains no regular files.", file=sys.stderr)
        return 1
    for path in source_root.rglob("*"):
        if path.is_symlink():
            print("Source root contains a symbolic link.", file=sys.stderr)
            return 1
    with zipfile.ZipFile(
        output_path,
        "x",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=6,
        allowZip64=True,
    ) as archive:
        for path in files:
            relative = path.relative_to(source_root).as_posix()
            archive_name = f"{source_root.name}/{relative}"
            mode = stat.S_IMODE(path.stat().st_mode)
            info = zipfile.ZipInfo(archive_name, date_time=FIXED_TIMESTAMP)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | mode) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            with path.open("rb") as source, archive.open(info, "w") as destination:
                shutil.copyfileobj(source, destination, length=1024 * 1024)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
