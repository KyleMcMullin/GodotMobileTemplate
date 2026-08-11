#!/usr/bin/env bash
#
# Runs the project's gdUnit4 suite headlessly. Used both locally and by CI, so a
# green run on your machine means the same thing as a green run on a runner.
#
# Usage:
#   ./run_tests.sh                      # whole suite
#   ./run_tests.sh res://tests/unit     # a subset
#   PROJECT_PATH=Game/hue-blend ./run_tests.sh
#
# Godot is found via $GODOT_BIN, then `godot` on PATH, then the standard macOS
# app bundle location.
#
# Canonical copy: https://github.com/KyleMcMullin/godot-ci/blob/main/scripts/run_tests.sh
# This is a local-dev tool, so it has to live in the repo rather than being pulled
# from the shared workflow. Re-copy it from godot-ci if it drifts.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- locate the Godot project ------------------------------------------------
if [ -n "${PROJECT_PATH:-}" ]; then
	PROJECT_DIR="$REPO_ROOT/$PROJECT_PATH"
elif [ -f "$REPO_ROOT/project.godot" ]; then
	PROJECT_DIR="$REPO_ROOT"
else
	# Single unambiguous project.godot below the repo root, ignoring build output.
	FOUND="$(find "$REPO_ROOT" -name project.godot -maxdepth 3 \
		-not -path '*/android/*' -not -path '*/build/*' 2>/dev/null)"
	COUNT="$(printf '%s\n' "$FOUND" | grep -c . || true)"
	if [ "$COUNT" -ne 1 ]; then
		echo "Could not determine the project directory ($COUNT candidates)." >&2
		echo "Set PROJECT_PATH, e.g. PROJECT_PATH=Game/hue-blend $0" >&2
		exit 1
	fi
	PROJECT_DIR="$(dirname "$FOUND")"
fi

if [ ! -f "$PROJECT_DIR/project.godot" ]; then
	echo "No project.godot in $PROJECT_DIR" >&2
	exit 1
fi

# --- locate Godot ------------------------------------------------------------
if [ -n "${GODOT_BIN:-}" ]; then
	GODOT="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
	GODOT="$(command -v godot)"
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
	GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
else
	echo "Godot not found. Set GODOT_BIN=/path/to/godot" >&2
	exit 1
fi

# Skips rather than fails: a project that has not adopted gdUnit4 yet should not
# have a red build. Install the addon and this starts running with no other change.
if [ ! -d "$PROJECT_DIR/addons/gdUnit4" ]; then
	echo "gdUnit4 is not installed in $PROJECT_DIR/addons/gdUnit4 - skipping tests."
	echo "To add it: Godot > AssetLib > search 'gdUnit4', or https://github.com/MikeSchulze/gdUnit4"
	exit 0
fi

echo "Godot:   $("$GODOT" --version)"
echo "Project: $PROJECT_DIR"

# --- work out where user:// lands --------------------------------------------
# Autoloads read and write real save data, and analytics addons fire real requests.
# Both would otherwise leak out of a test run and pollute your actual game state, so
# the run happens against a throwaway user:// directory that is restored afterwards.
cfg_value() { grep -m1 "^$1=" "$PROJECT_DIR/project.godot" | cut -d= -f2- | tr -d '"'; }

USE_CUSTOM="$(cfg_value 'config/use_custom_user_dir')"
CUSTOM_DIR="$(cfg_value 'config/custom_user_dir_name')"
PROJECT_NAME="$(cfg_value 'config/name')"

case "$(uname -s)" in
	Darwin) DATA_HOME="$HOME/Library/Application Support" ;;
	*)      DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}" ;;
esac

if [ "$USE_CUSTOM" = "true" ] && [ -n "$CUSTOM_DIR" ]; then
	USER_DIR="$DATA_HOME/$CUSTOM_DIR"
else
	USER_DIR="$DATA_HOME/Godot/app_userdata/$PROJECT_NAME"
fi

BACKUP_DIR="${USER_DIR}.testbackup.$$"
RESTORED=0

restore_user_dir() {
	[ "$RESTORED" -eq 1 ] && return
	RESTORED=1
	rm -rf "$USER_DIR"
	if [ -d "$BACKUP_DIR" ]; then
		mv "$BACKUP_DIR" "$USER_DIR"
		echo "Restored original user:// data."
	fi
}
trap restore_user_dir EXIT INT TERM

if [ -d "$USER_DIR" ]; then
	mv "$USER_DIR" "$BACKUP_DIR"
	echo "Stashed existing user:// data."
fi
mkdir -p "$USER_DIR"

# PostHog reads this before any test runs and bails out early when it is false, so
# no analytics request is ever constructed. Harmless if the addon is not present.
if [ -f "$PROJECT_DIR/posthog.json" ]; then
	cat > "$USER_DIR/user_config.cfg" <<'CFG'
[analytics]

PostHog=false
CFG
fi

# --- make sure class_name globals are registered -----------------------------
# gdUnit4's own class_names live in .godot/global_script_class_cache.cfg. A fresh
# checkout (or a newly added addon) has no cache, and the CLI tool then fails to
# parse with "Could not find type GdUnitTestCIRunner".
if [ ! -f "$PROJECT_DIR/.godot/global_script_class_cache.cfg" ]; then
	echo "Importing project (first run, building class cache)..."
	"$GODOT" --headless --path "$PROJECT_DIR" --import --quit-after 100 >/dev/null 2>&1
fi

# --- run ---------------------------------------------------------------------
TARGETS=("$@")
if [ ${#TARGETS[@]} -eq 0 ]; then
	if [ -d "$PROJECT_DIR/tests" ]; then
		TARGETS=("res://tests")
	elif [ -d "$PROJECT_DIR/test" ]; then
		TARGETS=("res://test")
	else
		echo "No tests/ or test/ directory in $PROJECT_DIR - nothing to run."
		exit 0
	fi
fi

ADD_ARGS=()
for t in "${TARGETS[@]}"; do
	ADD_ARGS+=(--add "$t")
done

# -s runs GdUnitCmdTool as the main script. Autoloads are still registered by the
# time test suites load, so game singletons resolve normally.
# --ignoreHeadlessMode is required: gdUnit4 refuses to start headless otherwise.
# --remote-debug on a closed port stops Godot dropping into its interactive
# "debug>" prompt on a parse error, which would hang CI forever.
"$GODOT" --path "$PROJECT_DIR" --headless \
	-s -d --remote-debug tcp://127.0.0.1:65534 \
	res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
	--ignoreHeadlessMode \
	"${ADD_ARGS[@]}"
EXIT_CODE=$?

restore_user_dir
echo "Test run finished with exit code $EXIT_CODE"
exit $EXIT_CODE
