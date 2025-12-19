#!/usr/bin/env bash

# Use strict mode by default so errors are visible during the demo.
# This script temporarily disables `-e` around an intentional failure.
set -euo pipefail

# I resolve the repo root so I can find the local bin directory reliably.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_BIN="${SCRIPT_DIR}/bin"

# Ensure create_user.sh is on PATH, preferring the repo's bin directory.
if ! command -v create_user.sh >/dev/null 2>&1; then
    if [[ -x "${PROJECT_BIN}/create_user.sh" ]]; then
        PATH="${PROJECT_BIN}:$PATH"
    elif [[ -d "$HOME/bin" ]]; then
        PATH="$HOME/bin:$PATH"
    fi
fi

echo "Demo: create_user.sh requirements"
echo "Detected OS: $(uname -s)"
echo

echo "1) Run script without arguments (should error):"
# Allow the next command to fail without exiting this demo script.
set +e
create_user.sh
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
echo "   Note: On macOS, the user may not appear in /etc/passwd; create_user.sh also prints dscl/id output."
echo
# This will likely prompt for sudo (if you're not root) and then prompt for a password.
create_user.sh "$demo_username"
echo

if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "3) Switch to the new user:"
    echo "   sudo -iu $demo_username whoami"
    echo "   sudo -iu $demo_username id"
    echo "   (runs a command as the user, then returns to your shell)"
    echo
    echo "macOS note about \"force password change\":"
    # Use single quotes so backticks are printed literally (not treated as command substitution).
    echo ' - If create_user.sh sets pwpolicy newPasswordRequired=1, Terminal `login`/`su` may reject with "Login incorrect".'
    echo " - To see the forced-change behavior, log out (or use Fast User Switching) and sign in as $demo_username."
else
    echo "3) Switch to the new user (uses the password you set) and you should be forced to change it:"
    echo "   su - $demo_username"
    echo
    echo "If your system uses sudo instead of su, you can also try:"
    echo "   sudo -iu $demo_username whoami"
    echo "   sudo -iu $demo_username id"
    echo
    echo "Note: If you open an interactive shell with:"
    echo "   sudo -iu $demo_username"
    echo 'type `exit` to return to your original terminal session.'
fi
