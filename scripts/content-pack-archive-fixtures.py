#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import shutil
import stat
import struct
import sys
import warnings
import zipfile


def info(name: str, *, mode: int = stat.S_IFREG | 0o644) -> zipfile.ZipInfo:
    value = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
    value.create_system = 3
    value.external_attr = mode << 16
    value.compress_type = zipfile.ZIP_DEFLATED
    return value


def write_entries(path: pathlib.Path, entries: list[tuple[zipfile.ZipInfo, bytes]]) -> None:
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        with zipfile.ZipFile(path, "w", allowZip64=False) as archive:
            for entry, data in entries:
                archive.writestr(entry, data)


def pack_entries(source: pathlib.Path, prefix: str = "") -> list[tuple[zipfile.ZipInfo, bytes]]:
    values: list[tuple[zipfile.ZipInfo, bytes]] = []
    for path in sorted(source.rglob("*")):
        if path.is_file():
            relative = path.relative_to(source).as_posix()
            values.append((info(prefix + relative), path.read_bytes()))
    return values


def mutate_u16(path: pathlib.Path, local_offset: int, central_offset: int, value: int) -> None:
    data = bytearray(path.read_bytes())
    local = data.find(b"PK\x03\x04")
    central = data.find(b"PK\x01\x02")
    if local < 0 or central < 0:
        raise RuntimeError("fixture ZIP signatures missing")
    struct.pack_into("<H", data, local + local_offset, value)
    struct.pack_into("<H", data, central + central_offset, value)
    path.write_bytes(data)


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: content-pack-archive-fixtures.py <valid-pack> <output-directory>", file=sys.stderr)
        return 2
    source = pathlib.Path(sys.argv[1])
    output = pathlib.Path(sys.argv[2])
    output.mkdir(parents=True, exist_ok=False)

    flat = output / "valid-flat.chengyinpack"
    wrapped = output / "valid-wrapped.chengyinpack"
    write_entries(flat, pack_entries(source))
    write_entries(wrapped, pack_entries(source, "hello-workday/"))

    write_entries(
        output / "traversal.chengyinpack",
        [(info("manifest.json"), b"{}"), (info("../escape.txt"), b"escape")],
    )
    write_entries(
        output / "symlink.chengyinpack",
        [
            (info("manifest.json"), b"{}"),
            (info("media/link", mode=stat.S_IFLNK | 0o777), b"../../outside"),
        ],
    )
    write_entries(
        output / "duplicate.chengyinpack",
        [(info("manifest.json"), b"{}"), (info("manifest.json"), b"{\"second\":true}")],
    )
    write_entries(
        output / "case-collision.chengyinpack",
        [(info("manifest.json"), b"{}"), (info("Manifest.json"), b"{}")],
    )
    write_entries(
        output / "missing-manifest.chengyinpack",
        [(info("media/scene.mov"), b"not-media")],
    )
    (output / "corrupt.chengyinpack").write_bytes(b"not-a-zip")

    local_mismatch = output / "local-header-mismatch.chengyinpack"
    shutil.copy2(flat, local_mismatch)
    mismatch_data = bytearray(local_mismatch.read_bytes())
    local = mismatch_data.find(b"PK\x03\x04")
    mismatch_data[local + 30] ^= 0x20
    local_mismatch.write_bytes(mismatch_data)

    encrypted = output / "encrypted.chengyinpack"
    shutil.copy2(flat, encrypted)
    encrypted_data = bytearray(encrypted.read_bytes())
    local = encrypted_data.find(b"PK\x03\x04")
    central = encrypted_data.find(b"PK\x01\x02")
    local_flags = struct.unpack_from("<H", encrypted_data, local + 6)[0] | 0x0001
    central_flags = struct.unpack_from("<H", encrypted_data, central + 8)[0] | 0x0001
    struct.pack_into("<H", encrypted_data, local + 6, local_flags)
    struct.pack_into("<H", encrypted_data, central + 8, central_flags)
    encrypted.write_bytes(encrypted_data)

    unsupported = output / "unsupported-method.chengyinpack"
    shutil.copy2(flat, unsupported)
    mutate_u16(unsupported, 8, 10, 99)

    oversized = output / "oversized-entry.chengyinpack"
    write_entries(oversized, [(info("manifest.json"), b"{}")])
    oversized_data = bytearray(oversized.read_bytes())
    local = oversized_data.find(b"PK\x03\x04")
    central = oversized_data.find(b"PK\x01\x02")
    struct.pack_into("<I", oversized_data, local + 22, 768 * 1024 * 1024)
    struct.pack_into("<I", oversized_data, central + 24, 768 * 1024 * 1024)
    oversized.write_bytes(oversized_data)

    bomb = output / "compression-bomb.chengyinpack"
    write_entries(
        bomb,
        [(info("manifest.json"), b"0" * (17 * 1024 * 1024))],
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
