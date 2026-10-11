# Secrets Handling (SEC) — DRAFT v0.2

Owner: Security & Identity (SEC). Updated for the 9 Oct architecture (OPNsense gateway, six VMs, Docker image submission).
This document records **where** secrets live and **who** may read them. It never contains a secret value.

## 1. Rules
1. No plaintext secrets in the repo: passwords, tokens, private keys, kubeconfigs, .env files, WireGuard configs, OPNsense config backups.
2. No secret in WhatsApp, email or tickets. Share in person or through the approved password manager.
3. Repo secrets exist only as **Ansible Vault** encrypted files; CI and pre-commit block anything else.
4. Vault passwords live outside the repo (`~/.jengasec/`, mode 600), held by Tier 0 only.
5. Runtime secrets on the shared VM are stored with root-only permissions and are never printed to logs.
6. One person, one account. The shared bootstrap login has an end date and is rotated when retired.
7. Least privilege: API users and tokens get only the permissions their job needs, and are source-restricted where possible.
8. A secret that appeared anywhere it should not have is treated as compromised and rotated (section 5).

## 2. Who can read what
| Tier | Who | Reads |
|---|---|---|
| 0 | Platform lead, Security lead, one named backup | Vault passwords, Proxmox, OPNsense admin |
| 1 | Named Network / Platform engineers | Credentials for the systems they operate |
| 2 | Area leads | Secrets of their own area only |
| 3 | Everyone else | None; repo read access only |
The named people per tier are kept in the access register, not here.

## 3. Inventory (no values). "TBC" = to confirm with the owner.
| Secret | Lives in | Owner | Readers | Rotation |
|---|---|---|---|---|
| Vault password `platform` | Tier 0 password manager + `~/.jengasec/vault-platform` | SEC | Tier 0 | Tier 0 change; 6-monthly |
| Vault password `ci` (only if CI exists) | as above | SEC | Tier 0 | TBC; may be dropped, see note below |
| Bootstrap shared admin login (lab) | Password manager | Platform | Tier 0/1 | **Retire** when named accounts exist, then rotate |
| Staff SSH keys (ed25519, passphrase) | Each person's machine; public key in repo | Each person | Owner | Loss or departure |
| Proxmox host and iDRAC admin | Password manager | Platform | Tier 0 | Before event; on staff change |
| OPNsense admin accounts (named) | OPNsense; passwords in password manager | Network + SEC | Tier 0, named admins | On staff change |
| OPNsense API user for provisioning (key + secret) | Shared VM, root-only; vault copy | SEC + Network | Tier 0 | Before event; on exposure |
| OPNsense kill-switch API credential | Held by the two named owners only | SEC | 2 named owners | Before event |
| OPNsense config backups | Encrypted, off-repo | Network | Tier 0 | Each change |
| WireGuard server private key | Gateway only | Network | Tier 0 | Per event |
| WireGuard participant private keys | Preferred: generated client-side; **not stored** | Each participant | Owner | Per event |
| JengaSec DB credentials (PostgreSQL) | Shared VM; vault copy | Platform | Services that need it | Per event |
| Registry credentials (shared VM) | Shared VM; k8s image-pull secrets | Platform / APP | Cluster nodes | Per event |
| Participant image pull tokens (GHCR / Docker Hub) | Shared VM, encrypted | APP | Registry worker only | **Delete after freeze** |
| AI API team tokens (scoped) | Obs VM | AIC / OBS | Issued to each team | Per event; revoke on leak |
| Per-cell database passwords | k8s Secret per namespace | APP | That cell only | Daily reset |
| Grafana admin | Obs VM | OBS | Tier 0, OBS lead | Before event |
| Public site hosting + DB (Render, Neon) | Their dashboards; password manager | Web | Named web admins | On staff change |
| Cloudflare / Gitea / runner tokens | Only if those are still used | TBC | TBC | TBC |

Note: Gitea and build runners were removed in the 9 Oct design. Confirm and drop the `ci` vault ID and the runner/Cloudflare rows if so.

## 4. Adding or using a secret
1. Add its inventory row in the same PR.
2. Put the value in the right vault file: `ansible-vault edit --encrypt-vault-id platform ansible/group_vars/all/vault.yml`.
3. Reference it from `vars.yml` as `thing: "{{ vault_thing }}"`.
4. Use `no_log: true` on tasks that handle it. Never echo it in scripts.
5. Add a placeholder (never a real value) to `vault.yml.example`.

## 5. If a secret leaks
1. **Rotate first**; deleting it from history does not un-leak it.
2. Tell the SEC lead; note the time, where it appeared and who could have seen it.
3. Remove it from where it leaked.
4. Update the inventory and check why the guard did not catch it.

## 6. Known gaps to close before the event
- Shared bootstrap login retirement date.
- Decide WireGuard key generation: client-side (preferred) vs server-side.
- Where config backups and vault passwords are kept, and the named Tier 0 members.
- Retention and deletion for participant tokens and per-person attribution data (privacy notice on the registration site).
