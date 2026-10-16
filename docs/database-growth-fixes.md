# Database growth fixes

Implementation started 2026-10-16, following [the original audit](database-growth-audit-2026-10-16.md).

The application has zero users. The owner requested no new migrations. Indexes and the cost-adjustment relation are added to initial creation; the schema version remains 2. Existing development databases are not reset or silently altered. Use a fresh development database for the revised schema. This supersedes the original audit's migration recommendation.

## First batch completed

- Initial indexes cover document source/kind checks, dates, kind/date sorting, kind/insertion-order sorting, allocation payment IDs, stock product IDs, and stable product/party name sorting. The kind-only index supports rowid ordering, which the kind/date index cannot replace.
- Barcode lookup uses the existing UNIQUE index and decodes one product. Trimming, missing/empty barcode handling, active/service eligibility, quantity increments, and seller price masking are preserved.
- Invoice lists use SQL counts and bounded pages. They return summaries with party names and invoice-scoped indexed due calculations, without deserializing invoice lines.
- Catalog and party lists use SQL filters/counts/page limits. Stock quantities are joined, including low-stock filtering. Results are read once per build. Detail lookup uses primary keys.
- Invoice product selection queries five eligible products at a time instead of loading the catalog.
- Financial history, stock movements, ledger entries, and party statements return bounded pages. Statement running balances cover the full ordered history before page limits. Exports retain complete requested history.
- Allocation previews query one party/kind, exclude settled invoices, and preserve oldest paper date/posted time ordering. Finance and credit UIs reuse returned dues and candidates.
- Document reports fetch party names and cancellation status in the report query; totals reuse that status. Reports project displayed fields instead of deserializing invoice lines.
- Literal substring search is preserved with `instr`; `%` and `_` remain literal. Connection-local `app_lower` preserves Dart's Unicode case behavior. Search counts still scan matching history.

## Verification

- `dart analyze`: no issues.
- Full `flutter test --no-pub --reporter expanded`: 65 tests passed after background ownership, including file-backed permissions/rollback/restore and manual allocation values retained across page changes.
- Focused coverage includes fresh-schema query plans, barcode eligibility and price permissions, paging/search/filters, dues after payments/returns/cancellation, allocation order, and statement balances across pages.
- Native macOS debug and profile probes now exercise an isolated synthetic database. Debug hot reload and restart succeeded. Results and limits are below; normal shop files were never opened by the probes.

The disposable scale benchmark reused the original 10k/50k/100k-document fixtures and production repository methods, with a warm-up and three repetitions (median). Foreign-key and quick integrity checks passed. [Raw output](database-growth-followup-2026-10-16.txt) is retained. Temporary source: `/tmp/dept-database-scale-followup-test.dart`; removed from the permanent test suite.

| Path at 100k documents | Original | First batch |
| --- | ---: | ---: |
| Ten invoice rows including dues | 736.73 ms | 1.50 ms |
| Latest five dashboard invoices | 12,424.84 ms | 0.52 ms |
| Sales report with 900 rows | 11,924.27 ms | 2.71 ms |
| Party allocation preview | 1,321.08 ms | 3.45 ms |
| Catalog barcode search / single-product lookup | 65.18 ms | 0.026 ms |

The replacement barcode measurement includes one product decode and repository visibility, but neither barcode measurement covers hardware input, draft persistence, or rendering. Invoice substring search for `DOC-99` still took about 95 ms at 100k documents. Measurements use SQLite 3.53.4 in memory on this development Mac; file-system, target-device, and UI responsiveness acceptance remain outstanding.

## Second batch completed

- Posting checks cash balances only for accounts with a net outgoing change. Untouched and incoming accounts cannot become negative through that post. Account displays and overview summaries consolidate their balance queries; the underlying journal remains the source of truth. Affected-account sums still grow with that account's history, so background execution remains necessary.
- Receipt finalization writes indexed `cost_adjustments` rows in the same transaction as its document, journal, and stock corrections. Original posted JSON snapshots remain unchanged. Returns load one invoice's adjustment totals and prior returns in batches; the editor reuses that history until the store revision changes. Cancellation checks use the relation instead of scanning purchase JSON. Regression coverage includes positive/negative cost corrections, duplicate product lines, partial returns before/after finalization, and idempotent finalization.
- External automatic backups coalesce writes for five minutes from the first pending change, rather than postponing indefinitely while work continues. Launch/reconnect deliver outstanding changes; resume and graceful shutdown flush pending work, including a request arriving during another check. Local hourly scheduling remains. Both distinct destinations keep 48 automatic copies; manual backups remain untouched.
- Backup preparation, decryption, authentication, SQLite integrity/foreign-key checks, and inspection run in an isolate. The UI streams selected files into a stable temporary copy, including picker URIs without a local path, then passes paths to the worker. Copying to final destinations retains flushed partial-file replacement. Busy/shutdown tracking includes temporary-file cleanup.
- New file archives use format 2: `DEPTBAK2` (8 bytes), a random 12-byte nonce, ChaCha20-Poly1305 ciphertext, and a 16-byte MAC. The magic is authenticated as additional data. The existing cryptography package performs the cipher/MAC operations. File creation and verification stream bounded chunks; output is exactly database size plus 36 bytes. Wrong keys, header/nonce/ciphertext/MAC corruption, and truncation are rejected; failed decrypt output is removed. The extension and recovery key remain unchanged.
- Version-1 AES-GCM JSON envelopes, including the former application identity, remain readable. Legacy JSON restoration still buffers that envelope inside the worker; newly generated automatic backups use the bounded format.

### File-backed backup profile

The first candidate used the package's AES stream API. Inspection and measurement showed that implementation buffers the entire message; the 64 MiB fixture added about 354 MB to peak process RSS. It was replaced with the package's incremental ChaCha20-Poly1305 state before acceptance.

The accepted profile uses valid, disposable SQLite files with 16/64 MiB of synthetic BLOB payload. `BackupFiles.prepare()` encrypts, decrypts, and checks integrity/foreign keys. A 25 ms main-isolate timer samples process RSS and event-loop gaps. This includes process/isolate/SQLite overhead and is not a heap attribution or a rendered-frame measurement. [Raw output](database-backup-profile-2026-10-16.txt); temporary source retained at `/tmp/dept-backup-scale-test.dart`.

| Payload | Database size | Archive overhead | Complete preparation | Additional peak RSS | Largest timer interval |
| --- | ---: | ---: | ---: | ---: | ---: |
| 16 MiB | 17,018,880 bytes | 36 bytes | 1.09 s | 10.37 MB | 29.49 ms |
| 64 MiB | 67,416,064 bytes | 36 bytes | 4.09 s | 10.32 MB | 27.13 ms |

These are development Flutter-test measurements on this Mac. Actual USB throughput, native folder-picker permissions, full snapshot/copy/restore durations, Windows behavior, and rendered UI frames still require runtime acceptance.

## Third batch completed

- Unit/category fields and conversions use primary-key lookups. Resolving/saving a reference no longer loads all references and recounts every linked product. Management lists count references separately and compute product counts only for the displayed page; pickers omit unused product counts.
- Customers, suppliers, references, products, and credit sources use a shared paged selection dialog with loading, error, and retry states. Party eligibility and reference activity/exclusions are applied in SQL. A shared ChangeNotifier query model ignores stale responses and results arriving after disposal. These callbacks are prepared for asynchronous execution; `Future.sync` itself does not offload SQL, and database ownership work is still pending.
- Draft lists are bounded and indexed by owner/kind/update time. Receipt links are projected with the page instead of loading each draft again. A shared panel supports resume actions without inserting empty-panel spacing. Pending receiving uses joined supplier names and header projections in a bounded page.
- Outstanding invoices use a five-row page in both allocation entry points. Manual selections remain in the view model across pages. Automatic allocation uses an ordered SQL cumulative sum across the complete eligible set and returns only actual allocations, preserving oldest-paper-date/posted-time ordering. It is independent of the displayed page.
- Credit source availability is calculated in SQL, including original/opening/return limits, cancellations, and existing use. Allocation validates one source by ID; refunds use an ordered SQL allocation plan instead of decoding all historical source documents. Pickers return source summaries. Completed/used sources are excluded before returning rows.
- Focused checks cover Unicode/literal searches, roles and inactive exclusions, reference counts, draft ownership/kind separation, receipt finalization, allocations/refunds spanning multiple pages, stale query results, and actual editor input retention across pages.

## Fourth batch completed

- Main startup now opens one persistent database worker. It owns the writable connection, posting repositories, and serial task queue. The UI retains a separate `query_only` connection for small indexed lookups (settings, names, product details, barcode). All writes and growing list/report/balance queries use typed feature tasks. Native SQLite handles never cross isolates.
- Permission checks execute inside the queued operation after reloading the stored user by ID. The session epoch prevents a late reply from signing a logged-out user back in. Existing `BEGIN IMMEDIATE` transaction boundaries, rollback, idempotent request IDs, integer accounting, WAL, and FULL durability remain.
- Shared asynchronous query state ignores stale/disposed replies and executes only the newest pending read after an active read. Lists retain their current view while replacements load, preserving filter focus; loading, failure, and retry use shared design-system components. Input and navigation on work forms are blocked during commands.
- Draft edits coalesce for 250 ms; explicit saves/navigation await persistence. Each queued posting operation removes its draft before replying; posted IDs cannot recreate drafts. Cash selectors query account identity without repeatedly summing history.
- Period reports load ten formatted rows with complete SQL totals/counts. Aggregates cache by revision and period. Explicit exports request the complete report. The dashboard returns four low-stock rows plus the complete alert count.
- A temporary differential check compared all ten report kinds, complete rows/columns/totals and concatenated pages against the previous implementation across two date ranges. It passed before the previous implementation and comparison harness were removed. Permanent coverage checks page/full-report consistency, cache invalidation, and complete stock counts.
- Dashboard activity now starts with the indexed date window, joins journal rows by document, and aggregates local calendar days in SQL. It returns at most the requested 7/30 day buckets, rather than materializing the period's journal rows in Dart. A file-backed 100k-document benchmark measured the former SQL fetch alone at **99.62 ms**, versus **1.79 ms** including replacement repository mapping; warmed medians of three. Plans confirm `documents_posted` followed by `journal_document`. [Raw output](database-cash-activity-profile-2026-10-16.txt).
- The same benchmark measured a cash balance over 100k account entries at **18.73 ms** and affected outgoing-cash validation at **18.70 ms**. These operations now run in the worker. Maintained cash totals are deferred: the measurement does not justify adding accounting reconciliation complexity yet.
- Snapshots, restoration, and pre-upgrade copies explicitly use SQLite backup `nPage: -1` inside background execution. Inspection of sqlite3 3.5.2 found that its default copies five pages and sleeps 250 ms between steps: a roughly 108 MB file can otherwise take over 20 minutes. Legacy-name transfer also runs in an isolate. A 4 MiB file-worker regression requires backup/restore to finish within a generous ten-second bound.
- Restore has an exclusive queue barrier across the pre-restore safety backup and replacement. Earlier commands finish before the safety copy; commands arriving during maintenance wait and recheck the resulting session. Automatic checks avoid maintenance. Shutdown drains backups and pending worker requests before closing both connections.
- The executor keeps a bounded record of the latest 20 operations taking at least 50 ms (fixed operation name, worker duration, failure flag), plus a completion count. It records no query arguments or credentials. Planner maintenance runs at startup with `PRAGMA optimize=0x10002`, after 1,000 changes, on the next request after a day, and on close. The startup/periodic policy follows [SQLite's guidance for long-lived connections](https://www.sqlite.org/lang_analyze.html#periodically_run_pragma_optimize).

### Native macOS acceptance

The disposable harness used the actual `DeptAccountingApp`, production repositories/tasks and backup service on an Apple M2 Max, SQLite 3.53.4, in debug and then profile mode. Automatic backups remained active. The fresh profile fixture contained **100,001 documents**, **400,002 journal rows**, 10,001 products, and 100 parties, occupying **107,741,184 bytes** before the test sale. Data is synthetic; accounting correctness is covered separately by workflow tests.

All nine exercised routes (catalog, sales, finance, reports, parties, inventory, receiving, settings, home) rendered with no captured Flutter/async errors. The route harness waited 900 ms at each stop; those wait durations are **not** page-render latency measurements.

| Profile-mode observation | Result |
| --- | ---: |
| Twenty repeated barcode additions, median / maximum | 46 / 814 microseconds |
| Posting the resulting 20-unit sale, including worker round trip | 160 ms |
| Sale-period page, including queue round trip | 1.24 ms |
| Complete local encrypted backup and verification | 8.45 s |
| Existing-store restore, including safety backup and login | 13.89 s |
| Fresh-store restore and login | 5.72 s |
| Recorded frames after initial home warm-up | 778 |
| Frame build, 95th percentile / maximum | 1.28 / 7.75 ms |
| Raster, 95th percentile | 1.61 ms |
| Largest 25 ms main-isolate timer interval | 35.61 ms |

Posting removed its draft. Restore logged out, removed a subsequently posted sale, and preserved the snapshot's cash balance. Both restored stores passed `quick_check` and foreign-key checks. The disposable databases were deleted. [Raw profile observations](database-runtime-profile-2026-10-16.txt). Temporary sources are retained at `/tmp/dept-native-runtime-probe.dart` and `/tmp/dept-cash-scale-test.dart`, outside the app and permanent suite.

The whole exercise's process RSS rose from about 159 MB to 308 MB, including fixture seeding, UI/font caches, SQLite connections, and backup isolates. This is not backup heap attribution. The separate streaming-backup profile above remains the bounded-memory evidence. The native profile preceded the final dashboard SQL aggregation; that last query change has its separate file-backed comparison and workflow tests. A final fresh-store native smoke check also exercised cash opening, barcode draft/post, finance, document details, reports, and home after the final changes: cash was 11,000 minor units as expected, no runtime errors were captured, and hot reload succeeded. Its source is retained at `/tmp/dept-final-native-smoke.dart`.

## Ongoing limits and watch points

- Literal substring search/counts, full-history accounting summaries, and very deep `OFFSET` pages still grow with the amount of matching history. They execute in the worker. Consider a search index, cursor browsing, or maintained accounting totals only when a representative workload justifies the extra semantics and consistency rules.
- Explicit whole-history exports still materialize the requested report and output document. Large exports have proportional memory/storage cost; paginated browsing does not impose an export limit.
- A full backup still copies the complete database. Coalescing, streaming encryption, and retention control its frequency, memory, and storage; sufficient free space remains necessary.
- Native acceptance covers this Mac and local storage. Physical scanner behavior, USB throughput/folder permissions, and Windows runtime acceptance remain platform checks. These measurements do not establish a universal safe maximum record count.
- No new migration or developer-database reset was added. The revised initial schema requires a fresh development database, as requested for this zero-user application.
