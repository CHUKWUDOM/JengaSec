# Secrets Handling (SEC) — DRAFT v0

Owner: Security & Identity (SEC). Status: draft for review by Platform and Engagement.
This document records **where** secrets live and **who** may read them.
It never contains a secret value. If you are about to paste one here, stop.

## 1. Rules

1. No secret is ever committed in plaintext. That includes passwords, tokens, private keys, kubeconfigs, `.env` files and WireGuard configs.
2. No secret is ever sent in WhatsApp, Slack, email or a ticket. Share in person or through the approved password manager.
3. Platform secrets in the repo exist only as **Ansible Vault** encrypted files (`$ANSIBLE_VAULT;` header). CI blocks anything else.
4. Vault passwords live **outside the repo** (`~/.jengasec/`, mode 600) and are held by Tier 0 only.
5. One person, one account. Shared logins are bootstrap-only, carry an end date, and are rotated when retired.
6. Least privilege: if you cannot say why you need to read a secret, you do not get it.
7. A secret that appeared anywhere it should not have (chat, repo, screenshot) is treated as compromised and rotated. See section 5.

## 2. Who can read what

| Tier | Who | Reads |
|---|---|---|
| 0 | Platform lead, Security lead, one named backup | All vault passwords, Proxmox/host credentials |
| 1 | Platform and Network engineers (named) | Credentials for the systems they operate, via the password manager |
| 2 | Area leads | Secrets for their own area only (e.g. APP: registry and deploy tokens) |
| 3 | All other team members | No secrets. Repo read access only |

Named people per tier are listed in the access register (SEC-owned), not here.

## 3. Secrets inventory (no values)

Add a row **before** a new secret is created. "TBC" means not yet confirmed with the owner.

| Secret | Lives in | Owner | Readers | Rotation |
|---|---|---|---|---|
| Vault password: `platform` | Tier 0 password manager and `~/.jengasec/vault-platform` | SEC | Tier 0 | On any Tier 0 change, and every 6 months |
| Vault password: `ci` | Same as above | SEC | Tier 0 and APP lead | On any change in readers |
| Bootstrap shared admin login (lab) | Password manager (Tier 0/1) | Platform | Tier 0/1 | **Retire** once named accounts and SSH keys exist, then rotate |
| Named staff SSH keys (ed25519, passphrase) | Each person's machine; public key in repo | Each person | Owner only | On loss, or when someone leaves |
| Cloudflare API token (DNS edit only) | `ansible/group_vars/all/vault.yml` | APP | Tier 0 and APP lead | Every 90 days (TBC) |
| Cloudflare Access / tunnel credentials | Vault file (TBC) | Platform | Tier 0 | On any suspected exposure |
| Gitea and registry tokens | Vault file (`ci`) | APP | APP lead, Tier 0 | Every 90 days (TBC) |
| CI runner registration tokens | Vault file (`ci`) | APP | APP lead, Tier 0 | Each re-registration |
| Per-team preview passwords | Generated per cell, stored as k8s Secrets | APP | That team plus Tier 0 | Per event |
| Per-cell AI API tokens | k8s Secret in the cell namespace | AIC (TBC) | Tier 0 | Per event |
| WireGuard private keys | Generated on host, never in repo | Platform | Tier 0 | Per event or on exposure |

## 4. How to add or use a secret

1. Add its row to section 3 in your PR.
2. Add the value to the right vault file:
   `ansible-vault edit --encrypt-vault-id platform ansible/group_vars/all/vault.yml`
3. Reference it from `vars.yml` as `my_thing: "{{ vault_my_thing }}"`. Variables from the vault are always prefixed `vault_`.
4. Never `echo` or log it in CI. Mark tasks that touch it with `no_log: true`.
5. Add an example placeholder (not a real value) to `vault.yml.example`.

## 5. If a secret leaks

1. **Rotate first.** Removing it from git history does not un-leak it.
2. Tell the SEC lead. Record the time, where it appeared and who could have seen it.
3. Remove it from the place it leaked (delete the message, rewrite history if needed).
4. Update the row in section 3 and check why the guard (pre-commit, CI scan) did not catch it.
