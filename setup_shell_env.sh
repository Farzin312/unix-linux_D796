#!/usr/bin/env bash
# setup_shell_env.sh — WGU D796 RQN1 Task 1 (Section C)
#
# a1: Create and populate a project-local `./bin` directory (deliverable visibility).
# a2: Install the same scripts into `~/bin` for PATH-based execution from any working directory.
# a3: Ensure `~/bin` is first in PATH to avoid conflicts with other installed copies.
# a4: Configure a colored `$` prompt and load aliases from `~/.bash_aliases`.
# a5: Ensure login shells source `~/.bashrc` (macOS-safe).

set -euo pipefail  # a6: Stop on errors, unset variables, and pipeline failures.

# f1: err — Print an error message to stderr and exit non-zero.
err() {
  echo "Error: $*" >&2
  exit 1
}

# f2: require_cmd — Verify a required command exists on PATH.
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || err "Required command not found: $1"
}

# f3: find_script — Locate a script by searching the project root, project `./bin`, `~/bin`, then PATH.
find_script() {
  local name="$1"
  local project_dir="$2"

  if [[ -f "$project_dir/$name" ]]; then
    echo "$project_dir/$name"
    return 0
  fi

  if [[ -f "$project_dir/bin/$name" ]]; then
    echo "$project_dir/bin/$name"
    return 0
  fi

  if [[ -f "$HOME/bin/$name" ]]; then
    echo "$HOME/bin/$name"
    return 0
  fi

  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi

  return 1
}

# a7: Validate required external commands used by this setup script.
for cmd in uname cp chmod mkdir grep cat tr printf sed nl; do
  require_cmd "$cmd"
done

# a8: Resolve the absolute project directory from the location of this script.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"  # a8a: Cache OS name for login-shell config decisions.

PROJECT_BIN="$PROJECT_DIR/bin"  # a9: Project-local bin directory (./bin).
HOME_BIN="$HOME/bin"            # a10: Home bin directory for PATH execution.

ALIAS_SRC="$PROJECT_DIR/bash_aliases"
ALIAS_DEST="$HOME/.bash_aliases"
BASHRC="$HOME/.bashrc"
BASH_PROFILE="$HOME/.bash_profile"
PROFILE="$HOME/.profile"
MARKER="# Added by setup_shell_env.sh (WGU D796 RQN1)"

# a11: Create the project bin and home bin directories (idempotent).
mkdir -p "$PROJECT_BIN"
mkdir -p "$HOME_BIN"

# a12: Locate source copies of the deliverable scripts.
create_src="$(find_script create_user.sh "$PROJECT_DIR" || true)"
delete_src="$(find_script delete_user.sh "$PROJECT_DIR" || true)"

[[ -n "$create_src" ]] || err "create_user.sh not found (expected in project root, project bin, ~/bin, or PATH)"
[[ -n "$delete_src" ]] || err "delete_user.sh not found (expected in project root, project bin, ~/bin, or PATH)"

# a13: Copy scripts into the project `./bin` directory (deliverable visibility).
proj_create="$PROJECT_BIN/create_user.sh"
proj_delete="$PROJECT_BIN/delete_user.sh"

if [[ "$create_src" != "$proj_create" ]]; then
  cp -f "$create_src" "$proj_create"
fi
if [[ "$delete_src" != "$proj_delete" ]]; then
  cp -f "$delete_src" "$proj_delete"
fi
chmod +x "$proj_create" "$proj_delete"

# a14: Copy scripts into `~/bin` for PATH-based execution.
home_create="$HOME_BIN/create_user.sh"
home_delete="$HOME_BIN/delete_user.sh"

# a15: Prefer the project `./bin` versions as the source of truth for `~/bin`.
cp -f "$proj_create" "$home_create"
cp -f "$proj_delete" "$home_delete"
chmod +x "$home_create" "$home_delete"

# a16: Install the project alias file into `~/.bash_aliases`.
[[ -f "$ALIAS_SRC" ]] || err "bash_aliases file missing in project folder: $ALIAS_SRC"
cp -f "$ALIAS_SRC" "$ALIAS_DEST"

# a17: Ensure `~/.bashrc` exists before attempting to append configuration.
touch "$BASHRC"

# a18: Append configuration once (C1/C2/C4b) using a marker to keep the operation idempotent.
if ! grep -qF "$MARKER" "$BASHRC"; then
  cat <<'EOF' >>"$BASHRC"

# Added by setup_shell_env.sh (WGU D796 RQN1)

# C1: "$" prompt with different colors
export PS1="\[\e[1;32m\]\$\[\e[0;36m\] "

# C1a: Reset color before command output
export PROMPT_COMMAND='echo -ne "\e[0m"'

# C2: Load aliases from separate file
if [[ -f "$HOME/.bash_aliases" ]]; then
  . "$HOME/.bash_aliases"
fi

# C4b: Ensure ~/bin is FIRST in PATH
case ":$PATH:" in
  *":$HOME/bin:"*) ;;
  *) export PATH="$HOME/bin:$PATH" ;;
esac
EOF
fi

# a19: Ensure login shells source `~/.bashrc`.
# a19a: macOS uses .bash_profile; Linux typically uses .profile (avoid overriding it).
if [[ "$OS" == "Darwin" ]]; then
  if [[ -f "$BASH_PROFILE" ]]; then
    if ! grep -q 'source "$HOME/.bashrc"' "$BASH_PROFILE" && ! grep -q 'source ~/.bashrc' "$BASH_PROFILE"; then
      cat <<'EOF' >>"$BASH_PROFILE"

# Added by setup_shell_env.sh (WGU D796 RQN1)
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
EOF
    fi
  else
    cat <<'EOF' >"$BASH_PROFILE"
# Added by setup_shell_env.sh (WGU D796 RQN1)
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
EOF
  fi
else
  if [[ -f "$BASH_PROFILE" ]]; then
    if ! grep -q 'source "$HOME/.bashrc"' "$BASH_PROFILE" && ! grep -q 'source ~/.bashrc' "$BASH_PROFILE"; then
      cat <<'EOF' >>"$BASH_PROFILE"

# Added by setup_shell_env.sh (WGU D796 RQN1)
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc"
EOF
    fi
  elif [[ -f "$PROFILE" ]]; then
    if ! grep -q '\.bashrc' "$PROFILE"; then
      cat <<'EOF' >>"$PROFILE"

# Added by setup_shell_env.sh (WGU D796 RQN1)
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
EOF
    fi
  else
    cat <<'EOF' >"$PROFILE"
# Added by setup_shell_env.sh (WGU D796 RQN1)
[ -f "$HOME/.bashrc" ] && . "$HOME/.bashrc"
EOF
  fi
fi

# a20: Apply the updated shell config and print verification output.
echo "Applying changes with: source $BASHRC"
# shellcheck disable=SC1090
source "$BASHRC"
echo "source exit status: 0"
echo

echo "Verification: PS1 (prompt) value:"
printf '%s\n' "$PS1"
echo

echo "Verification: key aliases:"
alias lrt 2>/dev/null || true
alias la 2>/dev/null || true
alias cls 2>/dev/null || true
alias desktop 2>/dev/null || true
alias download 2>/dev/null || true
alias documents 2>/dev/null || true
echo

echo "Verification: project bin directory exists and contains scripts:"
ls -la "$PROJECT_BIN"
echo

echo "Verification: home bin directory exists and contains scripts:"
ls -la "$HOME_BIN"
echo

echo "Verification: PATH order (first 15 entries):"
echo "$PATH" | tr ':' '\n' | nl -ba | sed -n '1,15p'
echo

echo "Verification: create_user.sh resolves to:"
type -a create_user.sh || true
echo
echo "Verification: delete_user.sh resolves to:"
type -a delete_user.sh || true
echo

echo "Demonstration: run scripts from /tmp (no args, expect errors):"
set +e
(
  cd /tmp || exit 1
  create_user.sh
  echo "create_user.sh exit status: $?"
  delete_user.sh
  echo "delete_user.sh exit status: $?"
)
set -e

echo
echo "Done — project ./bin created, scripts installed to project and ~/bin, PATH is set."
exit 0
