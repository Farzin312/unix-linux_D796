#!/usr/bin/env bash

# a1: Network connectivity check via a single ICMP ping to a hostname.
set -euo pipefail  # a2: Fail fast on errors, unset variables, and pipeline failures.

# a3: Verify the required command exists before running the check.
command -v ping >/dev/null 2>&1 || { echo "Error: ping not found" >&2; exit 1; }

# a4: Send exactly one ping to keep the check quick; success implies DNS + network reachability.
if ping -c 1 google.com >/dev/null 2>&1; then
    echo "Network is up."
else
    echo "Network is down."
    exit 1
fi
