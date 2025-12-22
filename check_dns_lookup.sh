#!/usr/bin/env bash

# a1: DNS resolution check using `nslookup` against a known domain.
set -euo pipefail  # a2: Fail fast on errors, unset variables, and pipeline failures.

# a3: Verify the required command exists before running the check.
command -v nslookup >/dev/null 2>&1 || { echo "Error: nslookup not found" >&2; exit 1; }

# a4: Attempt a DNS lookup; exit non-zero when resolution fails.
if nslookup example.com >/dev/null 2>&1; then
    echo "DNS lookup for example.com succeeded."
else
    echo "DNS lookup for example.com failed."
    exit 1
fi
