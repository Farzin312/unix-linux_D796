#!/usr/bin/env bash

# Use strict mode by default so errors are visible during the demo.
# This script temporarily disables `-e` around intentional failures.
set -euo pipefail

echo "Demo: delete_user.sh requirements"
echo "Detected OS: $(uname -s)"
echo

echo "1) Run script without arguments (should error):"
# Allow the next command to fail without exiting this demo script.
set +e
./delete_user.sh
status=$?
# Re-enable \"exit on error\" for the rest of the demo.
set -e
echo "Exit status: $status"
echo

# Allow passing a username as $1; otherwise generate one using the current epoch seconds.
# ${1:-} expands to $1 if set, otherwise empty string.
demo_username="${1:-}"
if [[ -z "$demo_username" ]]; then
    demo_username="demo_user_$(date +%s)"
    echo "No username provided. Creating a temporary user to delete: $demo_username"
    echo "You will be prompted for a password to create the user."
    echo
    ./create_user.sh "$demo_username"
    echo
fi

# If a username was provided, verify it exists before attempting deletion.
if ! id -u "$demo_username" >/dev/null 2>&1; then
    echo "User $demo_username does not exist."
    echo "Create it with create_user.sh before running this demo, or rerun with a valid username."
    exit 1
fi

echo "2) Run script with valid arguments (username):"
echo "   Username: $demo_username"
echo "   You will be prompted to confirm deletion."
echo
./delete_user.sh "$demo_username"
echo

echo "3) Attempt to switch to the deleted user (should fail):"
# Allow the next command to fail without exiting this demo script.
set +e
su - "$demo_username" -c "whoami"
status=$?
set -e
if [[ $status -eq 0 ]]; then
    echo "Unexpected: switch succeeded (user may not have been deleted)."
else
    echo "As expected, switching to $demo_username failed."
fi
