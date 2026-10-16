# Database growth audit — 16 October 2026

Implementation follow-up: [Database growth fixes](database-growth-fixes.md). This report records the original audit; subsequent user direction requests initial-schema changes without new migrations.

SQLite remains a reasonable fit for this local application. The current query paths have measurable growth problems that should be fixed before relying on a large transaction history. The first work should be indexes, bounded SQL reads, and direct barcode lookup. A database-engine replacement is not supported by these findings.

This review covers schema version 2 at commit `ea7fe01`, repository queries, their UI callers, posting validation, migrations, and backup behavior. Application implementation and user databases were not changed. Candidate indexes were added only to disposable, generated databases.

## Evidence and limits

A temporary Flutter test instantiated the actual `LocalDatabase.memory()` and `AppDependencies`, generated records using the current model serializers, and called the production repositories. SQLite reported version 3.53.4. Every fixture passed `PRAGMA quick_check` and `PRAGMA foreign_key_check`. These checks establish structural validity of the generated data, not validation of a real shop's accounting balances.

Fixtures contained 10,000, 50,000, and 100,000 documents; 1,000, 5,000, and 10,000 products respectively; 100 parties; four journal rows, one stock movement, and one allocation per document. Documents were 90% sales and 10% receipts. Each sale had one line. The most recent 1,000 documents were dated 16 October 2026; older documents were dated 1 January. The single-day sales report therefore returned 900 rows at every database size.

Measurements include real SQL and Dart mapping, after one warm-up. Most are the median of three repetitions; the sales report has one timed repetition after warm-up. This is an in-memory Flutter test on the development Mac. It excludes screen rendering, production disk latency, backup runtime, and target-device performance. It does not establish a safe maximum record count. Actual results depend on document size, record distribution, hardware, and runtime mode.

The raw output is in [database-growth-audit-2026-10-16.txt](database-growth-audit-2026-10-16.txt). The command used was `flutter test --no-pub test/_database_scale_audit_test.dart --reporter expanded`; the temporary harness was removed from the test suite after the audit.

## Findings, in recommended order

**1. High: frequently used lookups scan growing history tables.**

The schema has indexes for `journal(account,party_id)`, `journal(document_id)`, `stock_moves(document_id)`, `allocations(invoice_id)`, and `documents(party_id,kind)`, plus primary/unique keys and catalog-reference indexes. It lacks indexes for document source links, document date ranges, stock movements by product, and allocations by payment source.

`InvoiceRepository.due()` searches all documents for returns/reversals linked to one invoice (`lib/features/invoices/data/invoice_repository.dart:42`). `CreditRepository.sources()` performs cancellation checks and a payment-source sum for each source (`lib/features/finance/data/credit_repository.dart:14`). Product movement screens and opening checks filter stock movements by product (`lib/features/inventory/data/inventory_repository.dart:12`, `lib/features/catalog/data/catalog_repository.dart:91`). Pending receipts, corrections, and returns use the same unindexed source-link pattern.

The baseline query plans explicitly reported `SCAN documents`, `SCAN allocations`, and `SCAN s` for these selective lookups. The latest-invoice ordering also required a temporary sorting B-tree. The existing `documents(party_id,kind)` index does not directly satisfy a query filtering only by kind.

The highest-value candidates tested together were:

```sql
CREATE INDEX documents_source_kind ON documents(source_id, kind);
CREATE INDEX documents_kind_posted ON documents(kind, posted_at);
CREATE INDEX documents_posted ON documents(posted_at);
CREATE INDEX stock_moves_product ON stock_moves(product_id);
CREATE INDEX allocations_payment ON allocations(payment_id);
```

These are recommendations, not an applied migration. The kind/date index supports the dashboard's date ordering; it does not also guarantee an efficient `ORDER BY rowid` for the current unbounded invoice list. Preserve current ordering deliberately when introducing SQL pagination: a kind-only index can support kind plus rowid ordering, or revise the query/index together if date ordering is desired. Do not create an explicit index on SQLite's hidden `rowid` column.

Add adopted indexes through a version-3 migration so existing installations receive them. `migrate()` returns immediately for databases already at the current version (`lib/core/data/local_database.dart:66`), so editing only the initial schema would miss existing users. Verify both fresh installs and version-2 upgrades, including restore of older backups. Indexes increase storage and write work; keep the ones justified by actual queries. SQLite's [query-planning documentation](https://www.sqlite.org/queryplanner.html) explains these tradeoffs.

**2. High: displayed pagination still reads and decodes complete lists.**

`InvoiceRepository.list()` returns every document of the requested kind, including the JSON containing all invoice lines. `InvoicesPage.build()` then filters that list in Dart and displays ten entries with `skip/take` (`lib/features/invoices/presentation/invoices_page.dart:29`). Changing a page or typing a search repeats the full read.

Catalog and party screens use the same pattern (`lib/features/catalog/presentation/catalog_view_model.dart:12`, `lib/features/parties/presentation/party_view_model.dart:13`). Catalog rendering requests the filtered list separately for visible rows and total count. Low-stock filtering can add a stock query per product. Statements, ledgers, and movement histories also return complete histories.

Move filters, counts, and page bounds into SQL. Return list summaries instead of full invoice details; load lines only when opening a document. Fetch stock quantities and party labels with the page query. Keep stable ordering with a tie-breaker. For the existing numbered page UI, bounded `LIMIT/OFFSET` is a practical first step; cursor pagination becomes useful for very deep sequential browsing.

Name sorting currently extracts JSON and sorts the entire product/party table. Targeted expression indexes or relational columns for frequently searched/sorted fields can help after queries move into SQL. A broad schema rewrite is unnecessary. Moving a contains-search to `LIKE '%text%'` alone does not make it indexable; see SQLite's [LIKE optimization conditions](https://www.sqlite.org/optoverview.html#the_like_optimization). Preserve current search semantics and evaluate a search index only if needed.

**3. High for checkout responsiveness: barcode scanning bypasses its existing index.**

`InvoiceViewModel.addBarcode()` accesses `products`, which calls `catalog.all()`, sorts and decodes every product, filters active/type eligibility, then searches the Dart list (`lib/features/invoices/presentation/invoice_view_model.dart:113`). Each scan therefore grows with the catalog.

Use `SELECT data FROM products WHERE barcode = ?` and decode the single match, preserving current permissions, active-product checks, sale/purchase eligibility, and empty-barcode behavior. `products.barcode` is already UNIQUE, and its query plan confirmed an indexed lookup. No additional barcode index is needed. The benchmark compared the current catalog-reading/search portion with direct SQL; it did not time draft persistence, UI updates, or an end-to-end hardware scan.

**4. High: slow SQL and decoding execute on the UI isolate.**

The app opens the synchronous `sqlite3` handle in `main()` and calls repository methods directly from builds and view models (`lib/main.dart:21`, `lib/core/data/local_database.dart:43`). There is no background database worker in this implementation. Awaiting a wrapper does not move its synchronous SQL work off the UI isolate. Long queries can therefore freeze interaction, rather than only delay a loading indicator.

Fix expensive queries first, then introduce one background database owner with asynchronous repository boundaries. Keep whole posting transactions in that owner; do not split a transaction across unrelated worker calls or share a handle unsafely. This fits the current feature repositories and ChangeNotifier view models. The [sqlite3 package documentation](https://pub.dev/packages/sqlite3) recommends a background isolate for most apps.

**5. High in reports and vouchers: repeated queries multiply the scan cost.**

For each sales/purchase report row, `ReportsRepository.table()` looks up a party and checks cancellation; it checks cancellation again while computing the total (`lib/features/reports/data/reports_repository.dart:246`). A report with R rows performs roughly two R-sized sets of document searches, in addition to party lookups. Without a source index, that can approach R × total-document-count work, even for a short report period.

Finance allocation preview loads every sale/purchase for every party before filtering one party (`lib/features/finance/data/finance_repository.dart:185`). The voucher screen independently loads/filter/checks outstanding invoices, then computes the preview (`lib/features/finance/presentation/finance_page.dart:248`). Adding a source index fixes the individual history scan but does not remove these full reads or repeated calls.

Use party-scoped SQL, join party names, and compute allocation/return/reversal aggregates once per page/report. Scope grouped subqueries to the relevant invoice IDs rather than accidentally aggregating every historical allocation for a ten-row screen. Avoid duplicate reads for report display and report totals.

**6. Medium: posting time grows with cash-account history.**

`PostingEngine.insert()` calls `validateCash()`, which sums journal history for every cash account on every posting (`lib/features/accounting/data/posting_engine.dart:63`). Its existing account index narrows the rows, but computing SUM still visits the matching entries. `FinanceRepository.accounts()` and overview totals also recalculate balances from history.

The benchmark isolates this validation cost; it does not measure a complete commit. First consolidate duplicate balance queries and consider restricting validation to affected cash accounts where existing invariants permit. If real-device measurements still justify it, introduce transactionally maintained account totals with a reconciliation check against the journal. Treat balance caching as accounting logic requiring focused tests, including reversals, failed writes, restores, and migrations. Current stock already uses this kind of current-balance table.

**7. Medium: large backups amplify CPU, memory, and disk use.**

With an available external backup directory, any changed revision can trigger a complete backup without the local hourly interval (`lib/features/backup/data/backup_service.dart:99`). Each backup snapshots the whole database, reads it into memory, encrypts it, encodes ciphertext in base64 JSON, decrypts it for verification, and runs integrity/foreign-key checks (`:135`). These safeguards are valuable, but work and peak memory grow with database size. A Future return type does not establish that encoding or validation runs in a worker.

Only the primary output directory is pruned to 48 automatic backups (`:166`, `:185`); separate external copies accumulate. Base64 alone adds roughly one third to ciphertext size, before JSON overhead. For illustration, 48 copies of a 300 MB database would consume about 19.2 GB in decimal units before overhead; this is arithmetic, not a measured database size.

Coalesce frequent external-backup requests with a bounded delay, preserve launch/resume/reconnect delivery, and apply explicit retention to external copies too. Keep encryption and verification, move heavy work off the UI isolate, and measure peak memory and recovery time with file-backed fixtures. No backup timing or memory profile was performed in this audit.

**8. Medium for heavy receiving/return workflows: cost corrections live inside purchase JSON.**

`ReturnsRepository.costCorrection()` selects and decodes all purchase documents carrying cost adjustments, looking for one invoice/product inside a nested JSON map (`lib/features/returns/data/returns_repository.dart:32`). It can repeat per return line. Cancellation checks use `json_each` over similar maps. Indexing document kind narrows the set but does not index the dynamic invoice/product links. Receipt finalization also reads historical product movements; the proposed product index helps that path.

Initially batch cost-correction reads per operation. If this workflow is common at scale, add a relational cost-adjustment table keyed by invoice/product/adjusting document, with a carefully tested backfill while preserving posted document snapshots. This path was inspected, not exercised by the synthetic sales/receipts benchmark.

## Safeguards to retain and routine maintenance

The app already uses transactional posting (`BEGIN IMMEDIATE`, rollback on failure), foreign keys, nonnegative stock/value constraints, integer money, unique document/request IDs for retry lookup, WAL with FULL synchronization, online SQLite snapshots, and backup validation. Current stock lookups use a primary key instead of rebuilding quantities from movement history. These are useful foundations; the performance findings do not justify discarding them.

Keep FULL synchronization for durability unless a separately evaluated product decision changes it. WAL already checkpoints automatically by default; absence of a manual checkpoint loop is not itself a defect. SQLite documents [WAL checkpointing and synchronization](https://sqlite.org/wal.html). Consider lightweight [PRAGMA optimize](https://www.sqlite.org/pragma.html#pragma_optimize) after index migrations and periodically for a long-lived connection. No optimize/ANALYZE maintenance was found in the application.

Monitor query duration, row counts, main/WAL file size, free disk space, backup duration, and retained backup storage. Free space helps SQLite and backup operations complete; it does not replace query fixes. Do not delete accounting history or run frequent VACUUM as a substitute for indexes and bounded queries.

## Implementation sequence

1. Add the justified indexes through a tested migration and switch barcode lookup to its existing unique index.
2. Move invoice/catalog/party paging, counts, and party-specific finance filtering into SQL; batch report status/name reads.
3. Put database and backup CPU work behind asynchronous worker boundaries, preserving transaction ownership.
4. Tune cash-balance summaries, cost-correction relations, and backup retention based on measured target-device workloads.

Acceptance should include a file-backed database on the supported desktop hardware, both fresh install and schema-2 upgrade, restored older backups, and large histories. Check query plans and UI frame responsiveness alongside correctness. The generated in-memory measurements below establish problems and candidate improvements, not production acceptance.

## Measurements

Candidate-index comparisons change only the disposable schema, leaving production repository code unchanged; improvements therefore do not include pagination, background work, or query batching. Times below are milliseconds, rounded for readability.

| Production path | 10k documents: current / indexes | 50k documents: current / indexes | 100k documents: current / indexes |
| --- | ---: | ---: | ---: |
| Latest five dashboard invoices | 341.44 / 0.16 | 3,453.56 / 0.16 | 12,424.84 / 0.16 |
| Single-day sales report, fixed 900 rows | 564.63 / 16.18 | 4,326.18 / 14.69 | 11,924.27 / 15.92 |
| Invoice list load plus dues for ten entries | 73.09 / 72.64 | 362.35 / 344.96 | 736.73 / 693.42 |
| Allocation preview for one party | 95.89 / 70.57 | 578.04 / 356.39 | 1,321.08 / 689.94 |
| Available credit sources for one party | 6.19 / 0.10 | 192.00 / 0.39 | 959.47 / 0.88 |
| Remaining balance for one invoice | 0.33 / 0.02 | 2.28 / 0.03 | 6.40 / 0.02 |
| History for one product, ten matching moves | 0.28 / 0.03 | 1.30 / 0.03 | 2.59 / 0.03 |

The invoice list contains 9,000 / 45,000 / 90,000 sales respectively, even though the screen displays ten. That is why indexes alone leave approximately 0.69 seconds of synchronous loading at the largest size.

The dashboard test is `OverviewRepository.recentInvoices()` including its five subsequent due reads, not a measurement of the entire dashboard. The sorting-plan probe in the raw log is the simpler `SELECT d.id ... ORDER BY ... LIMIT 5`; full repository timing includes the original party join and correlated allocation/cancellation queries.

The barcode comparison uses 1,000 / 5,000 / 10,000 products respectively:

| Lookup portion | 1k products | 5k products | 10k products |
| --- | ---: | ---: | ---: |
| Current full-catalog decode and barcode search | 7.88 | 31.51 | 65.18 |
| Direct query using existing barcode index | 0.005 | 0.003 | 0.005 |

The direct query measurement returns the raw matching row; a complete replacement would also decode that one Product and apply the existing checks. This is evidence for removing the catalog-wide read, not a promised end-to-end scan latency.

Cash validation alone increased from 1.32 ms to 7.96 ms to 16.29 ms. Seven-day activity increased from 11.34 ms to 40.16 ms to 81.51 ms; candidate-index timing for that activity path was not collected. These are separate from the dashboard latest-five measurement.

The harness completed successfully (`02:16 +1: All tests passed!`). It is a measurement harness with fixture-integrity checks, not a permanent regression suite or proof that proposed production changes are correct. The removed source was preserved at `/tmp/dept-database-scale-audit-test.dart` for this local session; reproducing it requires placing it under `test/` and running the command above.
