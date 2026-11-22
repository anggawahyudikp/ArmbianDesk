# Uninstalling & Restoring ArmbianDesk

## Uninstall
Preview removal:
```bash
sudo armbiandesk uninstall --user USER --dry-run
```
Remove ArmbianDesk files only (preserves your Chromium profile, cookies, bookmarks, user files, SSH configuration, stock desktop sessions, and shared APT packages):
```bash
sudo armbiandesk uninstall --user USER
```

## Restore Pre-Install Backup
Every `armbiandesk install` prints a `Backup ID` (stored under `/var/lib/armbiandesk/backups/<BACKUP_ID>`).
```bash
# Dry-run restore and check for local user modifications (conflicts)
sudo armbiandesk restore --backup <BACKUP_ID> --dry-run

# Restore original files (skips files modified after install unless --force is passed)
sudo armbiandesk restore --backup <BACKUP_ID>
sudo armbiandesk restore --backup <BACKUP_ID> --force
```
