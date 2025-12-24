#!/usr/bin/env bash
# demo_create_user.sh — WGU D796 RQN1 Task 1 (A5 demo)
#
# a1: Demonstrate `create_user.sh` behavior and collect rubric evidence.
# a2: Prefer the project copy in `./bin` to avoid PATH conflicts with other installations.
# a3: Run three scenarios: missing args, valid creation, and switch instructions.

set -euo pipefail  # a4: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() {
  echo "Error: $*" >&2
  exit 1
}

# a5: Resolve absolute project directory and expected script locations.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_CREATE="${PROJECT_DIR}/bin/create_user.sh"
HOME_CREATE="${HOME}/bin/create_user.sh"

DEFAULT_PASSWORD="TempPass123!"
OS="$(uname -s)"

# f2: pick_create_script — Select a script path with strict priority: project `./bin`, `~/bin`, then PATH.
pick_create_script() {
  if [[ -x "$PROJECT_CREATE" ]]; then
    echo "$PROJECT_CREATE"
    return 0
  fi
  if [[ -x "$HOME_CREATE" ]]; then
    echo "$HOME_CREATE"
    return 0
  fi
  if command -v create_user.sh >/dev/null 2>&1; then
    command -v create_user.sh
    return 0
  fi
  return 1
}

# a6: Select the intended `create_user.sh` path using the priority order defined above.
CREATE_SCRIPT="$(pick_create_script || true)"
[[ -n "$CREATE_SCRIPT" ]] || err "Could not find create_user.sh in ./bin, ~/bin, or PATH"

# a7: Print environment detection and script resolution evidence (PATH conflict proof).
echo "Demo: create_user.sh requirements"
echo "Detected OS: ${OS}"
echo

echo "Using create_user.sh at:"
echo "  ${CREATE_SCRIPT}"
echo

echo "type -a create_user.sh (for proof of PATH conflicts):"
type -a create_user.sh 2>/dev/null || true
echo

# a8: Scenario 1 — run without arguments to demonstrate usage/error handling.
echo "1) Run script without arguments (should error):"
set +e
"$CREATE_SCRIPT"
status=$?
set -e
echo "Exit status: $status"
echo

# a9: Use a provided username argument or generate a unique demo username.
demo_username="${1:-}"
if [[ -z "$demo_username" ]]; then
  demo_username="demo_user_$(date +%s)"
fi

# a10: Scenario 2 — run with a valid username and password to create the account.
echo "2) Run script with valid arguments (username + password):"
echo "   Username: $demo_username"
echo "   Assigned password: $DEFAULT_PASSWORD"
echo
"$CREATE_SCRIPT" "$demo_username" "$DEFAULT_PASSWORD"
echo

# a11: Linux verification — show group evidence and password-change status.
if [[ "$OS" == "Linux" ]]; then
  echo "Verification (Linux):"
  echo "- Group dev_group:"
  if command -v getent >/dev/null 2>&1; then
    getent group dev_group || true
  elif [[ -r /etc/group ]]; then
    grep -E "^dev_group:" /etc/group || true
  else
    echo "  (Unable to read group database)"
  fi
  echo

  if command -v chage >/dev/null 2>&1; then
    echo "- Password change status (chage -l $demo_username):"
    chage -l "$demo_username" || true
    echo
  elif command -v passwd >/dev/null 2>&1; then
    echo "- Password status (passwd -S $demo_username):"
    passwd -S "$demo_username" || true
    echo
  fi
fi

# a12: Scenario 3 — provide OS-specific commands to prove the new user can be switched into.
if [[ "$OS" == "Darwin" ]]; then
  echo "3) Switch to the new user (macOS):"
  echo "   Run the following manually in the demo recording:"
  echo "   sudo -iu $demo_username whoami"
  echo "   sudo -iu $demo_username id"
  echo
  echo "Note: macOS 'force password change' enforcement may vary by policy."
else
  echo "3) Switch to the new user (Linux):"
  if ! command -v su >/dev/null 2>&1; then
    err "su not found; cannot switch users on this system."
  fi
  echo "   Enter the assigned password when prompted; you should be forced to change it."
  echo
  if [[ -t 0 ]]; then
    echo "Opening a login shell for ${demo_username}..."
    set +e
    su - "$demo_username"
    switch_status=$?
    set -e
    if [[ $switch_status -ne 0 ]]; then
      echo "Switch to ${demo_username} exited with status: $switch_status"
    else
      echo "Exited from ${demo_username} login shell."
    fi
  else
    echo "Non-interactive session detected. Run manually:"
    echo "   su - $demo_username"
    echo "   (Enter password: $DEFAULT_PASSWORD)"
    echo "After login, exit back:"
    echo "   exit"
  fi
fi
