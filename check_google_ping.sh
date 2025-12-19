#!/usr/bin/env bash

# I use strict mode so any failure is obvious in this connectivity check.
set -euo pipefail

command -v ping >/dev/null 2>&1 || { echo "Error: ping not found" >&2; exit 1; }

# I send a single ping to keep the check quick.
if ping -c 1 google.com >/dev/null 2>&1; then
    echo "Network is up."
else
    echo "Network is down."
    exit 1
fi
