#!/usr/bin/env python3
"""Permission-minimal macOS executable discovery without ps or pgrep."""

from __future__ import annotations

import ctypes
import os
import pathlib


PROC_ALL_PIDS = 1
PROC_PIDPATHINFO_MAXSIZE = 4096


class ProcessInspectionError(RuntimeError):
    """Raised when macOS cannot provide a trustworthy process snapshot."""


def _libproc() -> ctypes.CDLL:
    try:
        library = ctypes.CDLL(None, use_errno=True)
        library.proc_listpids.argtypes = [
            ctypes.c_uint32,
            ctypes.c_uint32,
            ctypes.c_void_p,
            ctypes.c_int,
        ]
        library.proc_listpids.restype = ctypes.c_int
        library.proc_pidpath.argtypes = [
            ctypes.c_int,
            ctypes.c_void_p,
            ctypes.c_uint32,
        ]
        library.proc_pidpath.restype = ctypes.c_int
        return library
    except (AttributeError, OSError) as error:
        raise ProcessInspectionError("macOS libproc is unavailable") from error


def executable_for_pid(pid: int) -> pathlib.Path | None:
    if pid <= 0:
        return None
    library = _libproc()
    buffer = ctypes.create_string_buffer(PROC_PIDPATHINFO_MAXSIZE)
    length = library.proc_pidpath(pid, buffer, ctypes.sizeof(buffer))
    if length <= 0:
        return None
    raw_path = buffer.value
    if not raw_path:
        return None
    return pathlib.Path(os.fsdecode(raw_path))


def discover_processes(executable_name: str) -> list[tuple[int, pathlib.Path]]:
    if not executable_name or "/" in executable_name:
        raise ProcessInspectionError("invalid executable name")
    library = _libproc()
    required_bytes = library.proc_listpids(PROC_ALL_PIDS, 0, None, 0)
    if required_bytes <= 0:
        raise ProcessInspectionError("macOS process enumeration is unavailable")
    integer_size = ctypes.sizeof(ctypes.c_int)
    capacity = max(64, required_bytes // integer_size + 256)
    buffer = (ctypes.c_int * capacity)()
    used_bytes = library.proc_listpids(
        PROC_ALL_PIDS,
        0,
        ctypes.byref(buffer),
        ctypes.sizeof(buffer),
    )
    if used_bytes <= 0:
        raise ProcessInspectionError("macOS process enumeration failed")

    processes: list[tuple[int, pathlib.Path]] = []
    for pid in buffer[: used_bytes // integer_size]:
        executable = executable_for_pid(pid)
        if executable is not None and executable.name == executable_name:
            processes.append((pid, executable))
    return processes


def discover_executables(executable_name: str) -> list[pathlib.Path]:
    return [executable for _, executable in discover_processes(executable_name)]
