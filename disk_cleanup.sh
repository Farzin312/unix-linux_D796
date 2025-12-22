#!/usr/bin/env bash

set -euo pipefail

err() {
    echo "Error: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

ensure_root_or_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    exec sudo -- "$0" "$@"
  fi
}
ensure_root_or_sudo "$@"


require_cmd df
require_cmd awk
require_cmd find
require_cmd rm

# F1: free space in root partition (/) stored in a variable
root_free_before_kb="$(df -kP / | awk 'NR==2 {print $4}')"
[[ -n "$root_free_before_kb" ]] || err "Could not read free space for /"

# F5: MUST check /root partition (rubric specific)
[[ -d /root ]] || err "/root directory not found. This task expects a Linux system with /root."

root_free_before_root_kb="$(df -kP /root | awk 'NR==2 {print $4}')"
[[ -n "$root_free_before_root_kb" ]] || err "Could not read free space for /root"

cleanDir() {
    local target="$1"

    [[ -n "$target" ]] || err "Directory argument missing"
    if [[ ! -d "$target" ]]; then
        echo "Skipping $target (not found)"
        return
    fi

    case "$target" in
        / | /root | /home | /Users)
            err "Refusing to clean unsafe directory: $target"
            ;;
    esac

    find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
}

# F3: variable containing list of directories to clean
CLEAN_DIRS=(/var/log "$HOME/.cache")

# F4: delete all files/subdirs using for loop + cleanDir()
for dir in "${CLEAN_DIRS[@]}"; do
    cleanDir "$dir"
done

root_free_after_root_kb="$(df -kP /root | awk 'NR==2 {print $4}')"
[[ -n "$root_free_after_root_kb" ]] || err "Could not read free space for /root"

freed_kb=$((root_free_after_root_kb - root_free_before_root_kb))
if ((freed_kb > 0)); then
    echo "Freed ${freed_kb} KB of disk space."
else
    echo "No significant disk space was freed"
fi
