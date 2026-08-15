#!/usr/bin/env python3
"""Use Swift's parser output to audit Chengyin source-module boundaries."""

from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import stat
import subprocess
import sys
import tempfile


CONTRACT = "chengyin.swift-compiler-boundaries/v1"
DEFAULT_ROOT = pathlib.Path(__file__).resolve().parent.parent
MAX_SWIFT_FILES = 256
MAX_FILE_BYTES = 512 * 1024
MAX_TOTAL_BYTES = 4 * 1024 * 1024
MAX_AST_BYTES = 12 * 1024 * 1024
TARGETS = {
    "CompanionContracts": {
        "path": pathlib.Path("Sources/CompanionContracts"),
        "allowedImports": {"Foundation", "CoreGraphics"},
        "requiredImports": set(),
    },
    "CompanionApp": {
        "path": pathlib.Path("Sources/CompanionApp"),
        "allowedImports": {
            "AVFoundation",
            "AppKit",
            "Combine",
            "CompanionContracts",
            "CoreGraphics",
            "CoreMedia",
            "CryptoKit",
            "Darwin",
            "Foundation",
            "ImageIO",
            "QuartzCore",
            "ServiceManagement",
            "SwiftUI",
            "UniformTypeIdentifiers",
        },
        "requiredImports": {"CompanionContracts"},
    },
    "CompanionContractChecks": {
        "path": pathlib.Path("Tests/CompanionContractsTests"),
        "allowedImports": {"CompanionContracts", "Darwin", "Foundation"},
        "requiredImports": {"CompanionContracts"},
    },
    "CompanionEventEmitter": {
        "path": pathlib.Path("Tools/CompanionEventEmitter"),
        "allowedImports": {"CompanionContracts", "Darwin", "Foundation"},
        "requiredImports": {"CompanionContracts"},
    },
}
REQUIRED_PUBLIC_CORE_DECLARATIONS = {
    "CompanionChemistryInteractionDirector",
    "CompanionDisplaySelectionPolicy",
    "CompanionExperienceDirector",
    "CompanionFirstSessionJourney",
    "CompanionLifestyleMemoryStore",
    "CompanionLifestyleScheduler",
    "CompanionLocaleResolutionPolicy",
    "CompanionMicrogameCompletionPolicy",
    "CompanionMicrogameSession",
    "CompanionMicrogameWindowPlacement",
    "CompanionMicrogameWindowPolicy",
    "CompanionPetDragPolicy",
    "CompanionPlaybackHealthAccumulator",
    "CompanionPlayPaletteLayout",
    "CompanionPlayPaletteLayoutPlan",
    "CompanionPresentationLifecycle",
    "CompanionPresentationProjection",
    "CompanionPresentationSession",
    "CompanionProjectionAuthoringReceipt",
    "CompanionRuntimeReadiness",
    "CompanionTaskCompletionPolicy",
    "CompanionUserPresentationPolicy",
    "CompanionWindowPolicy",
    "CompanionWorkdayExperiencePolicy",
    "CompanionWorkdaySignalSourcePolicy",
    "CompanionWorkdaySignalTrustPolicy",
    "CompanionWorkdayStateStore",
}
IMPORT_PATTERN = re.compile(r'\(import_decl[^\n]*\bmodule="([^"]+)"')
TOP_LEVEL_DECLARATION_PATTERN = re.compile(
    r'^  \((?:struct_decl|enum_decl|class_decl|protocol|typealias_decl)\b[^\n]*? "([^"]+)"',
    re.MULTILINE,
)
PUBLIC_ACCESS_PATTERN = re.compile(r'\(access_control_attr[^\n]*\baccess_level=public\)')


class CompilerBoundaryFailure(Exception):
    def __init__(self, code: str, message: str, recovery: str):
        super().__init__(message)
        self.code = code
        self.message = message
        self.recovery = recovery


def fail(code: str, message: str, recovery: str) -> None:
    raise CompilerBoundaryFailure(code, message, recovery)


def parse_arguments(arguments: list[str]) -> tuple[pathlib.Path, bool]:
    root = DEFAULT_ROOT
    json_output = False
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        if argument == "--json":
            json_output = True
        elif argument == "--root" and index + 1 < len(arguments):
            index += 1
            root = pathlib.Path(arguments[index])
        elif argument in {"--help", "-h"}:
            print("Usage: audit-swift-compiler-boundaries.py [--root DIR] [--json]")
            raise SystemExit(0)
        else:
            fail(
                "SWIFT_COMPILER_BOUNDARY_INVALID_ARGUMENT",
                "The Swift compiler boundary audit received an unsupported argument.",
                "Use only --root DIR and --json, then retry.",
            )
        index += 1
    if not root.is_dir() or root.is_symlink():
        fail(
            "SWIFT_COMPILER_BOUNDARY_INVALID_ARGUMENT",
            "The Swift compiler boundary audit root is missing or unsafe.",
            "Provide a regular extracted project directory and retry.",
        )
    return root.resolve(), json_output


def regular_swift_files(root: pathlib.Path, relative: pathlib.Path) -> list[pathlib.Path]:
    target = root / relative
    if not target.is_dir() or target.is_symlink():
        fail(
            "SWIFT_COMPILER_BOUNDARY_SOURCE_ROOT_MISSING",
            "A reviewed Swift target source root is missing or unsafe.",
            "Restore the four documented target source roots and retry.",
        )
    files: list[pathlib.Path] = []
    pending = [target]
    while pending:
        directory = pending.pop()
        try:
            entries = sorted(os.scandir(directory), key=lambda item: item.name)
        except OSError:
            fail(
                "SWIFT_COMPILER_BOUNDARY_SOURCE_UNSAFE",
                "A Swift target source directory could not be inspected safely.",
                "Restore regular local source directories without links and retry.",
            )
        for entry in entries:
            if entry.name == "Resources" and directory == target:
                continue
            try:
                metadata = entry.stat(follow_symlinks=False)
            except OSError:
                fail(
                    "SWIFT_COMPILER_BOUNDARY_SOURCE_UNSAFE",
                    "A Swift target source entry changed during inspection.",
                    "Stop concurrent source mutation and rerun the audit.",
                )
            mode = metadata.st_mode
            if stat.S_ISLNK(mode):
                fail(
                    "SWIFT_COMPILER_BOUNDARY_SOURCE_UNSAFE",
                    "A Swift target source tree contains a symbolic link.",
                    "Replace linked source entries with reviewed regular files or directories.",
                )
            if stat.S_ISDIR(mode):
                if entry.name.startswith("."):
                    continue
                pending.append(pathlib.Path(entry.path))
                continue
            if entry.name.endswith(".swift"):
                if not stat.S_ISREG(mode):
                    fail(
                        "SWIFT_COMPILER_BOUNDARY_SOURCE_UNSAFE",
                        "A Swift source entry is not a regular file.",
                        "Restore the reviewed regular Swift source file and retry.",
                    )
                if metadata.st_size > MAX_FILE_BYTES:
                    fail(
                        "SWIFT_COMPILER_BOUNDARY_SOURCE_LIMIT_EXCEEDED",
                        "A Swift source file exceeds the bounded compiler-audit limit.",
                        "Split the source by responsibility and retry.",
                    )
                files.append(pathlib.Path(entry.path))
    if not files:
        fail(
            "SWIFT_COMPILER_BOUNDARY_SOURCE_ROOT_MISSING",
            "A reviewed Swift target contains no regular Swift source files.",
            "Restore the target source files and retry.",
        )
    return sorted(files)


def select_compiler() -> tuple[str, str]:
    try:
        compiler = subprocess.run(
            ["/usr/bin/xcrun", "--find", "swiftc"],
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
        ).stdout.strip()
        version = subprocess.run(
            [compiler, "--version"],
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
        ).stdout.splitlines()[0].strip()
    except (OSError, subprocess.SubprocessError, IndexError):
        fail(
            "SWIFT_COMPILER_BOUNDARY_TOOLCHAIN_UNAVAILABLE",
            "A compatible local Swift compiler could not be selected.",
            "Run the source preflight, repair Xcode Command Line Tools, and retry.",
        )
    if not compiler or not version or len(version) > 240:
        fail(
            "SWIFT_COMPILER_BOUNDARY_TOOLCHAIN_UNAVAILABLE",
            "The selected Swift compiler returned an unsupported identity.",
            "Repair Xcode Command Line Tools and rerun the source preflight.",
        )
    return compiler, version


def public_declarations(ast: str) -> set[str]:
    matches = list(TOP_LEVEL_DECLARATION_PATTERN.finditer(ast))
    result: set[str] = set()
    for index, match in enumerate(matches):
        end = matches[index + 1].start() if index + 1 < len(matches) else len(ast)
        if PUBLIC_ACCESS_PATTERN.search(ast, match.start(), end):
            result.add(match.group(1))
    return result


def source_digest(root: pathlib.Path, files: list[pathlib.Path]) -> str:
    digest = hashlib.sha256()
    for source in sorted(files):
        relative = source.relative_to(root).as_posix().encode("utf-8")
        digest.update(len(relative).to_bytes(4, "big"))
        digest.update(relative)
        payload = source.read_bytes()
        digest.update(len(payload).to_bytes(8, "big"))
        digest.update(payload)
    return digest.hexdigest()


def audit(root: pathlib.Path) -> dict[str, object]:
    compiler, compiler_identity = select_compiler()
    target_files: dict[str, list[pathlib.Path]] = {}
    all_files: list[pathlib.Path] = []
    total_bytes = 0
    for target_name, policy in TARGETS.items():
        files = regular_swift_files(root, policy["path"])
        target_files[target_name] = files
        all_files.extend(files)
        total_bytes += sum(source.stat().st_size for source in files)
    if len(all_files) > MAX_SWIFT_FILES or total_bytes > MAX_TOTAL_BYTES:
        fail(
            "SWIFT_COMPILER_BOUNDARY_SOURCE_LIMIT_EXCEEDED",
            "The reviewed Swift source set exceeds the bounded compiler-audit limits.",
            "Remove generated or unrelated sources, split oversized files, and retry.",
        )

    target_receipts: dict[str, dict[str, object]] = {}
    core_public: set[str] = set()
    with tempfile.TemporaryDirectory(prefix="chengyin-compiler-boundary-") as temporary:
        environment = os.environ.copy()
        environment["CLANG_MODULE_CACHE_PATH"] = str(pathlib.Path(temporary) / "clang-cache")
        for target_name, files in target_files.items():
            imports: set[str] = set()
            target_public: set[str] = set()
            for source in files:
                try:
                    result = subprocess.run(
                        [compiler, "-frontend", "-dump-parse", str(source)],
                        check=False,
                        capture_output=True,
                        text=True,
                        timeout=20,
                        cwd=root,
                        env=environment,
                    )
                except (OSError, subprocess.SubprocessError):
                    fail(
                        "SWIFT_COMPILER_BOUNDARY_PARSE_FAILED",
                        "The Swift compiler could not parse a reviewed source file.",
                        "Run swift build, repair the reported source syntax, and retry.",
                    )
                if result.returncode != 0 or not result.stdout.startswith("(source_file "):
                    fail(
                        "SWIFT_COMPILER_BOUNDARY_PARSE_FAILED",
                        "The Swift compiler rejected a reviewed source file.",
                        "Run swift build, repair the reported source syntax, and retry.",
                    )
                if len(result.stdout.encode("utf-8")) > MAX_AST_BYTES:
                    fail(
                        "SWIFT_COMPILER_BOUNDARY_SOURCE_LIMIT_EXCEEDED",
                        "A compiler syntax projection exceeds the bounded audit limit.",
                        "Split the source by responsibility and retry.",
                    )
                imports.update(IMPORT_PATTERN.findall(result.stdout))
                target_public.update(public_declarations(result.stdout))

            policy = TARGETS[target_name]
            unexpected = imports - policy["allowedImports"]
            if unexpected:
                fail(
                    "SWIFT_COMPILER_BOUNDARY_IMPORT_VIOLATION",
                    "Compiler-parsed imports crossed the reviewed local-first module boundary.",
                    "Remove the unreviewed import or complete a separately reviewed dependency migration.",
                )
            missing = policy["requiredImports"] - imports
            if missing:
                fail(
                    "SWIFT_COMPILER_BOUNDARY_DEPENDENCY_EDGE_MISSING",
                    "A compiler-parsed target lost its required CompanionContracts import edge.",
                    "Restore the one-way CompanionContracts import in the executable target and retry.",
                )
            target_receipts[target_name] = {
                "fileCount": len(files),
                "sourceBytes": sum(source.stat().st_size for source in files),
                "sourceDigest": source_digest(root, files),
                "imports": sorted(imports),
                "publicTopLevelDeclarationCount": len(target_public),
            }
            if target_name == "CompanionContracts":
                core_public = target_public

    missing_public = REQUIRED_PUBLIC_CORE_DECLARATIONS - core_public
    if missing_public:
        fail(
            "SWIFT_COMPILER_BOUNDARY_PUBLIC_SURFACE_MISSING",
            "The compiler-parsed Core module lost a required public policy declaration.",
            "Restore the focused public contract or complete a reviewed compatibility migration.",
        )

    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "PASS",
        "code": None,
        "message": "Swift compiler parser evidence matches the reviewed local-first source boundary.",
        "recoveryAction": None,
        "compilerIdentity": compiler_identity,
        "compilerMode": "frontend-dump-parse",
        "targetCount": len(TARGETS),
        "swiftFileCount": len(all_files),
        "sourceBytes": total_bytes,
        "requiredPublicCoreDeclarationCount": len(REQUIRED_PUBLIC_CORE_DECLARATIONS),
        "targets": target_receipts,
        "networkRequired": False,
        "sourceExecuted": False,
        "proofStrength": "swift-compiler-parser-emitted-import-and-public-declaration-evidence-not-typechecked-dependency-or-sandbox-proof",
        "releaseState": "NOT_PUBLIC_RELEASE_READY",
    }


def failure_receipt(error: CompilerBoundaryFailure) -> dict[str, object]:
    return {
        "schemaVersion": 1,
        "contract": CONTRACT,
        "status": "FAIL",
        "code": error.code,
        "message": error.message,
        "recoveryAction": error.recovery,
        "networkRequired": False,
        "sourceExecuted": False,
        "proofStrength": "swift-compiler-parser-emitted-import-and-public-declaration-evidence-not-typechecked-dependency-or-sandbox-proof",
        "releaseState": "NOT_PUBLIC_RELEASE_READY",
    }


def render(receipt: dict[str, object], json_output: bool) -> None:
    if json_output:
        print(json.dumps(receipt, ensure_ascii=False, sort_keys=True))
        return
    if receipt["status"] == "PASS":
        print(
            "PASS  Swift compiler source boundary: "
            f"{receipt['swiftFileCount']} files, {receipt['targetCount']} targets, "
            f"{receipt['requiredPublicCoreDeclarationCount']} required public Core declarations"
        )
    else:
        print(f"FAIL  {receipt['code']}: {receipt['message']}", file=sys.stderr)
        print(f"RECOVERY  {receipt['recoveryAction']}", file=sys.stderr)


def main() -> int:
    json_output = "--json" in sys.argv[1:]
    try:
        root, json_output = parse_arguments(sys.argv[1:])
        receipt = audit(root)
    except CompilerBoundaryFailure as error:
        render(failure_receipt(error), json_output)
        return 1
    except Exception:
        render(
            failure_receipt(
                CompilerBoundaryFailure(
                    "SWIFT_COMPILER_BOUNDARY_UNEXPECTED_ERROR",
                    "The Swift compiler boundary audit encountered an unexpected local error.",
                    "Run the source preflight, restore regular source files, and retry.",
                )
            ),
            json_output,
        )
        return 1
    render(receipt, json_output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
