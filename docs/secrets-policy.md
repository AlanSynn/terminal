# Secrets Policy

Never commit plaintext credentials, OAuth tokens, private keys, cloud auth caches, browser sessions, or Keychain exports. Prefer re-authentication and password-manager references. Encrypted material must be deliberately reviewed before tracking.

## Public repository policy

A public repo audit must distinguish credentials from privacy metadata. Credentials, private keys, OAuth tokens, cloud auth caches, browser sessions, and Keychain exports are never acceptable. Privacy metadata such as git identity, local usernames, SSH host aliases, institution names, app inventories, and password-manager item paths may be acceptable for personal public dotfiles only after explicit review.

Run `just public-audit` before publishing. Use `just public-audit-strict` when the target is an anonymous/reusable public template rather than a personal dotfiles repo.
