#!/usr/bin/env bash
# Run as root on the shared VM (secrets live there per the architecture draft).
# Creates a root-owned secrets directory readable only by a dedicated group.
# Usage: sudo ./setup-runtime-secrets.sh [group-member ...]
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
GROUP=jengasec-secrets
DIR=/etc/jengasec/secrets

getent group "$GROUP" >/dev/null || groupadd --system "$GROUP"
install -d -m 0750 -o root -g "$GROUP" /etc/jengasec "$DIR"
for u in "$@"; do usermod -aG "$GROUP" "$u" && echo "added $u to $GROUP"; done

# helper: reads the secret from stdin (so it never lands in shell history or argv)
cat > /usr/local/sbin/jengasec-put-secret <<'HELPER'
#!/usr/bin/env bash
# Usage: jengasec-put-secret NAME   (then type/paste the value, Ctrl-D; or pipe it in)
set -euo pipefail
name="${1:?name required}"
case "$name" in *[!A-Za-z0-9._-]*|"") echo "bad name" >&2; exit 1;; esac
umask 077
tmp="$(mktemp /etc/jengasec/secrets/.tmp.XXXXXX)"
cat > "$tmp"
chown root:jengasec-secrets "$tmp"; chmod 0640 "$tmp"
mv "$tmp" "/etc/jengasec/secrets/$name"
echo "stored $name"
HELPER
chmod 0750 /usr/local/sbin/jengasec-put-secret

ls -ld /etc/jengasec /etc/jengasec/secrets
echo "Done. Add each secret with: sudo jengasec-put-secret <name>"
