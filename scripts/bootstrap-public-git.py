#!/usr/bin/env python3
"""Create an audited, staged, commit-free public Git candidate.

The current development directory may contain private production inputs,
historical release artifacts and local state. This command never initializes
that directory. It builds the existing portable-source allowlist, audits the
archive, extracts it into a new destination and initializes only that clean
public tree.
"""

from __future__ import annotations

import json
import ctypes
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from typing import Optional


CONTRACT = "chengyin.public-git-bootstrap/v1"
RELEASE_STATE = "NOT_PUBLIC_RELEASE_READY"
PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILDER = PROJECT_ROOT / "scripts/build-portable-source.sh"
ARCHIVE_AUDITOR = PROJECT_ROOT / "scripts/audit-portable-source.py"
SECRET_AUDITOR = PROJECT_ROOT / "scripts/audit-public-source-secrets.py"
SAFE_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._ -]{0,95}$")
FORBIDDEN_ROOTS = {
    ".agents",
    ".ai-bridge",
    ".build",
    ".codex",
    ".git",
    ".swiftpm",
    "DerivedData",
    "dist",
    "generated",
    "local-entitlements",
    "pack-staging",
    "video-production",
}


@dataclass(frozen=True)
class BootstrapFailure(Exception):
    code: str
    message: str
    recovery: str


def fail(code: str, message: str, recovery: str) -> None:
    raise BootstrapFailure(code, message, recovery)


def receipt(
    *,
    status: str,
    code: Optional[str],
    message: str,
    recovery: Optional[str],
    staged_count: int = 0,
    destination_created: bool = False,
    source_identity: Optional[str] = None,
    source_audit: str = "NOT_RUN",
    credential_audit: str = "NOT_RUN",
) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": status,
        "code": code,
        "message": message,
        "recoveryAction": recovery,
        "repositoryState": (
            "staged-unborn-main" if status == "PASS" else "not-created"
        ),
        "branch": "main" if status == "PASS" else None,
        "stagedFileCount": staged_count,
        "commitCreated": False,
        "remoteConfigured": False,
        "destinationCreated": destination_created,
        "sourcePackageIdentity": source_identity,
        "sourcePackageAudit": source_audit,
        "credentialAudit": credential_audit,
        "networkRequired": False,
        "authoritativeSourceMutation": False,
        "releaseState": RELEASE_STATE,
    }


def run(
    command: list[str],
    *,
    cwd: pathlib.Path,
    environment: dict[str, str],
    timeout: int = 900,
    allow_failure: bool = False,
    failure_code: str = "PUBLIC_GIT_BOOTSTRAP_BUILD_FAILED",
) -> subprocess.CompletedProcess[bytes]:
    completed = subprocess.run(
        command,
        cwd=cwd,
        env=environment,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=timeout,
        check=False,
    )
    if completed.returncode != 0 and not allow_failure:
        fail(
            failure_code,
            "A local public-repository preparation command failed.",
            "Run the portable-source smoke and public credential audit, repair the first failure, then retry with a new destination.",
        )
    return completed


def publish_exclusive(source: pathlib.Path, destination: pathlib.Path) -> None:
    """Atomically publish one directory without replacing an existing path.

    Chengyin's supported bootstrap host is macOS. ``renamex_np`` with
    ``RENAME_EXCL`` closes the check/rename race that a separate exists check
    would leave behind, while keeping the staged checkout on the same volume.
    """

    rename_exclusive = getattr(ctypes.CDLL(None, use_errno=True), "renamex_np", None)
    if rename_exclusive is None:
        fail(
            "PUBLIC_GIT_BOOTSTRAP_GIT_FAILED",
            "This macOS runtime cannot publish the candidate without replacement risk.",
            "Use a current supported macOS runtime and retry with a new destination.",
        )
    rename_exclusive.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
    rename_exclusive.restype = ctypes.c_int
    rename_excl = 0x00000004
    result = rename_exclusive(
        os.fsencode(source), os.fsencode(destination), rename_excl
    )
    if result == 0:
        return
    error_number = ctypes.get_errno()
    if destination.exists() or destination.is_symlink():
        fail(
            "PUBLIC_GIT_BOOTSTRAP_DESTINATION_EXISTS",
            "The public Git destination appeared before the audited candidate was published.",
            "Choose a new destination; this command never replaces an existing path.",
        )
    raise OSError(error_number, "exclusive repository publication failed")


def parse_json_output(
    completed: subprocess.CompletedProcess[bytes],
    *,
    failure_code: str,
    label: str,
) -> dict[str, object]:
    try:
        value = json.loads(completed.stdout.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        fail(
            failure_code,
            f"The {label} returned no valid machine receipt.",
            "Run the underlying audit directly, repair its first failure, then retry with a new destination.",
        )
    if not isinstance(value, dict) or value.get("status") != "PASS":
        fail(
            failure_code,
            f"The {label} did not pass.",
            "Run the underlying audit directly, repair its first failure, then retry with a new destination.",
        )
    return value


def safe_destination(raw: str) -> pathlib.Path:
    destination = pathlib.Path(raw).expanduser()
    if not destination.is_absolute() or not SAFE_NAME.fullmatch(destination.name):
        fail(
            "PUBLIC_GIT_BOOTSTRAP_INVALID_ARGUMENT",
            "The destination must be an absolute path with a bounded directory name.",
            "Choose a new absolute destination outside the Chengyin project and retry.",
        )
    if destination.exists() or destination.is_symlink():
        fail(
            "PUBLIC_GIT_BOOTSTRAP_DESTINATION_EXISTS",
            "The public Git destination already exists.",
            "Choose a new destination; this command never overwrites or merges an existing directory.",
        )
    parent = destination.parent
    if parent.is_symlink() or not parent.is_dir():
        fail(
            "PUBLIC_GIT_BOOTSTRAP_UNSAFE_DESTINATION",
            "The destination parent is unavailable or symbolic.",
            "Choose a regular existing parent directory and retry.",
        )
    resolved_parent = parent.resolve()
    resolved_destination = resolved_parent / destination.name
    project = PROJECT_ROOT.resolve()
    if resolved_destination == project or project in resolved_destination.parents:
        fail(
            "PUBLIC_GIT_BOOTSTRAP_UNSAFE_DESTINATION",
            "The public Git destination cannot be inside the development project.",
            "Choose a separate local directory so generated Git state cannot pollute the authoritative source.",
        )
    return resolved_destination


def public_files(checkout: pathlib.Path) -> set[str]:
    result: set[str] = set()
    for path in checkout.rglob("*"):
        relative = path.relative_to(checkout)
        if relative.parts and relative.parts[0] == ".git":
            continue
        if path.is_symlink() or not path.is_file():
            if path.is_symlink():
                fail(
                    "PUBLIC_GIT_BOOTSTRAP_SOURCE_MISMATCH",
                    "The audited public checkout contains a symbolic link.",
                    "Restore a regular-file portable source package and retry.",
                )
            continue
        result.add(relative.as_posix())
    return result


def bootstrap(destination: pathlib.Path) -> dict[str, object]:
    git = shutil.which("git")
    if not git:
        fail(
            "PUBLIC_GIT_BOOTSTRAP_GIT_UNAVAILABLE",
            "Git is unavailable on this Mac.",
            "Install Xcode Command Line Tools, verify git --version, then retry.",
        )

    work_root = pathlib.Path(
        tempfile.mkdtemp(prefix=".chengyin-public-git.", dir=destination.parent)
    )
    environment = os.environ.copy()
    environment["PYTHONDONTWRITEBYTECODE"] = "1"
    environment["TMPDIR"] = str(work_root)
    archive = work_root / "public-source.zip"
    extract_root = work_root / "extract"
    source_identity: Optional[str] = None
    try:
        run(
            [str(BUILDER), "--output", str(archive)],
            cwd=PROJECT_ROOT,
            environment=environment,
        )
        archive_audit = parse_json_output(
            run(
                [sys.executable, str(ARCHIVE_AUDITOR), str(archive), "--json"],
                cwd=PROJECT_ROOT,
                environment=environment,
                allow_failure=True,
            ),
            failure_code="PUBLIC_GIT_BOOTSTRAP_SOURCE_AUDIT_FAILED",
            label="portable-source audit",
        )
        source_identity_value = archive_audit.get("sourcePackageIdentity")
        archive_root_value = archive_audit.get("archiveRoot")
        if not isinstance(source_identity_value, str) or not isinstance(
            archive_root_value, str
        ):
            fail(
                "PUBLIC_GIT_BOOTSTRAP_SOURCE_AUDIT_FAILED",
                "The portable-source audit omitted its bounded identity.",
                "Restore the source-package contract and retry with a new destination.",
            )
        source_identity = source_identity_value
        extract_root.mkdir()
        run(
            ["/usr/bin/ditto", "-x", "-k", str(archive), str(extract_root)],
            cwd=PROJECT_ROOT,
            environment=environment,
            failure_code="PUBLIC_GIT_BOOTSTRAP_SOURCE_MISMATCH",
        )
        checkout = extract_root / archive_root_value
        if checkout.is_symlink() or not checkout.is_dir():
            fail(
                "PUBLIC_GIT_BOOTSTRAP_SOURCE_MISMATCH",
                "The audited source root was not extracted as one regular directory.",
                "Restore the portable-source builder and retry with a new destination.",
            )
        credential_audit = parse_json_output(
            run(
                [
                    sys.executable,
                    str(SECRET_AUDITOR),
                    "--root",
                    str(checkout),
                    "--json",
                ],
                cwd=PROJECT_ROOT,
                environment=environment,
                allow_failure=True,
            ),
            failure_code="PUBLIC_GIT_BOOTSTRAP_SOURCE_AUDIT_FAILED",
            label="public credential audit",
        )
        if credential_audit.get("privateDirectoriesScanned") is not False:
            fail(
                "PUBLIC_GIT_BOOTSTRAP_SOURCE_AUDIT_FAILED",
                "The credential receipt did not preserve the bounded public scope.",
                "Restore the public-source credential audit contract and retry.",
            )
        run(
            [git, "init", "--initial-branch=main", "."],
            cwd=checkout,
            environment=environment,
            failure_code="PUBLIC_GIT_BOOTSTRAP_GIT_FAILED",
        )
        run(
            [git, "add", "--all"],
            cwd=checkout,
            environment=environment,
            failure_code="PUBLIC_GIT_BOOTSTRAP_GIT_FAILED",
        )
        listed = run(
            [git, "ls-files", "-z"],
            cwd=checkout,
            environment=environment,
            failure_code="PUBLIC_GIT_BOOTSTRAP_GIT_FAILED",
        ).stdout
        try:
            staged = {
                item.decode("utf-8")
                for item in listed.split(b"\0")
                if item
            }
        except UnicodeDecodeError:
            fail(
                "PUBLIC_GIT_BOOTSTRAP_SOURCE_MISMATCH",
                "The staged public index contains a non-UTF-8 path.",
                "Rename the source path and rebuild the portable source package.",
            )
        expected = public_files(checkout)
        if staged != expected or not staged:
            fail(
                "PUBLIC_GIT_BOOTSTRAP_SOURCE_MISMATCH",
                "The staged Git index does not exactly match the audited public source tree.",
                "Repair .gitignore or the portable-source allowlist, then retry with a new destination.",
            )
        if any(path.split("/", 1)[0] in FORBIDDEN_ROOTS for path in staged):
            fail(
                "PUBLIC_GIT_BOOTSTRAP_SOURCE_MISMATCH",
                "A private or generated root entered the staged Git index.",
                "Remove the private root from the public-source allowlist and retry.",
            )
        branch = run(
            [git, "symbolic-ref", "--short", "HEAD"],
            cwd=checkout,
            environment=environment,
            failure_code="PUBLIC_GIT_BOOTSTRAP_GIT_FAILED",
        ).stdout.decode("utf-8", errors="replace").strip()
        remotes = run(
            [git, "remote"], cwd=checkout, environment=environment
        ).stdout.strip()
        head = run(
            [git, "rev-parse", "--verify", "HEAD"],
            cwd=checkout,
            environment=environment,
            allow_failure=True,
        )
        if branch != "main" or remotes or head.returncode == 0:
            fail(
                "PUBLIC_GIT_BOOTSTRAP_GIT_FAILED",
                "The candidate repository gained an unexpected branch, remote or commit.",
                "Discard the candidate and retry from a trusted Git installation.",
            )
        publish_exclusive(checkout, destination)
        return receipt(
            status="PASS",
            code=None,
            message=(
                "An audited public Git candidate was created with every public file staged; "
                "the owner still controls the first commit and remote."
            ),
            recovery=None,
            staged_count=len(staged),
            destination_created=True,
            source_identity=source_identity,
            source_audit="PASS",
            credential_audit="PASS",
        )
    finally:
        shutil.rmtree(work_root, ignore_errors=True)


def parse_arguments(argv: list[str]) -> tuple[pathlib.Path, bool]:
    json_mode = "--json" in argv
    destination_value: Optional[str] = None
    index = 0
    while index < len(argv):
        argument = argv[index]
        if argument == "--json":
            index += 1
        elif argument == "--destination":
            if index + 1 >= len(argv) or argv[index + 1].startswith("-"):
                fail(
                    "PUBLIC_GIT_BOOTSTRAP_INVALID_ARGUMENT",
                    "The destination option requires one path.",
                    "Provide --destination followed by a new absolute directory path.",
                )
            destination_value = argv[index + 1]
            index += 2
        elif argument in {"--help", "-h"}:
            print(
                "Usage: python3 scripts/bootstrap-public-git.py "
                "--destination <new-absolute-directory> [--json]"
            )
            raise SystemExit(0)
        else:
            fail(
                "PUBLIC_GIT_BOOTSTRAP_INVALID_ARGUMENT",
                "The public Git bootstrap received an unknown option.",
                "Run the command with --help, correct the option and retry.",
            )
    if destination_value is None:
        fail(
            "PUBLIC_GIT_BOOTSTRAP_INVALID_ARGUMENT",
            "A new destination is required.",
            "Provide --destination followed by a new absolute directory path.",
        )
    return safe_destination(destination_value), json_mode


def emit(value: dict[str, object], json_mode: bool) -> int:
    if json_mode:
        print(json.dumps(value, ensure_ascii=False, sort_keys=True))
    elif value["status"] == "PASS":
        print(
            "Public Git bootstrap: PASS "
            f"({value['stagedFileCount']} staged files, no commit, no remote)"
        )
        print(f"Release state: {RELEASE_STATE}")
    else:
        print(f"FAIL  [{value['code']}] {value['message']}", file=sys.stderr)
        print(f"ACTION  {value['recoveryAction']}", file=sys.stderr)
    return 0 if value["status"] == "PASS" else 1


def main(argv: list[str]) -> int:
    json_mode = "--json" in argv
    try:
        destination, json_mode = parse_arguments(argv)
        value = bootstrap(destination)
    except BootstrapFailure as error:
        value = receipt(
            status="FAIL",
            code=error.code,
            message=error.message,
            recovery=error.recovery,
        )
    except (OSError, subprocess.SubprocessError):
        value = receipt(
            status="FAIL",
            code="PUBLIC_GIT_BOOTSTRAP_UNEXPECTED_ERROR",
            message="The public Git candidate could not be created safely.",
            recovery="Choose a new local destination, run the portable-source smoke, then retry.",
        )
    return emit(value, json_mode)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
