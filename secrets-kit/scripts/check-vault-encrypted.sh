#!/usr/bin/env bash
# Fails if any given vault file is not Ansible-Vault encrypted.
# Used by pre-commit; also safe to run in CI: scripts/check-vault-encrypted.sh $(git ls-files 'ansible/**/vault*.yml')
set -u
rc=0
for f in "$@"; do
  [ -f "$f" ] || continue
  if ! head -n1 "$f" | grep -q '^\$ANSIBLE_VAULT;'; then
    echo "ERROR: $f is NOT encrypted. Run: ansible-vault encrypt --encrypt-vault-id platform $f" >&2
    rc=1
  fi
done
exit $rc
