#!/usr/bin/env bash

# I use strict mode so any failure is obvious in this connectivity check.
set -euo pipefail

command -v ping >/dev/null 2>&1 || { echo "Error: ping not found" >&2; exit 1; }

# I ping the Google DNS IP to confirm raw IP connectivity.
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "Ping to 8.8.8.8 succeeded."
else
    echo "Ping to 8.8.8.8 failed."
    exit 1
fi
