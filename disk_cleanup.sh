#!/usr/bin/env bash

# I use strict mode so cleanup stops if something unexpected happens.
set -euo pipefail

err() {
    echo "Error: $*" >&2
    exit 1
}

require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

require_cmd df
require_cmd awk
require_cmd find
require_cmd rm

# I capture free space in the root partition (/) before cleanup.
root_free_before_kb="$(df -kP / | awk 'NR==2 {print $4}')"
[[ -n "$root_free_before_kb" ]] || err "Could not read free space for /"

# I choose /root for the post-cleanup check when it exists; otherwise I fall back to /.
root_partition="/root"
if [[ ! -d "$root_partition" ]]; then
    echo "Note: /root does not exist on this system; using / for the /root check."
    root_partition="/"
fi

# I capture free space in the /root partition (or fallback) before cleanup.
root_free_before_root_kb="$(df -kP "$root_partition" | awk 'NR==2 {print $4}')"
[[ -n "$root_free_before_root_kb" ]] || err "Could not read free space for $root_partition"

# cleanDir deletes the contents of the directory passed as $1.
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

    # I remove the contents but keep the directory itself.
    # I use sudo for system directories if I'm not root.
    if [[ "${EUID}" -ne 0 && "$target" == /var/* ]]; then
        require_cmd sudo
        sudo find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    else
        find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +
    fi
}

# List of directories to clean.
CLEAN_DIRS=(/var/log "$HOME/.cache")

# I loop through the list and clean each directory.
for dir in "${CLEAN_DIRS[@]}"; do
    cleanDir "$dir"
done

# I capture free space in the /root partition (or fallback) after cleanup.
root_free_after_root_kb="$(df -kP "$root_partition" | awk 'NR==2 {print $4}')"
[[ -n "$root_free_after_root_kb" ]] || err "Could not read free space for $root_partition"

freed_kb=$((root_free_after_root_kb - root_free_before_root_kb))
if ((freed_kb > 0)); then
    echo "Freed ${freed_kb} KB of disk space."
else
    echo "No significant disk space was freed"
fi
