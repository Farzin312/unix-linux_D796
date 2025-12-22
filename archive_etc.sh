#!/usr/bin/env bash

# a1: Create compressed archives of `/etc` using gzip and bzip2, then compare the file sizes.
set -euo pipefail  # a2: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() {
    echo "Error: $*" >&2
    exit 1
}

# f2: require_cmd — Verify a command exists on PATH before running the script.
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# f3: ensure_root_or_sudo — Re-exec the script under sudo when not running as root.
ensure_root_or_sudo() {
    if [[ "${EUID}" -ne 0 ]]; then
        exec sudo -- "$0" "$@"
    fi
}

# f4: fileSize — Return a file size in bytes (Linux stat or macOS stat fallback).
fileSize() {
    local file="$1"
    [[ -f "$file" ]] || err "File not found: $file"

    if stat -c%s "$file" >/dev/null 2>&1; then
        stat -c%s "$file"
    else
        stat -f%z "$file"
    fi
}

# a3: Validate required tooling exists before attempting archive creation.
require_cmd tar
require_cmd gzip
require_cmd bzip2
require_cmd stat

# a4: Ensure permissions allow reading `/etc` contents during archiving.
ensure_root_or_sudo "$@"

# a5: Generate timestamped archive names to avoid collisions across runs.
timestamp="$(date +%Y%m%d_%H%M%S)"
gzip_archive="etc_backup_${timestamp}.tar.gz"
bzip_archive="etc_backup_${timestamp}.tar.bz2"

# a6: Create the gzip and bzip2 tar archives of `/etc`.
tar -czf "$gzip_archive" /etc
tar -cjf "$bzip_archive" /etc

# a7: Compute resulting archive sizes for a direct comparison.
gzip_size="$(fileSize "$gzip_archive")"
bzip_size="$(fileSize "$bzip_archive")"

echo "gzip size: ${gzip_size} bytes"
echo "bzip2 size: ${bzip_size} bytes"

# a8: Compare sizes and print which compression produced a smaller result.
if ((gzip_size > bzip_size)); then
    diff=$((gzip_size - bzip_size))
    echo "bzip2 is smaller by ${diff} bytes."
elif ((bzip_size > gzip_size)); then
    diff=$((bzip_size - gzip_size))
    echo "gzip is smaller by ${diff} bytes."
else
    echo "Both archives are the same size."
fi
