import '../../../core/data/app_store.dart';
import '../../invoices/data/document.dart';
import '../../invoices/data/invoice_repository.dart';

class OverviewDay {
  const OverviewDay(this.date, this.sales, this.profit);
  final DateTime date;
  final int sales;
  final int? profit;
}

typedef OverviewInvoice = ({
  Document document,
  String customer,
  int paid,
  int due,
  bool cancelled,
});
typedef OverviewStock = ({
  String id,
  String name,
  String unit,
  int quantity,
  int minimum,
});

class OverviewRepository {
  OverviewRepository(this.store, this.invoices);
  final AppStore store;
  final InvoiceRepository invoices;

  List<OverviewDay> activity(int days, {DateTime? now}) {
    store.require();
    final today = now ?? DateTime.now();
    final first = DateTime(today.year, today.month, today.day - days + 1);
    final end = DateTime(today.year, today.month, today.day + 1);
    final canManage = store.user!.canManage;
    final rows = store.database.handle.select(
      '''SELECT d.posted_at,j.account,j.debit,j.credit FROM journal j
      JOIN documents d ON d.id=j.document_id
      WHERE d.posted_at >= ? AND d.posted_at < ?
      AND j.account IN (${canManage ? "'4100','4200','5100'" : "'4100','4200'"})''',
      [first.toUtc().toIso8601String(), end.toUtc().toIso8601String()],
    );
    final sales = <DateTime, int>{}, costs = <DateTime, int>{};
    for (final row in rows) {
      final at = DateTime.parse(row['posted_at'] as String).toLocal();
      final day = DateTime(at.year, at.month, at.day);
      final amount = (row['credit'] as int) - (row['debit'] as int);
      final target = row['account'] == '5100' ? costs : sales;
      target.update(day, (n) => n + amount, ifAbsent: () => amount);
    }
    return [
      for (var i = 0; i < days; i++)
        (() {
          final day = DateTime(first.year, first.month, first.day + i);
          final revenue = sales[day] ?? 0;
          return OverviewDay(
            day,
            revenue,
            canManage ? revenue + (costs[day] ?? 0) : null,
          );
        })(),
    ];
  }

  List<OverviewInvoice> recentInvoices() {
    store.require();
    final rows = store.database.handle.select('''
      SELECT d.data,p.data AS party,
      COALESCE((SELECT SUM(amount) FROM allocations WHERE invoice_id=d.id),0) AS paid,
      EXISTS(SELECT 1 FROM documents r WHERE r.source_id=d.id AND r.kind='reversal') AS cancelled
      FROM documents d LEFT JOIN parties p ON p.id=d.party_id
      WHERE d.kind='sale' ORDER BY d.posted_at DESC,d.rowid DESC LIMIT 5
    ''');
    return [
      for (final r in rows)
        (() {
          final doc = DocumentMapper.fromJson(r['data'] as String);
          return (
            document: doc,
            customer: r['party'] == null
                ? 'عميل نقدي'
                : store.decode(r['party'] as String)['name'] as String,
            paid: r['paid'] as int,
            due: invoices.due(doc.id),
            cancelled: r['cancelled'] == 1,
          );
        })(),
    ];
  }

  List<OverviewStock> lowStock() {
    store.require();
    final rows = store.database.handle.select('''
      SELECT p.id,p.data,COALESCE(s.quantity,0) AS quantity FROM products p
      LEFT JOIN stock s ON s.product_id=p.id
      WHERE json_extract(p.data,'\$.active')=1 AND json_extract(p.data,'\$.service')=0
      AND COALESCE(s.quantity,0) <= json_extract(p.data,'\$.minStock')
      ORDER BY COALESCE(s.quantity,0),json_extract(p.data,'\$.name')
    ''');
    return [
      for (final r in rows)
        (() {
          final p = store.decode(r['data'] as String);
          return (
            id: r['id'] as String,
            name: p['name'] as String,
            unit: p['unit'] as String,
            quantity: r['quantity'] as int,
            minimum: p['minStock'] as int,
          );
        })(),
    ];
  }
}
