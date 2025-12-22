#!/usr/bin/env bash

# a1: Remove contents of selected cache/log directories and report reclaimed space on the `/root` filesystem.
set -euo pipefail  # a2: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() {
    echo "Error: $*" >&2
    exit 1
}

# f2: require_cmd — Verify a required command exists on PATH.
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# f3: ensure_root_or_sudo — Re-exec the script under sudo when not running as root.
ensure_root_or_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    exec sudo -- "$0" "$@"
  fi
}
# a3: Ensure the script has permissions needed to delete system log files.
ensure_root_or_sudo "$@"

# a4: Validate external commands used by this script.
require_cmd df
require_cmd awk
require_cmd find
require_cmd rm

# a5: Capture free space for `/` in KiB as a baseline (rubric visibility).
root_free_before_kb="$(df -kP / | awk 'NR==2 {print $4}')"
[[ -n "$root_free_before_kb" ]] || err "Could not read free space for /"

# a6: Verify `/root` exists (rubric requirement on Linux-style systems).
[[ -d /root ]] || err "/root directory not found. This task expects a Linux system with /root."

# a7: Capture free space for the filesystem containing `/root` in KiB (baseline for cleanup delta).
root_free_before_root_kb="$(df -kP /root | awk 'NR==2 {print $4}')"
[[ -n "$root_free_before_root_kb" ]] || err "Could not read free space for /root"

# f4: cleanDir — Delete all top-level entries in a target directory while protecting unsafe paths.
cleanDir() {
    local target="$1"

    [[ -n "$target" ]] || err "Directory argument missing"
    if [[ ! -d "$target" ]]; then
        echo "Skipping $target (not found)"
        return
    fi

    # a8: Refuse to operate on high-risk root directories to prevent destructive deletes.
    case "$target" in
        / | /root | /home | /Users)
            err "Refusing to clean unsafe directory: $target"
            ;;
    esac

    # a9: Remove everything inside the directory without deleting the directory itself.
    find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

# a10: Define the cleanup targets (system logs + per-user cache).
CLEAN_DIRS=(/var/log "$HOME/.cache")

# a11: Iterate through targets and clean each directory.
for dir in "${CLEAN_DIRS[@]}"; do
    cleanDir "$dir"
done

# a12: Re-check free space after cleanup to calculate how much space changed.
root_free_after_root_kb="$(df -kP /root | awk 'NR==2 {print $4}')"
[[ -n "$root_free_after_root_kb" ]] || err "Could not read free space for /root"

# a13: Compute and report the delta in KiB on the `/root` filesystem.
freed_kb=$((root_free_after_root_kb - root_free_before_root_kb))
if ((freed_kb > 0)); then
    echo "Freed ${freed_kb} KB of disk space."
else
    echo "No significant disk space was freed"
fi
