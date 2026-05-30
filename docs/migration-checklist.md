# Migration Checklist

1. Create encrypted Time Machine backup.
2. Audit current machine inventories with `just inventory` and review `inventories/current-machine/curation-report.md`.
3. Run bootstrap dry-run on target.
4. Apply minimal/cli tier before full tier.
5. Re-authenticate cloud and app accounts manually.
6. Keep old machine/backup until verification passes.
