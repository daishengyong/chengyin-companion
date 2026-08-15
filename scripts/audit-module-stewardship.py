#!/usr/bin/env python3
"""Audit and route Chengyin contribution paths without network or private-path receipts."""

from __future__ import annotations

import json
import pathlib
import re
import shlex
import stat
import sys
from dataclasses import dataclass
from typing import NoReturn


PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = PROJECT_ROOT / "community/module-stewardship.json"
SCHEMA_NAME = "chengyin.module-stewardship/v1"
RELEASE_STATE = "NOT_PUBLIC_RELEASE_READY"
IDENTITY_MODE = "role-only-until-canonical-github-organization"
MAX_MANIFEST_BYTES = 512 * 1024
MAX_ROUTE_PATHS = 128
MAX_STDIN_BYTES = 64 * 1024
ID_PATTERN = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
SEMVER_PATTERN = re.compile(
    r"^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
    r"(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)
TOP_FIELDS = {
    "schemaVersion",
    "contractID",
    "policyVersion",
    "identityMode",
    "roles",
    "checks",
    "modules",
    "forbiddenPathPrefixes",
}
ROLE_FIELDS = {"id", "title", "assignmentState", "responsibilities"}
CHECK_FIELDS = {"id", "title", "command", "recoveryAction"}
MODULE_FIELDS = {
    "id",
    "title",
    "pathPrefixes",
    "exactPaths",
    "reviewRoles",
    "requiredChecks",
    "riskClasses",
    "rfcPolicy",
    "ownerGatePolicy",
}
ASSIGNMENT_STATES = {
    "project-owner-boundary",
    "unassigned-until-canonical-github-organization",
}
RISK_CLASSES = {
    "accessibility",
    "documentation",
    "governance",
    "media-rights",
    "packaging",
    "privacy-security",
    "public-contract",
    "release",
    "runtime",
    "tooling",
}
RFC_POLICIES = {
    "not-required",
    "required-for-public-contract-or-persistence",
    "required-for-new-permission-or-trigger",
    "required-for-policy-change",
}
OWNER_GATE_POLICIES = {
    "none",
    "required-for-public-media-release",
    "required-for-final-license-signing-or-publication",
}
FORBIDDEN_COMMAND_CHARACTERS = set(";&|$`<>\n\r\t\\\"'")


@dataclass(frozen=True)
class StewardshipFailure(Exception):
    code: str
    message: str
    recovery_action: str


def fail(code: str, message: str, recovery_action: str) -> NoReturn:
    raise StewardshipFailure(code, message, recovery_action)


def receipt(
    *,
    status: str,
    mode: str,
    code: str | None,
    message: str,
    recovery_action: str | None,
    policy: dict[str, object] | None = None,
    path_count: int = 0,
    routed_modules: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    roles = policy.get("roles", []) if policy else []
    checks = policy.get("checks", []) if policy else []
    modules = policy.get("modules", []) if policy else []
    result: dict[str, object] = {
        "schemaVersion": SCHEMA_NAME,
        "status": status,
        "mode": mode,
        "networkRequired": False,
        "releaseState": RELEASE_STATE,
        "identityMode": IDENTITY_MODE,
        "policyVersion": policy.get("policyVersion") if policy else None,
        "pathCount": path_count,
        "moduleCount": len(modules),
        "roleCount": len(roles),
        "checkCount": len(checks),
        "unassignedRoleCount": sum(
            isinstance(item, dict)
            and item.get("assignmentState")
            == "unassigned-until-canonical-github-organization"
            for item in roles
        ),
        "code": code,
        "message": message,
        "recoveryAction": recovery_action,
    }
    if status == "PASS" and mode == "route" and routed_modules is not None:
        role_ids = sorted(
            {
                role
                for module in routed_modules
                for role in module["reviewRoles"]
            }
        )
        check_ids = sorted(
            {
                check
                for module in routed_modules
                for check in module["requiredChecks"]
            }
        )
        check_map = {item["id"]: item for item in checks}
        result.update(
            {
                "moduleIDs": sorted({module["id"] for module in routed_modules}),
                "reviewRoles": role_ids,
                "requiredChecks": [
                    {"id": identifier, "command": check_map[identifier]["command"]}
                    for identifier in check_ids
                ],
                "riskClasses": sorted(
                    {
                        risk
                        for module in routed_modules
                        for risk in module["riskClasses"]
                    }
                ),
                "rfcPolicies": sorted(
                    {module["rfcPolicy"] for module in routed_modules}
                ),
                "ownerGatePolicies": sorted(
                    {module["ownerGatePolicy"] for module in routed_modules}
                ),
            }
        )
    return result


def emit(data: dict[str, object], json_mode: bool) -> int:
    if json_mode:
        print(json.dumps(data, ensure_ascii=False, sort_keys=True))
    elif data["status"] == "PASS":
        if data["mode"] == "route":
            print(
                "Module stewardship route: PASS "
                f"({data['pathCount']} paths, {len(data['moduleIDs'])} modules)"
            )
            print("Review roles: " + ", ".join(data["reviewRoles"]))
            print("Required checks:")
            for item in data["requiredChecks"]:
                print(f"- {item['id']}: {item['command']}")
        else:
            print(
                "Module stewardship audit: PASS "
                f"({data['moduleCount']} modules, {data['roleCount']} roles, "
                f"{data['checkCount']} checks)"
            )
        print(f"Release state: {RELEASE_STATE}")
    else:
        print(f"FAIL  [{data['code']}] {data['message']}", file=sys.stderr)
        print(f"ACTION  {data['recoveryAction']}", file=sys.stderr)
    return 0 if data["status"] == "PASS" else 1


def exact_fields(value: object, expected: set[str], label: str) -> dict[str, object]:
    if not isinstance(value, dict):
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            f"{label} must be a JSON object.",
            "Restore the documented module-stewardship v1 structure and rerun the audit.",
        )
    unknown = sorted(set(value) - expected)
    missing = sorted(expected - set(value))
    if unknown:
        fail(
            "STEWARDSHIP_UNKNOWN_FIELD",
            f"{label} contains one or more unsupported fields.",
            "Remove unknown fields or publish a new reviewed schema version.",
        )
    if missing:
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            f"{label} is missing required fields: {', '.join(missing)}.",
            "Add every required v1 field and rerun the audit.",
        )
    return value


def identifier(value: object, label: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) > 96
        or ID_PATTERN.fullmatch(value) is None
    ):
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            f"{label} is not a stable lowercase identifier.",
            "Use a bounded lowercase hyphenated identifier and rerun the audit.",
        )
    return value


def short_text(value: object, label: str) -> str:
    if (
        not isinstance(value, str)
        or not value.strip()
        or len(value) > 240
        or any(ord(character) < 32 for character in value)
    ):
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            f"{label} must be bounded plain text.",
            "Replace the invalid metadata with concise printable text.",
        )
    return value


def string_list(
    value: object,
    label: str,
    *,
    minimum: int,
    maximum: int,
) -> list[str]:
    if (
        not isinstance(value, list)
        or not minimum <= len(value) <= maximum
        or not all(isinstance(item, str) for item in value)
    ):
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            f"{label} must contain between {minimum} and {maximum} strings.",
            "Correct the bounded stewardship list and rerun the audit.",
        )
    if len(value) != len(set(value)):
        fail(
            "STEWARDSHIP_DUPLICATE_ID",
            f"{label} contains duplicate values.",
            "Remove duplicate declarations and rerun the audit.",
        )
    return value


def safe_relative_path(value: object, label: str) -> str:
    if (
        not isinstance(value, str)
        or not value
        or len(value) > 256
        or value.startswith(("/", "~"))
        or value.endswith("/")
        or "//" in value
        or "\\" in value
        or "\x00" in value
    ):
        fail(
            "STEWARDSHIP_UNSAFE_PATH",
            f"{label} is not a safe repository-relative path.",
            "Use a normalized repository-relative path with no private or traversal syntax.",
        )
    parts = pathlib.PurePosixPath(value).parts
    if not parts or any(part in {"", ".", ".."} for part in parts):
        fail(
            "STEWARDSHIP_UNSAFE_PATH",
            f"{label} contains traversal or ambiguous components.",
            "Remove dot and traversal components, then rerun the audit.",
        )
    return value


def validate_command(value: object) -> str:
    if (
        not isinstance(value, str)
        or not value
        or len(value) > 256
        or any(character in FORBIDDEN_COMMAND_CHARACTERS for character in value)
        or "  " in value
    ):
        fail(
            "STEWARDSHIP_COMMAND_UNSAFE",
            "A declared check command contains unsupported shell syntax.",
            "Use one reviewed, argument-only local command without redirection or shell operators.",
        )
    try:
        tokens = shlex.split(value, posix=True)
    except ValueError:
        tokens = []
    if not tokens or " ".join(tokens) != value:
        fail(
            "STEWARDSHIP_COMMAND_UNSAFE",
            "A declared check command is not in canonical argument-only form.",
            "Use single spaces and unquoted local arguments, then rerun the audit.",
        )
    if any(
        token.startswith(("/", "~"))
        or ".." in pathlib.PurePosixPath(token).parts
        for token in tokens
    ):
        fail(
            "STEWARDSHIP_COMMAND_UNSAFE",
            "A declared check command uses an unsafe path.",
            "Use repository-relative tools and arguments only.",
        )
    allowed = False
    if tokens[0].startswith("./scripts/") and tokens[0].endswith(".sh"):
        allowed = True
    elif (
        len(tokens) >= 2
        and tokens[0] == "python3"
        and tokens[1].startswith("scripts/")
        and tokens[1].endswith(".py")
    ):
        allowed = True
    elif len(tokens) >= 2 and tokens[0] == "swift" and tokens[1] in {"build", "run"}:
        allowed = True
    if not allowed or any(
        re.fullmatch(r"[A-Za-z0-9._/+:-]+", token) is None for token in tokens
    ):
        fail(
            "STEWARDSHIP_COMMAND_UNSAFE",
            "A declared check command is outside the reviewed local command allowlist.",
            "Use a repository script, Python audit, or Swift build/run command without shell syntax.",
        )
    return value


def verify_declared_path(root: pathlib.Path, relative: str, directory: bool) -> None:
    cursor = root
    parts = pathlib.PurePosixPath(relative).parts
    for part in parts:
        cursor = cursor / part
        try:
            metadata = cursor.lstat()
        except OSError:
            fail(
                "STEWARDSHIP_INVALID_METADATA",
                "The policy declares a path that is absent from this checkout.",
                "Restore the declared repository path or update the reviewed stewardship policy.",
            )
        if stat.S_ISLNK(metadata.st_mode):
            fail(
                "STEWARDSHIP_UNSAFE_PATH",
                "A declared stewardship path crosses a symbolic link.",
                "Replace the link with a regular repository path and rerun the audit.",
            )
    metadata = cursor.lstat()
    if directory and not stat.S_ISDIR(metadata.st_mode):
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            "A declared module prefix is not a repository directory.",
            "Correct the prefix or restore the declared directory.",
        )
    if not directory and not stat.S_ISREG(metadata.st_mode):
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            "A declared exact path is not a regular repository file.",
            "Correct the exact path or restore the declared file.",
        )


def load_policy(manifest_path: pathlib.Path, root: pathlib.Path) -> dict[str, object]:
    try:
        root = root.resolve(strict=True)
    except OSError:
        fail(
            "STEWARDSHIP_INVALID_ARGUMENT",
            "The selected repository root is unavailable.",
            "Choose a complete local Chengyin checkout and rerun the audit.",
        )
    if not root.is_dir():
        fail(
            "STEWARDSHIP_INVALID_ARGUMENT",
            "The selected repository root is not a directory.",
            "Choose a complete local Chengyin checkout and rerun the audit.",
        )
    try:
        metadata = manifest_path.lstat()
    except OSError:
        fail(
            "STEWARDSHIP_MANIFEST_MISSING",
            "The module-stewardship manifest is missing or unreadable.",
            "Restore community/module-stewardship.json from a trusted checkout.",
        )
    if not stat.S_ISREG(metadata.st_mode) or stat.S_ISLNK(metadata.st_mode):
        fail(
            "STEWARDSHIP_MANIFEST_MISSING",
            "The module-stewardship manifest must be a regular file, not a link.",
            "Replace the manifest with a reviewed regular JSON file.",
        )
    if metadata.st_size > MAX_MANIFEST_BYTES:
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            "The module-stewardship manifest exceeds its bounded audit size.",
            "Reduce the policy to the documented v1 limits and rerun the audit.",
        )
    try:
        raw = json.loads(manifest_path.read_bytes())
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        fail(
            "STEWARDSHIP_INVALID_JSON",
            "The module-stewardship manifest is not valid UTF-8 JSON.",
            "Correct the JSON document and rerun the audit.",
        )
    policy = exact_fields(raw, TOP_FIELDS, "Stewardship manifest")
    if (
        policy["schemaVersion"] != 1
        or policy["contractID"] != "cc.chengyin.module-stewardship"
        or policy["identityMode"] != IDENTITY_MODE
        or not isinstance(policy["policyVersion"], str)
        or SEMVER_PATTERN.fullmatch(policy["policyVersion"]) is None
    ):
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            "The module-stewardship contract identity or version is invalid.",
            "Restore the documented v1 contract identity, identity mode and semantic version.",
        )

    roles_raw = policy["roles"]
    if not isinstance(roles_raw, list) or not 1 <= len(roles_raw) <= 32:
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            "The stewardship role registry is missing or exceeds its bounded size.",
            "Declare between 1 and 32 role records.",
        )
    role_ids: set[str] = set()
    roles: list[dict[str, object]] = []
    for index, raw_role in enumerate(roles_raw):
        role = exact_fields(raw_role, ROLE_FIELDS, f"Role record {index + 1}")
        role_id = identifier(role["id"], "Role ID")
        if role_id in role_ids:
            fail(
                "STEWARDSHIP_DUPLICATE_ID",
                "The stewardship role registry contains a duplicate ID.",
                "Give every role one unique stable identifier.",
            )
        role_ids.add(role_id)
        short_text(role["title"], "Role title")
        if role["assignmentState"] not in ASSIGNMENT_STATES:
            fail(
                "STEWARDSHIP_INVALID_METADATA",
                "A role assignment state is unsupported.",
                "Use an explicit owner boundary or the canonical-organization pending state.",
            )
        responsibilities = string_list(
            role["responsibilities"], "Role responsibilities", minimum=1, maximum=12
        )
        for item in responsibilities:
            short_text(item, "Role responsibility")
        roles.append(role)

    checks_raw = policy["checks"]
    if not isinstance(checks_raw, list) or not 1 <= len(checks_raw) <= 64:
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            "The stewardship check registry is missing or exceeds its bounded size.",
            "Declare between 1 and 64 local check records.",
        )
    check_ids: set[str] = set()
    checks: list[dict[str, object]] = []
    for index, raw_check in enumerate(checks_raw):
        check = exact_fields(raw_check, CHECK_FIELDS, f"Check record {index + 1}")
        check_id = identifier(check["id"], "Check ID")
        if check_id in check_ids:
            fail(
                "STEWARDSHIP_DUPLICATE_ID",
                "The stewardship check registry contains a duplicate ID.",
                "Give every check one unique stable identifier.",
            )
        check_ids.add(check_id)
        short_text(check["title"], "Check title")
        validate_command(check["command"])
        short_text(check["recoveryAction"], "Check recovery action")
        checks.append(check)

    modules_raw = policy["modules"]
    if not isinstance(modules_raw, list) or not 1 <= len(modules_raw) <= 64:
        fail(
            "STEWARDSHIP_INVALID_METADATA",
            "The module registry is missing or exceeds its bounded size.",
            "Declare between 1 and 64 module records.",
        )
    module_ids: set[str] = set()
    prefix_owners: dict[str, str] = {}
    exact_owners: dict[str, str] = {}
    modules: list[dict[str, object]] = []
    for index, raw_module in enumerate(modules_raw):
        module = exact_fields(raw_module, MODULE_FIELDS, f"Module record {index + 1}")
        module_id = identifier(module["id"], "Module ID")
        if module_id in module_ids:
            fail(
                "STEWARDSHIP_DUPLICATE_ID",
                "The module registry contains a duplicate ID.",
                "Give every module one unique stable identifier.",
            )
        module_ids.add(module_id)
        short_text(module["title"], "Module title")
        prefixes = string_list(
            module["pathPrefixes"], "Module path prefixes", minimum=0, maximum=24
        )
        exact_paths = string_list(
            module["exactPaths"], "Module exact paths", minimum=0, maximum=32
        )
        if not prefixes and not exact_paths:
            fail(
                "STEWARDSHIP_INVALID_METADATA",
                "A module has no path routing declaration.",
                "Add at least one path prefix or exact path.",
            )
        for prefix in prefixes:
            safe_relative_path(prefix, "Module path prefix")
            verify_declared_path(root, prefix, directory=True)
            previous = prefix_owners.get(prefix)
            if previous is not None and previous != module_id:
                fail(
                    "STEWARDSHIP_AMBIGUOUS_ROUTE",
                    "Two modules declare the same path prefix.",
                    "Keep one owner for each prefix or make one prefix more specific.",
                )
            prefix_owners[prefix] = module_id
        for exact_path in exact_paths:
            safe_relative_path(exact_path, "Module exact path")
            verify_declared_path(root, exact_path, directory=False)
            previous = exact_owners.get(exact_path)
            if previous is not None and previous != module_id:
                fail(
                    "STEWARDSHIP_AMBIGUOUS_ROUTE",
                    "Two modules declare the same exact path.",
                    "Keep exactly one module owner for each exact path.",
                )
            exact_owners[exact_path] = module_id
        review_roles = string_list(
            module["reviewRoles"], "Module review roles", minimum=1, maximum=12
        )
        if any(identifier(item, "Review role ID") not in role_ids for item in review_roles):
            fail(
                "STEWARDSHIP_ROLE_UNKNOWN",
                "A module references an unknown review role.",
                "Register the role first or correct the module reviewRoles list.",
            )
        required_checks = string_list(
            module["requiredChecks"], "Module required checks", minimum=1, maximum=24
        )
        if any(identifier(item, "Required check ID") not in check_ids for item in required_checks):
            fail(
                "STEWARDSHIP_CHECK_UNKNOWN",
                "A module references an unknown required check.",
                "Register the check first or correct the module requiredChecks list.",
            )
        risk_classes = string_list(
            module["riskClasses"], "Module risk classes", minimum=1, maximum=12
        )
        if any(item not in RISK_CLASSES for item in risk_classes):
            fail(
                "STEWARDSHIP_INVALID_METADATA",
                "A module declares an unsupported risk class.",
                "Use one of the risk classes documented by the v1 schema.",
            )
        if module["rfcPolicy"] not in RFC_POLICIES:
            fail(
                "STEWARDSHIP_INVALID_METADATA",
                "A module declares an unsupported RFC policy.",
                "Use one of the RFC policies documented by the v1 schema.",
            )
        if module["ownerGatePolicy"] not in OWNER_GATE_POLICIES:
            fail(
                "STEWARDSHIP_INVALID_METADATA",
                "A module declares an unsupported owner-gate policy.",
                "Use one of the owner-gate policies documented by the v1 schema.",
            )
        modules.append(module)

    forbidden = string_list(
        policy["forbiddenPathPrefixes"],
        "Forbidden path prefixes",
        minimum=1,
        maximum=32,
    )
    for item in forbidden:
        safe_relative_path(item, "Forbidden path prefix")
        if item in prefix_owners or item in exact_owners:
            fail(
                "STEWARDSHIP_AMBIGUOUS_ROUTE",
                "A forbidden path is also declared as a contribution route.",
                "Remove the overlap so generated or private paths cannot be routed for review.",
            )

    return {
        **policy,
        "roles": roles,
        "checks": checks,
        "modules": modules,
        "forbiddenPathPrefixes": forbidden,
    }


def path_matches_prefix(path: str, prefix: str) -> bool:
    return path == prefix or path.startswith(prefix + "/")


def route_paths(policy: dict[str, object], raw_paths: list[str]) -> list[dict[str, object]]:
    if not raw_paths or len(raw_paths) > MAX_ROUTE_PATHS:
        fail(
            "STEWARDSHIP_INVALID_ARGUMENT",
            "The route request must contain between 1 and 128 paths.",
            "Provide a bounded set of repository-relative changed paths.",
        )
    normalized: list[str] = []
    for raw_path in raw_paths:
        normalized.append(safe_relative_path(raw_path, "Changed path"))
    if len(normalized) != len(set(normalized)):
        fail(
            "STEWARDSHIP_DUPLICATE_ID",
            "The route request contains duplicate changed paths.",
            "Deduplicate the changed-path list and retry.",
        )
    forbidden = policy["forbiddenPathPrefixes"]
    for path in normalized:
        if any(path_matches_prefix(path, prefix) for prefix in forbidden):
            fail(
                "STEWARDSHIP_PATH_FORBIDDEN",
                "A changed path belongs to a generated, private or non-contributable area.",
                "Remove the forbidden artifact from the contribution and regenerate it locally if needed.",
            )

    selected: dict[str, dict[str, object]] = {}
    modules = policy["modules"]
    for path in normalized:
        candidates: list[tuple[int, dict[str, object]]] = []
        for module in modules:
            for exact_path in module["exactPaths"]:
                if path == exact_path:
                    candidates.append((100_000 + len(exact_path.split("/")), module))
            for prefix in module["pathPrefixes"]:
                if path_matches_prefix(path, prefix):
                    candidates.append((len(prefix.split("/")), module))
        if not candidates:
            fail(
                "STEWARDSHIP_PATH_UNROUTED",
                "A changed path has no reviewed module route.",
                "Add a reviewed module route for the repository area before merging the change.",
            )
        highest = max(score for score, _ in candidates)
        winners = {
            module["id"]: module for score, module in candidates if score == highest
        }
        if len(winners) != 1:
            fail(
                "STEWARDSHIP_AMBIGUOUS_ROUTE",
                "A changed path resolves to more than one equally specific module.",
                "Make one route more specific or remove the duplicate declaration.",
            )
        module = next(iter(winners.values()))
        selected[module["id"]] = module
    return list(selected.values())


def parse_arguments(
    argv: list[str],
) -> tuple[pathlib.Path, pathlib.Path, list[str], bool, bool] | int:
    manifest_path = DEFAULT_MANIFEST
    root = PROJECT_ROOT
    paths: list[str] = []
    stdin_mode = False
    explicit_audit = False
    json_mode = "--json" in argv
    index = 0
    while index < len(argv):
        argument = argv[index]
        if argument == "--json":
            index += 1
        elif argument == "--manifest":
            if index + 1 >= len(argv):
                return emit(
                    receipt(
                        status="FAIL",
                        mode="audit",
                        code="STEWARDSHIP_INVALID_ARGUMENT",
                        message="The manifest option is missing its value.",
                        recovery_action="Provide --manifest followed by one local JSON file.",
                    ),
                    json_mode,
                )
            manifest_path = pathlib.Path(argv[index + 1])
            index += 2
        elif argument == "--root":
            if index + 1 >= len(argv):
                return emit(
                    receipt(
                        status="FAIL",
                        mode="audit",
                        code="STEWARDSHIP_INVALID_ARGUMENT",
                        message="The root option is missing its value.",
                        recovery_action="Provide --root followed by one complete local checkout.",
                    ),
                    json_mode,
                )
            root = pathlib.Path(argv[index + 1])
            index += 2
        elif argument == "--path":
            if index + 1 >= len(argv):
                return emit(
                    receipt(
                        status="FAIL",
                        mode="route",
                        code="STEWARDSHIP_INVALID_ARGUMENT",
                        message="The path option is missing its value.",
                        recovery_action="Provide --path followed by a repository-relative changed path.",
                    ),
                    json_mode,
                )
            paths.append(argv[index + 1])
            index += 2
        elif argument == "--stdin":
            stdin_mode = True
            index += 1
        elif argument == "--audit":
            explicit_audit = True
            index += 1
        elif argument in {"--help", "-h"}:
            print(
                "Usage: python3 scripts/audit-module-stewardship.py "
                "[--audit | --path <relative-path> ... | --stdin] "
                "[--manifest <json>] [--root <checkout>] [--json]"
            )
            return 0
        else:
            return emit(
                receipt(
                    status="FAIL",
                    mode="audit",
                    code="STEWARDSHIP_INVALID_ARGUMENT",
                    message="The stewardship auditor received an unknown option.",
                    recovery_action="Run the command with --help, correct the arguments, then retry.",
                ),
                json_mode,
            )
    if explicit_audit and (paths or stdin_mode):
        return emit(
            receipt(
                status="FAIL",
                mode="audit",
                code="STEWARDSHIP_INVALID_ARGUMENT",
                message="Audit mode cannot be combined with changed-path routing.",
                recovery_action="Choose --audit or provide changed paths, but not both.",
            ),
            json_mode,
        )
    return manifest_path, root, paths, stdin_mode, json_mode


def main(argv: list[str]) -> int:
    parsed = parse_arguments(argv)
    if isinstance(parsed, int):
        return parsed
    manifest_path, root, paths, stdin_mode, json_mode = parsed
    if stdin_mode:
        payload = sys.stdin.buffer.read(MAX_STDIN_BYTES + 1)
        if len(payload) > MAX_STDIN_BYTES:
            return emit(
                receipt(
                    status="FAIL",
                    mode="route",
                    code="STEWARDSHIP_INVALID_ARGUMENT",
                    message="The changed-path input exceeds its bounded size.",
                    recovery_action="Provide at most 128 short repository-relative paths.",
                ),
                json_mode,
            )
        try:
            paths.extend(line for line in payload.decode("utf-8").splitlines() if line)
        except UnicodeDecodeError:
            return emit(
                receipt(
                    status="FAIL",
                    mode="route",
                    code="STEWARDSHIP_INVALID_ARGUMENT",
                    message="The changed-path input is not valid UTF-8 text.",
                    recovery_action="Provide one UTF-8 repository-relative path per line.",
                ),
                json_mode,
            )
    mode = "route" if paths else "audit"
    try:
        policy = load_policy(manifest_path, root)
        routed = route_paths(policy, paths) if paths else None
        return emit(
            receipt(
                status="PASS",
                mode=mode,
                code=None,
                message=(
                    "The changed paths have a deterministic stewardship route."
                    if paths
                    else "The module stewardship policy is internally consistent."
                ),
                recovery_action=None,
                policy=policy,
                path_count=len(paths),
                routed_modules=routed,
            ),
            json_mode,
        )
    except StewardshipFailure as error:
        return emit(
            receipt(
                status="FAIL",
                mode=mode,
                code=error.code,
                message=error.message,
                recovery_action=error.recovery_action,
                path_count=len(paths),
            ),
            json_mode,
        )
    except Exception:
        return emit(
            receipt(
                status="FAIL",
                mode=mode,
                code="STEWARDSHIP_UNEXPECTED_ERROR",
                message="The stewardship audit stopped at a privacy-safe fallback boundary.",
                recovery_action="Retry once; if it repeats, validate the manifest JSON and local checkout separately.",
                path_count=len(paths),
            ),
            json_mode,
        )


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
