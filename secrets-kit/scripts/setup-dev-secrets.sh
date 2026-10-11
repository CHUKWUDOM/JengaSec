#!/usr/bin/env bash
# Run on your Debian 12 dev VM (not on shared servers).
# Creates ~/.jengasec with vault password files, installs tooling, never prints secrets.
# Env: SKIP_INSTALL=1 to skip apt; JENGASEC_DIR to change the directory.
set -euo pipefail
umask 077
DIR="${JENGASEC_DIR:-$HOME/.jengasec}"

if [ "${SKIP_INSTALL:-0}" != "1" ]; then
  sudo apt-get update
  sudo apt-get install -y git openssl ansible pre-commit
fi

mkdir -p "$DIR"; chmod 700 "$DIR"
for id in platform ci; do
  f="$DIR/vault-$id"
  if [ -e "$f" ]; then
    echo "kept existing: $f"
  else
    openssl rand -base64 32 > "$f"
    chmod 600 "$f"
    echo "created: $f"
  fi
done

echo
echo "NEXT (manual):"
echo " 1. Store each vault password in the team password manager NOW (open the file locally; do not paste it into chat)."
echo " 2. Give the 'platform' password to the other Tier 0 members in person or through the password manager."
echo " 3. In your repo clone: pre-commit install && pre-commit run --all-files"
for tool in ansible-vault pre-commit git; do
  command -v "$tool" >/dev/null || echo "WARNING: $tool not found"
done
