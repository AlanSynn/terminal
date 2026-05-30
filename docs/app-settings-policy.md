# App Settings Policy

Use app-native export/sync for large GUI apps. Only automate explicit allowlisted defaults. Do not import full browser profiles or application support directories into git.

App-native exports can be copied into the external drive's `_backup-meta/` or `app-exports/` area after review. Do not mirror full `Library/Application Support`, browser profiles, Keychains, or credential caches through this repo.
