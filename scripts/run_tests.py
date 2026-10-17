#!/usr/bin/env python3
"""Run against a fresh project copy and disposable user data, never real saves."""
import json
from contextlib import ExitStack
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile


def main():
    repo = Path(__file__).resolve().parents[1]
    project = repo / os.environ.get("PROJECT_PATH", "godot-mobile-template")
    godot = os.environ.get("GODOT_BIN") or shutil.which("godot")
    if not godot and Path("/Applications/Godot.app/Contents/MacOS/Godot").exists():
        godot = "/Applications/Godot.app/Contents/MacOS/Godot"
    if not godot:
        raise RuntimeError("Godot not found. Set GODOT_BIN=/path/to/godot")
    if not (project / "project.godot").is_file():
        raise RuntimeError(f"No project.godot in {project}")

    with tempfile.TemporaryDirectory(prefix="godot-template-tests-") as temporary, ExitStack() as cleanup:
        scratch = Path(temporary).resolve()
        clone = scratch / "project"
        def ignore(directory, names):
            excluded = {".godot", ".git", "reports", ".DS_Store"}
            if Path(directory) == project:
                excluded.update({"android", "build"})
            return excluded.intersection(names)

        shutil.copytree(project, clone, ignore=ignore)
        # Only the copy uses this directory. No real saves are moved or deleted.
        if sys.platform == "darwin":
            data_home = Path.home() / "Library/Application Support"
        elif sys.platform == "win32":
            data_home = Path(os.environ["APPDATA"])
        else:
            data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
        data_home.mkdir(parents=True, exist_ok=True)
        user_dir = Path(cleanup.enter_context(tempfile.TemporaryDirectory(
            prefix="godot-template-user-", dir=data_home))).resolve()
        custom_dir = user_dir.name
        (clone / "override.cfg").write_text(
            '[application]\nconfig/use_custom_user_dir=true\n'
            f'config/custom_user_dir_name={json.dumps(custom_dir)}\n'
        )
        environment = dict(os.environ, TEMPLATE_TEST_USER_DIR=str(user_dir))
        command = [godot, "--headless", "--path", str(clone),
                   "--log-file", str(scratch / "godot.log")]

        def run(arguments, timeout=120):
            result = subprocess.run(command + arguments, env=environment,
                                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, timeout=timeout)
            # Godot can exit 0 on a script/resource error; treat those as failures.
            if result.returncode or re.search(r"(?:SCRIPT ERROR:|ERROR:|FAIL:)", result.stdout):
                print(result.stdout, end="", flush=True)
                raise RuntimeError(f"Godot check failed (exit {result.returncode})")
            print("Fresh editor import passed." if "--editor" in arguments else result.stdout,
                  flush=True)

        run(["--editor", "--import", "--quit"])
        run(["--scene", "res://tests/template_smoke.tscn"])
        if (clone / "addons/gdUnit4").is_dir():
            targets = sys.argv[1:] or ["res://tests/unit"]
            arguments = ["--script", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
                         "--", "--ignoreHeadlessMode"]
            for target in targets:
                arguments += ["--add", target]
            run(arguments, timeout=600)
        elif sys.argv[1:]:
            raise RuntimeError("Subset arguments require gdUnit4; template checks passed")
        print("Template checks passed using a fresh import and disposable user data.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
