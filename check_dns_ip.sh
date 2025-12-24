#!/usr/bin/env bash

# a1: Check connectivity to Google DNS IP (8.8.8.8) using ping.
set -euo pipefail  # a2: Fail fast on errors, unset variables, and pipeline failures.

# a3: Verify the required command exists before running the check.
command -v ping >/dev/null 2>&1 || { echo "Error: ping not found" >&2; exit 1; }

# a4: Send exactly one ping to keep the check quick.
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
  echo "Google DNS IP is reachable."
else
  echo "Google DNS IP is unreachable."
  exit 1
fi
