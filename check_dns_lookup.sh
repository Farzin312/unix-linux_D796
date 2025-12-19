#!/usr/bin/env bash

# I use strict mode so any failure is obvious in this DNS check.
set -euo pipefail

command -v nslookup >/dev/null 2>&1 || { echo "Error: nslookup not found" >&2; exit 1; }

# I use nslookup to confirm DNS resolution for example.com.
if nslookup example.com >/dev/null 2>&1; then
    echo "DNS lookup for example.com succeeded."
else
    echo "DNS lookup for example.com failed."
    exit 1
fi
