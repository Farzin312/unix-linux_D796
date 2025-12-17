#!/usr/bin/env bash

# Use strict mode by default so errors are visible during the demo.
# This script temporarily disables `-e` around an intentional failure.
set -euo pipefail

echo "Demo: create_user.sh requirements"
echo

echo "1) Run script without arguments (should error):"
# Allow the next command to fail without exiting this demo script.
set +e
./create_user.sh
status=$?
# Re-enable "exit on error" for the rest of the demo.
set -e
echo "Exit status: $status"
echo

# Allow passing a username as $1; otherwise generate one using the current epoch seconds.
# ${1:-} expands to $1 if set, otherwise empty string.
demo_username="${1:-}"
if [[ -z "$demo_username" ]]; then
    demo_username="demo_user_$(date +%s)"
fi

echo "2) Run script with valid arguments (username):"
echo "   Username: $demo_username"
echo "   You will be prompted to enter an initial password."
echo
# This will likely prompt for sudo (if you're not root) and then prompt for a password.
./create_user.sh "$demo_username"
echo

echo "3) Switch to the new user (uses the password you set) and you should be forced to change it:"
echo "   su - $demo_username"
echo
echo "If your system uses sudo instead of su, you can also try:"
echo "   sudo -i -u $demo_username"
