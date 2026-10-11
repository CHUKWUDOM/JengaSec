# SEC starter kit (draft)

Copy into the jengasec-infra repo, keeping paths:

- docs/secrets.md                       rules, tiers, inventory, leak procedure
- .gitleaks.toml                        secret scan config
- .pre-commit-config.yaml               runs gitleaks and the vault-encryption check
- scripts/check-vault-encrypted.sh      blocks plaintext vault files
- ansible/ansible.cfg                   two vault IDs: platform, ci
- ansible/group_vars/all/               vars.yml + vault.yml.example
- gitignore-additions.txt               append to .gitignore

Open a PR per Stage 0 rules, then ask Platform and APP to review the inventory table.
