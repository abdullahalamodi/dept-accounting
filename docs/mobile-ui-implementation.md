# Mobile UI implementation

Implemented against the approved interactive reference in `prototypes/mobile-sales/`, using the existing Flutter design system and live local repositories. The prototype remains a separate sample-data design artifact.

## Presentation and ownership

- Compact windows below the existing 600 px breakpoint use Home, Sales, Products, Finance, and More bottom navigation. More exposes purchases, inventory, receiving, parties, reports, settings, and optional POS according to the signed-in user's permissions.
- The existing desktop sidebar and intermediate-width drawer remain available. Router redirects continue enforcing permissions independently of visible navigation.
- Features keep their existing ChangeNotifier ViewModels and repositories. Invoice state stays in `InvoiceEditorPage`, above the compact/desktop presentation choice, so changing window size preserves the draft.
- `WorkPage` owns scrolling, the compact back header, and its bottom actions. The router does not wrap viewport-owning pages in another scroll view. `DatabaseQuery` preserves bounded viewport height while retaining its existing scroll-content behavior when height is unbounded.
- System Back returns from invoice payment to items, saves drafts when leaving the editor, and returns secondary destinations through More. Ordinary page scrolls carry workspace notices away with their content.

## Feature coverage

| Area | Compact behavior |
| --- | --- |
| Home | Daily sales and authorized profit summary, compact quick actions, activity, recent invoice cards, stock alerts, and the existing startup guide |
| Sales / purchases / POS | Search, saved drafts, readable invoice cards, searchable product sheet, item-editing sheet, review/payment step, split payments, discount, confirmation, and document view |
| Receiving | Pending receipt cards, quick receipt entry, and final supplier invoice with locked received quantities and editable actual costs |
| Products | Search and optional filters, a common product symbol, detail view before editing, prices/units, available stock, opening stock and inventory links |
| Inventory | Searchable stock list, stock/value/cost summary, movement history, and a separate count/adjustment section |
| Parties | Contact and role summary, separate customer/supplier balances, statement, advances, and separate opening/correction controls |
| Finance | Account balances, movement cards, ordinary financial operations, and a separate opening-balance section retaining the existing entry/review/close rules |
| Returns | Existing source-linked quantities, service refunds, damage flags, reason and refund account, with a reachable approval action |
| Reports | Period, result, trial-balance and ledger sections; account cards can open the ledger; existing PDF/Excel/printing services |
| Settings / profile / setup | Existing single-column forms and section selection, compact shared controls and readable audit/user records; existing login, password, backup and setup behavior |

Secondary tabular records use a shared labelled compact presentation; desktop tables retain their columns. Paged queries stay paged. Mobile views do not load a second in-memory copy of the catalog or financial history.

Backup notices show their title in a compact expandable row on phones. Expanding reveals the complete existing message. They remain part of the page scroll.

## Verification

Final local verification (2026-10-18): all 78 tests passed; Dart analysis reported no diagnostics; macOS debug build and hot reload succeeded with no runtime errors. The Android debug APK built successfully. Rendered mobile screens were visually reviewed after the compact notice, filtering and dashboard refinements.

The focused checks in `test/features/mobile_experience_test.dart` cover:

- A real local sale: product selection, fractional quantity editing with keyboard insets, resize to desktop and back, draft save/resume, customer selection, partial payment and posting effects on stock and debt.
- Credit purchase, quick receipt, and final actual-cost settlement; received quantities and supplier identity stay locked during finalization, and stock is not added twice.
- Populated feature routes at 320, 360 and 430 px portrait widths and 568 x 320 landscape, bottom navigation, system Back, keyboard-visible form actions and seller permission redirects.

Run the full regression suite with `flutter test --no-pub`. To also capture rendered phone screens, run:

```sh
flutter test --no-pub --dart-define=MOBILE_CAPTURE_DIR=/private/tmp/dept-mobile-captures test/features/mobile_experience_test.dart
```

Screenshots use real app widgets, bundled fonts and an isolated in-memory shop. They do not modify the user's shop.

Android validation uses `flutter build apk --debug --no-pub`; the result is `build/app/outputs/flutter-apk/app-debug.apk`. No Android device or emulator was connected during this implementation, so physical-device keyboard, system-gesture and print/share plugin behavior still require a device check. macOS build/hot reload and runtime diagnostics are separate from Android device acceptance.
