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

fileSize() {
    local file="$1"
    [[ -f "$file" ]] || err "File not found: $file"

    if stat -c%s "$file" >/dev/null 2>&1; then
        stat -c%s "$file"
    else
        stat -f%z "$file"
    fi
}

require_cmd tar
require_cmd gzip
require_cmd bzip2
require_cmd stat

ensure_root_or_sudo "$@"

timestamp="$(date +%Y%m%d_%H%M%S)"
gzip_archive="etc_backup_${timestamp}.tar.gz"
bzip_archive="etc_backup_${timestamp}.tar.bz2"

tar -czf "$gzip_archive" /etc
tar -cjf "$bzip_archive" /etc

gzip_size="$(fileSize "$gzip_archive")"
bzip_size="$(fileSize "$bzip_archive")"

echo "gzip size: ${gzip_size} bytes"
echo "bzip2 size: ${bzip_size} bytes"

if ((gzip_size > bzip_size)); then
    diff=$((gzip_size - bzip_size))
    echo "bzip2 is smaller by ${diff} bytes."
elif ((bzip_size > gzip_size)); then
    diff=$((bzip_size - gzip_size))
    echo "gzip is smaller by ${diff} bytes."
else
    echo "Both archives are the same size."
fi
