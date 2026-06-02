# Secrets Policy

Never commit plaintext credentials, OAuth tokens, private keys, cloud auth caches, browser sessions, or Keychain exports. Prefer re-authentication and password-manager references. Encrypted material must be deliberately reviewed before tracking.

## Public repository policy

A public repo audit must distinguish credentials from privacy metadata. Credentials, private keys, OAuth tokens, cloud auth caches, browser sessions, and Keychain exports are never acceptable. Privacy metadata such as git identity, local usernames, SSH host aliases, institution names, app inventories, and password-manager item paths may be acceptable for personal public dotfiles only after explicit review.

Run `just public-audit` before publishing. Use `just public-audit-strict` when the target is an anonymous/reusable public template rather than a personal dotfiles repo.

## Private repository incident policy

A private repo may still cause incidents through local credential persistence, broad shell environment propagation, external-drive backups, SSH/agent metadata, and bootstrap supply-chain execution. Run `just private-risk-audit` before non-dry-run bootstrap or before adding collaborators/devices. Use `just private-risk-audit-strict` when high-risk findings must be fixed rather than accepted.
