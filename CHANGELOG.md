# Changelog

All notable changes to GM Inventory Everywhere are recorded here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [Semantic Versioning](https://semver.org/).

## [1.0.0] - 2026-11-18

First released version.

### Added

- Offline-first inventory, sales/POS, purchases, suppliers, branches, debt and
  audit-log management on top of a local Drift/SQLite database, with a FastAPI
  backend for accounts, devices and background sync.
- Roles and per-branch access, barcode scanning, Excel/CSV import, PDF/Excel
  reports and exports, notifications, and a full admin dashboard.
- Subscription plans (Starter, Business, Enterprise) with a 14-day-free trial
  flow, add-ons, instant plan changes, feature gating and checkout.
- In-app update checks against GitHub Releases, with a pre-migration database
  snapshot before any schema upgrade.
