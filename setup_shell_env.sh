#!/usr/bin/env bash

# I use strict mode so setup steps stop if something important fails.
set -euo pipefail

err() {
    echo "Error: $*" >&2
    exit 1
}

# I use the script location as the project root so file moves are predictable.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"
ALIAS_SRC="${SCRIPT_DIR}/bash_aliases"
ALIAS_DEST="${HOME}/.bash_aliases"
BASHRC="${HOME}/.bashrc"
BASH_PROFILE="${HOME}/.bash_profile"
BASHRC_MARKER="# Added by setup_shell_env.sh"

mkdir -p "$BIN_DIR"

# Move scripts into the project bin directory if they are still in the repo root.
if [[ -f "${SCRIPT_DIR}/create_user.sh" ]]; then
    mv "${SCRIPT_DIR}/create_user.sh" "${BIN_DIR}/"
fi
if [[ -f "${SCRIPT_DIR}/delete_user.sh" ]]; then
    mv "${SCRIPT_DIR}/delete_user.sh" "${BIN_DIR}/"
fi

# Ensure the scripts remain executable after the move.
if [[ -f "${BIN_DIR}/create_user.sh" ]]; then
    chmod +x "${BIN_DIR}/create_user.sh"
fi
if [[ -f "${BIN_DIR}/delete_user.sh" ]]; then
    chmod +x "${BIN_DIR}/delete_user.sh"
fi

# Install the alias file as a separate file in the home directory.
if [[ -f "$ALIAS_SRC" ]]; then
    cp "$ALIAS_SRC" "$ALIAS_DEST"
else
    err "Alias template not found: $ALIAS_SRC"
fi

# Ensure ~/.bashrc exists so I can safely append to it.
touch "$BASHRC"

# Append prompt/alias/path settings once, guarded by a marker.
if ! grep -qF "$BASHRC_MARKER" "$BASHRC"; then
    cat <<EOF >> "$BASHRC"

$BASHRC_MARKER
# I use distinct colors for user, host, and path so the prompt is easy to read.
export PS1="\\[\\e[1;32m\\]\\u\\[\\e[0m\\]@\\[\\e[1;34m\\]\\h\\[\\e[0m\\]:\\[\\e[1;33m\\]\\w\\[\\e[0m\\] \\[\\e[1;35m\\]bash\\[\\e[0m\\]$ "
# I keep aliases in a separate file so I can edit them without touching .bashrc.
if [[ -f "\$HOME/.bash_aliases" ]]; then
  . "\$HOME/.bash_aliases"
fi
# I add the project bin so create_user.sh and delete_user.sh run from any directory.
export PATH="${BIN_DIR}:\$PATH"
EOF
fi

# Ensure login shells source .bashrc so the prompt/aliases apply after login.
if [[ -f "$BASH_PROFILE" ]]; then
    if ! grep -qF ".bashrc" "$BASH_PROFILE"; then
        cat <<'EOF' >> "$BASH_PROFILE"

# I source .bashrc so login shells pick up my interactive settings.
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF
    fi
else
    cat <<'EOF' > "$BASH_PROFILE"
# I source .bashrc so login shells pick up my interactive settings.
if [ -f "$HOME/.bashrc" ]; then
  . "$HOME/.bashrc"
fi
EOF
fi

echo "Applying changes with: source $BASHRC"
# shellcheck disable=SC1090
set +e
source "$BASHRC"
source_status=$?
set -e
echo "source exit status: $source_status"
echo

echo "Verification: PS1 is now set to:"
echo "$PS1"
echo

set +e
echo "Verification: aliases from $ALIAS_DEST"
alias lrt
alias la
alias cls
alias cddesktop
alias cddownload
alias cddocuments
echo

echo "Verification: PATH includes $BIN_DIR"
command -v create_user.sh
command -v delete_user.sh
echo
set -e

echo "Demonstration: run scripts from /tmp (no args, expect usage errors):"
set +e
(
    cd /tmp || exit 1
    create_user.sh
    echo "create_user.sh exit status: $?"
    delete_user.sh
    echo "delete_user.sh exit status: $?"
)
set -e
