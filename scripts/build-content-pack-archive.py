#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import pathlib
import shutil
import stat
import subprocess
import sys
import uuid
import zipfile

MAX_FILES = 256
MAX_FILE_BYTES = 512 * 1024 * 1024
MAX_TOTAL_BYTES = 1_500 * 1024 * 1024
FIXED_TIME = (2020, 1, 1, 0, 0, 0)
STORED_SUFFIXES = {
    ".mov", ".mp4", ".m4a", ".mp3", ".wav", ".jpg", ".jpeg", ".png", ".webp"
}


class BuildFailure(Exception):
    def __init__(self, code: str, message: str, action: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.action = action


def fail(code: str, message: str, action: str) -> None:
    raise BuildFailure(code, message, action)


def receipt_failure(error: BuildFailure) -> dict[str, object]:
    return {
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": error.action,
        "writesPerformed": False,
        "releaseState": "NOT_PUBLIC_RELEASE_READY",
    }


def validate_relative(relative: pathlib.PurePosixPath) -> None:
    parts = relative.parts
    if (
        not parts
        or any(part in {"", ".", ".."} or part.startswith(".") for part in parts)
        or any(len(part.encode("utf-8")) > 255 for part in parts)
    ):
        fail(
            "PACK_ARCHIVE_BUILD_UNSAFE_SOURCE",
            "The pack directory contains a hidden, unsafe or non-normalized path.",
            "Remove hidden metadata and unsafe paths, rerun validation, then rebuild the archive.",
        )


def inventory(root: pathlib.Path) -> list[tuple[pathlib.Path, pathlib.PurePosixPath, int]]:
    files: list[tuple[pathlib.Path, pathlib.PurePosixPath, int]] = []
    canonical: set[str] = set()
    total = 0
    for current, directory_names, file_names in os.walk(root, followlinks=False):
        directory_names.sort()
        file_names.sort()
        current_path = pathlib.Path(current)
        for name in list(directory_names):
            path = current_path / name
            relative = pathlib.PurePosixPath(path.relative_to(root).as_posix())
            validate_relative(relative)
            mode = path.lstat().st_mode
            if stat.S_ISLNK(mode) or not stat.S_ISDIR(mode):
                fail(
                    "PACK_ARCHIVE_BUILD_UNSAFE_SOURCE",
                    "The pack directory contains a link or unsupported filesystem entry.",
                    "Replace every entry with a regular file or directory, then rebuild.",
                )
        for name in file_names:
            path = current_path / name
            relative = pathlib.PurePosixPath(path.relative_to(root).as_posix())
            validate_relative(relative)
            info = path.lstat()
            if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
                fail(
                    "PACK_ARCHIVE_BUILD_UNSAFE_SOURCE",
                    "The pack directory contains a link or unsupported filesystem entry.",
                    "Replace every entry with a regular file, then rebuild.",
                )
            key = str(relative).casefold()
            if key in canonical:
                fail(
                    "PACK_ARCHIVE_BUILD_PATH_COLLISION",
                    "The pack directory contains a case-insensitive path collision.",
                    "Rename the colliding entries, update manifest.json and rebuild.",
                )
            canonical.add(key)
            if info.st_size > MAX_FILE_BYTES:
                fail(
                    "PACK_ARCHIVE_BUILD_RESOURCE_LIMIT",
                    "A pack file exceeds the archive per-file limit.",
                    "Transcode or split the file below the documented limit, then rebuild.",
                )
            total += info.st_size
            if total > MAX_TOTAL_BYTES or len(files) + 1 > MAX_FILES:
                fail(
                    "PACK_ARCHIVE_BUILD_RESOURCE_LIMIT",
                    "The pack exceeds the archive file-count or unpacked-size limit.",
                    "Reduce the pack below the documented limits, then rebuild.",
                )
            files.append((path, relative, info.st_size))
    if not files or not (root / "manifest.json").is_file():
        fail(
            "PACK_ARCHIVE_BUILD_MANIFEST_MISSING",
            "The selected pack directory does not contain manifest.json.",
            "Choose a validated content-pack directory and retry.",
        )
    return files


def run_gate(command: list[str], code: str, message: str, action: str) -> dict[str, object]:
    completed = subprocess.run(
        command,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if completed.returncode != 0:
        fail(code, message, action)
    try:
        data = json.loads(completed.stdout)
    except json.JSONDecodeError:
        fail(code, message, action)
    if data.get("status") != "PASS":
        fail(code, message, action)
    return data


def write_archive(
    files: list[tuple[pathlib.Path, pathlib.PurePosixPath, int]],
    destination: pathlib.Path,
) -> None:
    with zipfile.ZipFile(destination, "x", allowZip64=False) as archive:
        for source, relative, expected_size in files:
            suffix = source.suffix.lower()
            compression = zipfile.ZIP_STORED if suffix in STORED_SUFFIXES else zipfile.ZIP_DEFLATED
            info = zipfile.ZipInfo(str(relative), date_time=FIXED_TIME)
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            info.compress_type = compression
            flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
            descriptor = os.open(source, flags)
            try:
                opened = os.fstat(descriptor)
                if not stat.S_ISREG(opened.st_mode) or opened.st_size != expected_size:
                    fail(
                        "PACK_ARCHIVE_BUILD_SOURCE_CHANGED",
                        "The pack changed while the archive was being built.",
                        "Stop editing the pack, rerun validation and rebuild.",
                    )
                with os.fdopen(descriptor, "rb", closefd=False) as input_stream:
                    with archive.open(info, "w", force_zip64=False) as output_stream:
                        shutil.copyfileobj(input_stream, output_stream, length=1024 * 1024)
            finally:
                os.close(descriptor)


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("pack", nargs="?")
    parser.add_argument("output", nargs="?")
    parser.add_argument("--app-version", default="0.19.98")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--help", action="store_true")
    args, unknown = parser.parse_known_args()
    if args.help:
        print(
            "Usage: build-content-pack-archive.sh <pack-directory> "
            "<output.chengyinpack> [--app-version x.y.z] [--json]"
        )
        return 0
    try:
        if unknown or not args.pack or not args.output:
            fail(
                "PACK_ARCHIVE_BUILD_ARGUMENTS",
                "Exactly one pack directory and output .chengyinpack are required.",
                "Run scripts/build-content-pack-archive.sh --help and retry.",
            )
        project = pathlib.Path(__file__).resolve().parent.parent
        pack = pathlib.Path(args.pack).expanduser()
        output = pathlib.Path(args.output).expanduser()
        if (
            output.suffix.lower() != ".chengyinpack"
            or output.exists()
            or output.is_symlink()
            or not output.parent.is_dir()
            or output.parent.is_symlink()
            or not pack.is_dir()
            or pack.is_symlink()
        ):
            fail(
                "PACK_ARCHIVE_BUILD_INVALID_TARGET",
                "The input directory or output .chengyinpack target is missing or unsafe.",
                "Choose a regular pack directory and a new .chengyinpack filename, then retry.",
            )
        run_gate(
            [
                str(project / "scripts" / "validate-content-pack.sh"),
                str(pack),
                "--app-version",
                args.app_version,
                "--json",
            ],
            "PACK_ARCHIVE_BUILD_SOURCE_INVALID",
            "The source pack did not pass manifest, hash and media validation.",
            "Run scripts/validate-content-pack.sh on the directory, repair it, then rebuild.",
        )
        files = inventory(pack)
        temporary = output.parent / f".{output.name}.{uuid.uuid4().hex}.tmp.chengyinpack"
        try:
            write_archive(files, temporary)
            archive_receipt = run_gate(
                [
                    str(project / "scripts" / "audit-content-pack-archive.sh"),
                    str(temporary),
                    "--app-version",
                    args.app_version,
                    "--json",
                ],
                "PACK_ARCHIVE_BUILD_POSTVALIDATION_FAILED",
                "The staged archive did not pass the independent archive audit.",
                "Discard the staged output, run scripts/doctor.sh and rebuild.",
            )
            digest = sha256(temporary)
            size = temporary.stat().st_size
            os.replace(temporary, output)
        finally:
            if temporary.exists():
                temporary.unlink()
        receipt = {
            "status": "PASS",
            "schemaVersion": "chengyin.content-pack-archive-build/v1",
            "archiveSHA256": digest,
            "archiveBytes": size,
            "fileCount": len(files),
            "layout": archive_receipt["layout"],
            "validationScope": archive_receipt["validationScope"],
            "writesPerformed": True,
            "releaseState": "NOT_PUBLIC_RELEASE_READY",
        }
        if args.json:
            print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
        else:
            print("PASS  Safe .chengyinpack created and independently revalidated.")
            print(f"      SHA-256 {digest}")
        return 0
    except BuildFailure as error:
        receipt = receipt_failure(error)
        if args.json:
            print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
        else:
            print(f"FAIL  [{error.code}] {error.message}", file=sys.stderr)
            print(f"ACTION  {error.action}", file=sys.stderr)
        return 1
    except Exception:
        error = BuildFailure(
            "PACK_ARCHIVE_BUILD_UNEXPECTED",
            "The content-pack archive could not be built safely.",
            "Run scripts/doctor.sh, then retry; no final archive was published.",
        )
        if args.json:
            print(json.dumps(receipt_failure(error), ensure_ascii=False, sort_keys=True))
        else:
            print(f"FAIL  [{error.code}] {error.message}", file=sys.stderr)
            print(f"ACTION  {error.action}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
