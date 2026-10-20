# Desktop UI/UX refinement

The desktop presentation retains the existing Arabic identity, typography, palette, business rules, permissions, and local storage. Window widths below 600 px retain the existing phone presentation. Intermediate windows retain the drawer; expanded windows retain the sidebar.

## Shared presentation

- Forms align to the RTL content start and cap at 880 px; simple forms cap at 640 px. Wide data workspaces retain their 1440 px cap.
- Existing tokens provide 24 px desktop page padding, 14 px field gaps, 48 px ordinary controls, and 36 px compact controls. Transaction summaries use 320 px when space permits and stack when needed.
- Form stacks keep standalone desktop actions content-sized. Buttons continue respecting parent constraints, preserving accurate interaction and focus bounds.
- The shared table component keeps pagination and data loading, adds bounded text with full-value tooltips, and uses tighter desktop cells. Phone rows and pagination spacing retain their original presentation.
- Desktop table text actions and exports use light outlines; view/edit/remove icons remain plain. Primary actions remain reserved for the active task.
- Headers wrap their action group within the available width, including narrow desktop windows. Transaction editors keep their final actions in a persistent footer when the viewport is bounded and remain embeddable in scrolling hosts.
- Routine desktop backup guidance expands from a compact status row. Warning states continue showing their full actionable message.

## Screen checklist

| Area | Implemented desktop behavior |
| --- | --- |
| Workspace | Compact branding, consistent content spacing, bounded header actions |
| Overview | Daily sales and authorized profit, quick actions and activity first; expandable setup guide after daily work |
| Catalog | Shared search toolbar, section tabs, bounded product forms with identity/pricing groups and existing advanced unit controls |
| Categories and units | Shared desktop section navigation and compact search toolbar |
| Opening stock | Bounded quantity/value form; existing saved cost and posting restrictions |
| Sales and purchases | Invoice list first; separate drafts tab with outlined resume actions and an explicit empty state |
| Invoice / POS / quick receiving / finalization | Barcode with item controls, payment summary alongside when space permits, persistent total/save/approve footer |
| Parties | Overview and statement before editing; separate balance/settlement section; bounded edit form |
| Finance | Transactions first; separate Accounts and Opening balances sections; bounded account cards and opening forms |
| Finance editor | Existing allocation and payment behavior with a reachable final action footer |
| Inventory | Movement history first; separate adjustment section with a bounded form |
| Returns | Desktop selectable item rows and quantity/service fields with refund summary and approval footer |
| Receiving list | Pending receipts first; separate section for both kinds of receiving drafts |
| Reports | Period / Results / Trial balance / Ledger sections; retained period-report state; bounded account selectors and outlined exports |
| Documents | Existing document actions and confirmations; outlined exports; bounded total/payment summary |
| Settings | Consistent section navigation; bounded shop, preferences, and backup content; content-sized Save |
| Profile | Bounded identity/credential/session sections and secondary desktop logout |
| Dialogs and authentication | Existing bounded dialogs and auth flows retained; shared action and layout behavior verified |

The setup guide opens `/finance?section=opening` on desktop so its account setup action still reaches the intended section. Existing routes and phone setup behavior remain available.

## Verification

Final integration run: **86 tests passed**. Static analysis of `lib` and `test` reported no issues. The macOS debug target built successfully.

The desktop regression suite exercises 26 routes at 600, 900, 1100, 1280, 1440, and 1920 px, with macOS and Windows platform variants. Additional interaction checks cover section switching, retained period-report state, party editing, barcode entry, draft persistence, retained invoice-search text and draft pagination across desktop sections, the product picker, increased text scaling, and reachable final actions.

The updated native macOS dashboard, finance, and settings pages were also inspected and captured after hot reload.

The original checkout and updated app were rendered independently with the existing phone workflow tests. All 18 captured phone PNGs matched byte for byte: home, sales, purchases, receiving, invoice items/payment, products/product, parties, finance, stock/list, returns, documents, reports, settings, profile, and More.

Commands:

```sh
flutter test --no-pub
flutter test --no-pub --dart-define=DESKTOP_CAPTURE_DIR=/path/to/captures test/features/desktop_experience_test.dart
flutter test --no-pub --dart-define=MOBILE_CAPTURE_DIR=/path/to/captures test/features/mobile_experience_test.dart
dart analyze lib test
flutter build macos --debug --no-pub
```

Captured comparisons are local review evidence, not production data fixtures. Windows platform rendering in widget tests does not establish a native Windows build or physical-device acceptance. Native print/share/file-dialog completion remains outside the layout verification; existing export behavior and tests are retained.
