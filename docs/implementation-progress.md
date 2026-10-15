# تقدم تنفيذ دبت للحسابات

Current direction: implement the approved v1 scope feature by feature. The user's latest stack rules take precedence over earlier suggestions: Flutter, go_router, ChangeNotifier/MVVM, dart_mappable, and feature folders. Reuse the existing design system. Keep tests minimal and focused on consequential behavior.

## Implemented so far

- Local SQLite schema, transactional posting, fixed-point amounts, quantity/unit conversion, immutable document snapshots, balanced journal, stock and cash guards, request idempotency.
- Local shop/owner setup, login, owner recovery code, role checks, staff management, and currency lock.
- Catalog, services, categories, barcodes, units, fractional quantities, opening stock.
- Parties with independent customer/supplier accounts, opening balances and statements.
- Sales/purchases, mixed product/service sales, line/invoice discounts, split payments, purchasing freight, drafts.
- Customer collections, supplier payments, allocation preview/manual/general credit, cash accounts, opening cash, expenses, capital, drawings and transfers.
- Cumulative overview, trial balance, ledger.
- Encrypted backups with SQLite snapshot, authenticated encryption, verification, hourly/launch/resume scheduling, external folder support, pre-restore backup.
- Linked sales/purchase returns, partial service refunds, damaged return handling, inventory counts and adjustments.
- Cancellation and linked correction UI, with safeguards against later stock movements and cost adjustments.

## Completed in the implementation loop

- Quick receiving and final supplier invoice reconciliation without duplicate quantities, with current adjustments to remaining stock and realized costs.
- Existing credit allocation, advance refunds, reallocation audit, and independent legacy balance corrections.
- Cash reconciliation and reviewed opening closure.
- Linked reversal/correction drafts and original invoice retention.
- Period reports, statements, stock movements, A4/80mm document generation, print/share, PDF and RTL XLSX exports.
- Fresh-install encrypted recovery, verified backup snapshots, retention, local fallback when an external folder is absent, and a global backup warning.
- macOS scoped folder bookmarks, pre-upgrade backup, barcode/POS entry, keyboard shortcuts, and activity log.
- Windows build/installer recipes, a manual CI workflow, macOS packaging script, and an Arabic start/recovery guide.

## Remaining acceptance outside this local implementation

- Execute the Windows build/installer on a Windows host and verify clean install and upgrade.
- Run Android and Windows on target hardware; physical printer/USB/scanner behavior remains unverified.
- Finalize distribution identity, signing, support channel and deferred commercial activation.
- Accountant review of interleaved cost adjustments, real-shop acceptance, and independent recovery on a replacement device.

## Evidence and limits

- All 19 local checks passed: nine focused application checks plus ten existing design-system checks. They include the operating cycle, rollback/idempotency/aggregate stock guard, backups and fresh recovery, cost reconciliation, service refunds, advances, exports, and phone/desktop navigation.
- Approved example result: cash 20,500, remaining stock value 7,000, supplier debt 6,000, profit 1,500.
- macOS debug launch/hot restart and macOS release build succeeded; Android debug APK build succeeded. Dart tooling reported no startup runtime errors. These are local build results, not device acceptance.
- Native computer-use access to dukan_app was not authorized; no native visual inspection was completed.
- Windows execution, target-device operation, physical printers, accountant review and field acceptance remain separate from local implementation.
- No claim of release readiness. This task inserted no shop records into the running app; automated checks used isolated temporary/in-memory databases.
