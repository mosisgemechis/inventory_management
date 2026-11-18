# Releasing & updating GM Inventory Everywhere

This document is the update system for the app. It covers how a new version is
published, how installed copies find out about it, and how local data is kept
safe across every update.

---

## 1. How the update system works

| Piece | Where it lives |
| --- | --- |
| Version number | `version:` in `pubspec.yaml` (e.g. `1.0.0+1`) |
| Update feed | GitHub Releases: `mosisgemechis/inventory_management` (latest release) |
| Checker | `lib/core/services/app_update_service.dart` |
| Prompt UI | `lib/core/widgets/app_update_dialog.dart`, called from `lib/main.dart` |
| Data safety | `AppDatabase._backupBeforeUpgrade` in `lib/core/db/app_database.dart` |

On launch (after login/DB bootstrap, so it never slows startup) the app asks
GitHub for the newest published release:

* No release, offline, rate-limited, or same/newer version installed → nothing
  happens. The app is fully offline-first; the check is best-effort.
* A newer `tag_name` → a dialog shows the version, the release notes and an
  **Update now** button that opens the download for the current platform
  (`.apk` on Android, `.exe`/`.zip` on Windows, release page otherwise).
* **Later** remembers the skipped version, so the same release is not offered
  again. A newer release is always offered.
* Automatic checks are rate-limited to once per 6 hours (`AppUpdateService.checkCooldown`).
* The feed URL can be overridden without a code change with
  `UPDATE_FEED_URL=...` in `.env` (see `.env.example`), e.g. to test against a
  staging feed.

## 2. Marking / cutting a version

The app is at **v1.0.0** (first version, tag `v1.0.0`).

```bash
# 1. Commit your work first — the release script refuses a dirty tree.
git add -A && git commit -m "feat: ..."

# 2. Bump the version, commit the bump, and push commit + tag.
tool/release.sh 1.1.0

# 3. Build the artifacts.
flutter build apk --release            # Android
flutter build windows --release        # Windows desktop

# 4. Publish the GitHub Release (this is what the updater reads).
#    Attach the built files as assets, put user-facing notes in the body:
#    GitHub → Releases → Draft a new release → choose tag v1.1.0
#      - app-release.apk   (Android)
#      - gminventory.zip   (Windows build folder)
```

Rules:

* **The tag is the version.** The updater compares `tag_name` with the running
  `pubspec.yaml` version, so `1.1.0` and `v1.1.0` are equivalent.
* Only *published* releases count. Drafts and pre-releases are ignored by
  `/releases/latest`, which is intentional: drafts are safe for testing uploads.
* Release notes become the "What's new" text in the dialog — write them for
  shop owners, not developers.
* Build numbers (`+1`, `+2`, …) must increase for Android to accept an APK as an
  upgrade. `tool/release.sh` bumps it automatically.

## 3. Why no data is lost on update

1. **Same application id, same database path.** Android package
   `com.gminventory.app` and the SQLite file `<app documents>/inventory_db.sqlite`
   are unchanged between versions, so installing over the old app reuses the
   existing data. Never change the application id or the DB file name — that
   would look like a brand-new app with an empty database.
2. **Automatic pre-migration backup.** Before drift opens a database whose
   `PRAGMA user_version` is lower than `AppDatabase.currentSchemaVersion`, the
   app writes `VACUUM INTO` snapshot to `<app documents>/db_backups/`
   (`inventory_db_v<old>_<timestamp>.sqlite`). This is a consistent copy that
   includes rows still in the WAL. The five newest snapshots are kept.
3. **Additive migrations.** Every schema change adds a new
   `if (from < N)` block in `AppDatabase.migration` and bumps
   `currentSchemaVersion`, so existing rows are preserved.
4. **Signing key stays the same.** Android only installs an update signed with
   the same key as the installed app. The project currently signs release
   builds with `android/app/debug.keystore`; keep that keystore file, or move to
   a dedicated release keystore **before** the first store/public release and
   never change it afterwards.
5. **Rollback.** If an update ever goes wrong, copy the newest file from
   `db_backups/` back over `inventory_db.sqlite` (app closed) and reinstall the
   previous build.

Users should **install over** the existing app. Uninstalling deletes app data;
the app's normal data export remains the way to move between devices.

## 4. Checklist for shipping an update

- [ ] `flutter analyze` clean (no new errors/warnings)
- [ ] `flutter test` green
- [ ] If the schema changed: `currentSchemaVersion` bumped + migration added
- [ ] `tool/release.sh <version>` pushed a tag
- [ ] Builds made and attached to a published GitHub Release
- [ ] Install the new build over the old one and confirm data is intact
