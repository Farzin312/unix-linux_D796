#!/usr/bin/env bash

# a1: Raw IP connectivity check (no DNS dependency) by pinging a public IP address.
set -euo pipefail  # a2: Fail fast on errors, unset variables, and pipeline failures.

# a3: Verify the required command exists before running the check.
command -v ping >/dev/null 2>&1 || { echo "Error: ping not found" >&2; exit 1; }

# a4: Ping a well-known IP once; success indicates the network path is reachable.
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "Ping to 8.8.8.8 succeeded."
else
    echo "Ping to 8.8.8.8 failed."
    exit 1
fi
