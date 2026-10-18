# Mobile UI design reference

Arabic RTL HTML/CSS/JavaScript reference for the Dept Accounting mobile experience. The visual direction was reviewed and approved in the design discussion; the expanded feature screens remain available for further review. This is a design reference, not the Flutter implementation or an accounting specification.

## Open or run

Open [index.html](index.html) directly in a browser. All assets are local, so no dependency installation or internet connection is needed.

Alternatively, run **from the repository root**:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory prototypes/mobile-sales
```

Open [the local preview](http://127.0.0.1:8765/). Stop the server with `Ctrl+C`. If port 8765 is already in use, choose another port in both the command and the URL.

On desktop, the demo includes a phone frame and shortcuts for exploring features. At widths of 700 px and below, the interface fills the screen. Start with **فاتورة بيع جديدة**, use the bottom navigation, or open **المزيد** to reach the other sections.

## Reference contents

- Sales, product selection, item editing, discounts, payments, drafts, document review, and returns.
- Products and services, shared product symbols, units, opening stock, stock movements, and inventory adjustments.
- Customers and suppliers, statements, purchases, quick receiving, and supplier invoice settlement.
- Finance, accounts, vouchers, allocation previews, reports, store settings, users, and backup/restore previews.

Products use **one generic product symbol**, not individual product icons or images. Keep the approved Arabic typography, green palette, readable record lists, focused editing sheets, and items-then-payment flow consistent when extending the reference.

## Editing and limits

Edit `index.html` for the preview shell, `styles.css` for styling, `app.js` for the original sales flow, and `features.js` for the expanded features. Refresh the browser after saving. Keep prototype changes in this folder; implement production behavior separately using the Flutter design system and feature architecture.

All data and operations are illustrative and in memory. Refreshing resets records, drafts, settings, and simulated backups. The demo does not connect to the application database or perform real payments, backups, authentication, or camera scanning. Financial calculations are simplified; the trial balance and ledger include explicitly labeled sample data. Browser printing is available, but production exports and accounting acceptance require separate implementation and verification.

Fonts and colors reuse the Flutter design system. IBM Plex Sans Arabic is included under the SIL Open Font License (see assets). Lucide 0.468.0 is included locally with its license banner. No runtime network requests are required.
