#!/usr/bin/env bash
# Linux/macOS counterpart of validate.ps1; needs Python 3.10+ and Godot.
set -euo pipefail
script_dir="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
framework_root="$(cd -- "$script_dir/../../.." && pwd)"
exec "${PYTHON:-python3}" - "$framework_root" "$@" <<'PY'
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile


FRAMEWORK = Path(sys.argv.pop(1))
EXPECTED_SAVE_ERROR = (
    r"(?m)^ERROR: ConfigFile parse error at user://saves_test_backups_\d+/"
    r"[a-z0-9_]+/unreadable\.cfg:0: Unexpected EOF while parsing simple tag\.\r?$"
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate Tifo Beato in an isolated symlink project/profile.",
    )
    parser.add_argument("--godot", default=os.environ.get("GODOT") or "godot")
    parser.add_argument("--suites", nargs="+", default=["sound", "model", "scene"])
    parser.add_argument("--framework", action="store_true")
    parser.add_argument("--window", action="store_true")
    parser.add_argument("--timeout-seconds", type=int, default=180)
    args = parser.parse_args()
    suites = [
        item.strip()
        for value in args.suites for item in value.split(",") if item.strip()
    ]
    if not suites or any(re.fullmatch(r"\w+", suite) is None for suite in suites):
        parser.error("--suites requires simple test names, such as sound,model,scene")
    if args.timeout_seconds <= 0:
        parser.error("--timeout-seconds must be positive")
    godot = shutil.which(os.path.expanduser(args.godot))
    if godot is None:
        raise FileNotFoundError(f"Cannot run '{args.godot}'; pass --godot PATH.")

    workspace = Path(tempfile.mkdtemp(prefix="tifo_beato_validation_"))
    logs = workspace / "logs"
    logs.mkdir()
    profile = workspace / "user-data"
    profile.mkdir()
    environment = os.environ.copy()
    environment.update(
        HOME=str(profile), APPDATA=str(profile), XDG_DATA_HOME=str(profile),
    )
    print(f"Validation artifacts: {workspace}", flush=True)
    for folder in (
        "assets", "autoload", "games", "scenes", "scripts", "tests",
        "third_party", "tools", "ui",
    ):
        (workspace / folder).symlink_to(
            FRAMEWORK / folder, target_is_directory=True,
        )
    for name in ("default_bus_layout.tres", "icon.svg", "export_presets.cfg"):
        shutil.copy2(FRAMEWORK / name, workspace / name)
    project = (FRAMEWORK / "project.godot").read_text()
    project = project.replace(
        'config/custom_user_dir_name="DeskCanSaw Games/DCS Base Game"',
        f'config/custom_user_dir_name="DeskCanSaw Games/Tifo Validation '
        f'{workspace.name.removeprefix("tifo_beato_validation_")}"',
    )
    project_path = workspace / "project.godot"
    project_path.write_text(project.replace(
        'theme/custom="res://ui/theme/dcs_theme.tres"', 'theme/custom=""',
    ))
    results = []

    def check(name: str, arguments: list[str]) -> bool:
        stdout_path = logs / f"{name}.stdout.log"
        stderr_path = logs / f"{name}.stderr.log"
        with stdout_path.open("w") as stdout, stderr_path.open("w") as stderr:
            process = subprocess.Popen(
                [godot, *arguments], stdout=stdout, stderr=stderr,
                env=environment, start_new_session=True,
            )
            try:
                try:
                    code = process.wait(timeout=args.timeout_seconds)
                except subprocess.TimeoutExpired as error:
                    raise RuntimeError(
                        f"{name} exceeded {args.timeout_seconds} seconds. Logs: {logs}",
                    ) from error
            finally:
                if process.poll() is None:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    process.wait()
        output = stdout_path.read_text() + stderr_path.read_text()
        diagnostics = (
            re.sub(EXPECTED_SAVE_ERROR, "", output)
            if name == "saves_test" else output
        )
        passed = code == 0 and re.search(
            r"(?m)^(SCRIPT ERROR|ERROR):", diagnostics,
        ) is None
        results.append({"Name": name, "ExitCode": code, "Passed": passed})
        print(f"{name}: {'PASS' if passed else 'FAIL'}", flush=True)
        if not passed:
            for line in output.splitlines():
                if re.match(r"^\[\s*\d+%", line) is None:
                    print(line)
        return passed

    path_arguments = ["--path", str(workspace)]
    if not check("import", [
        "--headless", "--editor", "--import", "--quit", *path_arguments,
    ]):
        raise RuntimeError(f"Import failed. Logs: {logs}")
    project_path.write_text(project)
    for suite in suites:
        check(f"tifo_{suite}", [
            "--headless", "--audio-driver", "Dummy", *path_arguments,
            "--script", f"res://games/tifo_beato/tests/{suite}_test.gd",
            "--", "--game=all",
        ])
    if args.framework:
        for test in sorted((FRAMEWORK / "tests").glob("*_test.gd")):
            check(test.stem, [
                "--headless", "--audio-driver", "Dummy", *path_arguments,
                "--script", f"res://tests/{test.name}", "--", "--game=all",
            ])
    if args.window:
        check("curva_view", [
            *path_arguments, "--audio-driver", "Dummy",
            "--script", "res://games/tifo_beato/tests/curva_view_test.gd",
            "--", "--game=all",
        ])
    (logs / "results.json").write_text(json.dumps(results, indent=2) + "\n")
    return 1 if any(not result["Passed"] for result in results) else 0


try:
    sys.exit(main())
except (OSError, RuntimeError) as error:
    print(f"Validation failed: {error}", file=sys.stderr)
    sys.exit(1)
except KeyboardInterrupt:
    print("Validation interrupted.", file=sys.stderr)
    sys.exit(130)
PY
