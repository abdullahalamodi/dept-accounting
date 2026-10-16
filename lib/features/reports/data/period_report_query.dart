import '../../../core/date_time.dart';
import '../../../core/numbers.dart';
import '../../invoices/data/document.dart';

typedef ReportRow = Map<String, Object?>;

class PeriodReportQuery {
  const PeriodReportQuery({
    required this.title,
    required this.sql,
    required this.arguments,
    required this.order,
    required this.columns,
    required this.format,
    this.totals = const {},
  });
  final String title, sql, order;
  final List<Object?> arguments;
  final List<String> columns;
  final List<String> Function(ReportRow) format;
  final Map<String, String> totals;
}

PeriodReportQuery periodReportQuery(String kind, String start, String end) {
  String text(ReportRow row, String key) => row[key] as String;
  int number(ReportRow row, String key) => row[key] as int;
  String money(ReportRow row, String key) => Numbers.format(number(row, key));
  switch (kind) {
    case 'profit':
      return PeriodReportQuery(
        title: 'الأرباح والخسائر',
        sql: '''SELECT a.code,a.name,a.kind,COALESCE(SUM(j.debit-j.credit),0) AS amount
          FROM accounts a LEFT JOIN (SELECT j.* FROM journal j JOIN documents d ON d.id=j.document_id WHERE d.posted_at >= ? AND d.posted_at < ?) j ON j.account=a.code
          WHERE a.kind IN ('income','expense') GROUP BY a.code''',
        arguments: [start, end],
        order: 'code',
        columns: ['الحساب', 'الاسم', 'القيمة'],
        format: (r) => [
          text(r, 'code'),
          text(r, 'name'),
          Numbers.format(
            number(r, 'amount') * (r['kind'] == 'income' ? -1 : 1),
          ),
        ],
        totals: {
          'الإيرادات': "COALESCE(SUM(CASE WHEN kind='income' THEN -amount ELSE 0 END),0)",
          'المصروفات والتكلفة': "COALESCE(SUM(CASE WHEN kind='expense' THEN amount ELSE 0 END),0)",
          'صافي النتيجة': 'COALESCE(SUM(-amount),0)',
        },
      );
    case 'stock':
      return PeriodReportQuery(
        title: 'المخزون وقيمته في نهاية الفترة',
        sql: r'''SELECT p.id,json_extract(p.data,'$.name') AS name,COALESCE(SUM(m.quantity),0) AS quantity,COALESCE(SUM(m.value),0) AS value
          FROM products p LEFT JOIN (SELECT m.* FROM stock_moves m JOIN documents d ON d.id=m.document_id WHERE d.posted_at < ?) m ON m.product_id=p.id
          WHERE json_extract(p.data,'$.service')=0 GROUP BY p.id''',
        arguments: [end],
        order: 'id',
        columns: ['المنتج', 'الكمية الأساسية', 'القيمة'],
        format: (r) => [
          text(r, 'name'),
          Numbers.format(number(r, 'quantity'), decimals: 3),
          money(r, 'value'),
        ],
        totals: {'قيمة المخزون': 'COALESCE(SUM(value),0)'},
      );
    case 'parties':
      return PeriodReportQuery(
        title: 'أرصدة العملاء والموردين في نهاية الفترة',
        sql: r'''SELECT p.id,json_extract(p.data,'$.name') AS name,j.account,COALESCE(SUM(j.debit-j.credit),0) AS balance
          FROM parties p JOIN journal j ON j.party_id=p.id JOIN documents d ON d.id=j.document_id
          WHERE d.posted_at < ? AND j.account IN ('1200','2100') GROUP BY p.id,j.account''',
        arguments: [end],
        order: 'id,account',
        columns: ['الطرف', 'الحساب', 'المستحق / السالب لصالح الطرف'],
        format: (r) => [
          text(r, 'name'),
          r['account'] == '1200' ? 'عميل' : 'مورد',
          Numbers.format(
            number(r, 'balance') * (r['account'] == '1200' ? 1 : -1),
          ),
        ],
      );
    case 'cash':
      return PeriodReportQuery(
        title: 'حركة الصناديق والبنوك',
        sql: '''SELECT j.id AS position,d.number,d.posted_at,a.name,j.debit,j.credit FROM journal j
          JOIN accounts a ON a.code=j.account JOIN documents d ON d.id=j.document_id
          WHERE a.cash=1 AND d.posted_at >= ? AND d.posted_at < ?''',
        arguments: [start, end],
        order: 'posted_at,position',
        columns: ['المرجع', 'التاريخ', 'الحساب', 'وارد', 'صادر'],
        format: (r) => [
          text(r, 'number'),
          text(r, 'posted_at').substring(0, 10),
          text(r, 'name'),
          money(r, 'debit'),
          money(r, 'credit'),
        ],
      );
    case 'trial':
      return PeriodReportQuery(
        title: 'ميزان المراجعة في نهاية الفترة',
        sql: '''SELECT a.code,a.name,COALESCE(SUM(j.debit),0) AS debit,COALESCE(SUM(j.credit),0) AS credit
          FROM accounts a LEFT JOIN (SELECT j.* FROM journal j JOIN documents d ON d.id=j.document_id WHERE d.posted_at < ?) j ON j.account=a.code GROUP BY a.code''',
        arguments: [end],
        order: 'code',
        columns: ['الرمز', 'الحساب', 'مدين', 'دائن', 'صافي الرصيد'],
        format: (r) => [
          text(r, 'code'),
          text(r, 'name'),
          money(r, 'debit'),
          money(r, 'credit'),
          Numbers.format(number(r, 'debit') - number(r, 'credit')),
        ],
        totals: {
          'إجمالي المدين': 'COALESCE(SUM(debit),0)',
          'إجمالي الدائن': 'COALESCE(SUM(credit),0)',
        },
      );
    default:
      final kinds = switch (kind) {
        'sales' => ['sale'],
        'purchases' => ['purchase'],
        'returns' => ['sale_return', 'purchase_return'],
        'expenses' => ['expense'],
        _ => ['sale', 'purchase'],
      };
      return PeriodReportQuery(
        title: switch (kind) {
          'sales' => 'المبيعات',
          'purchases' => 'المشتريات',
          'returns' => 'المرتجعات',
          'expenses' => 'المصروفات',
          _ => 'المستندات',
        },
        sql:
            '''SELECT d.rowid AS position,d.posted_at,d.number,d.kind,json_extract(d.data,'\$.date') AS date,json_extract(d.data,'\$.total') AS total,
          CASE WHEN d.party_id IS NULL THEN COALESCE(json_extract(d.data,'\$.extra.category'),'') ELSE json_extract(p.data,'\$.name') END AS party,
          EXISTS(SELECT 1 FROM documents r WHERE r.source_id=d.id AND r.kind='reversal') AS cancelled
          FROM documents d LEFT JOIN parties p ON p.id=d.party_id
          WHERE d.posted_at >= ? AND d.posted_at < ? AND d.kind IN (${List.filled(kinds.length, '?').join(',')})''',
        arguments: [start, end, ...kinds],
        order: 'posted_at,position',
        columns: [
          'المرجع',
          'النوع',
          'التاريخ',
          'الطرف / التصنيف',
          'القيمة',
          'الحالة',
        ],
        format: (r) => [
          text(r, 'number'),
          Document.labelFor(text(r, 'kind')),
          formatDocumentDateTime(text(r, 'date')),
          text(r, 'party'),
          money(r, 'total'),
          r['cancelled'] == 0 ? 'معتمد' : 'ملغى',
        ],
        totals: {
          'إجمالي المستندات المعتمدة':
              'COALESCE(SUM(CASE WHEN cancelled=0 THEN total ELSE 0 END),0)',
        },
      );
  }
}
