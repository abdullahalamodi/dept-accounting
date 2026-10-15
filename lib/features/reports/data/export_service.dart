import 'package:excel/excel.dart' as x;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/numbers.dart';
import '../../auth/data/auth_models.dart';
import '../../invoices/data/document.dart';

class ReportTable {
  const ReportTable({
    required this.title,
    required this.columns,
    required this.rows,
    this.subtitle = '',
    this.summary = const {},
  });
  final String title, subtitle;
  final List<String> columns;
  final List<List<String>> rows;
  final Map<String, String> summary;
}

class ExportService {
  Future<Uint8List> reportPdf(
    Shop shop,
    ReportTable report, {
    bool thermal = false,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf'),
    );
    final document = pw.Document(title: report.title, author: shop.name);
    final green = PdfColor.fromHex('#17654D');
    final format = thermal
        ? PdfPageFormat(80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm)
        : PdfPageFormat.a4;
    document.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: pw.EdgeInsets.all(thermal ? 10 : 32),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        maxPages: 1000,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Text(
              shop.name,
              style: pw.TextStyle(
                fontSize: thermal ? 16 : 22,
                color: green,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            if (shop.address.isNotEmpty)
              pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9)),
            if (shop.phone.isNotEmpty)
              pw.Text(shop.phone, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 12),
            pw.Text(
              report.title,
              style: pw.TextStyle(
                fontSize: thermal ? 12 : 17,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text(report.subtitle, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 12),
          child: pw.Text(
            'دكّان · ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
        build: (context) => [
          if (thermal) ...[
            for (final row in report.rows)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < row.length; i++)
                      pw.Text(
                        '${report.columns[i]}: ${row[i]}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    pw.Divider(color: PdfColors.grey300),
                  ],
                ),
              ),
          ] else
            pw.TableHelper.fromTextArray(
              headers: report.columns.reversed.toList(),
              data: report.rows.map((r) => r.reversed.toList()).toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: pw.BoxDecoration(color: green),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerRight,
              cellPadding: const pw.EdgeInsets.all(7),
              oddRowDecoration: const pw.BoxDecoration(
                color: PdfColors.grey100,
              ),
              border: pw.TableBorder.all(color: PdfColors.grey300, width: .4),
            ),
          pw.SizedBox(height: 16),
          for (final entry in report.summary.entries)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Text(
                '${entry.key}: ${entry.value}',
                style: pw.TextStyle(
                  fontSize: thermal ? 10 : 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
    return document.save();
  }

  Uint8List reportExcel(Shop shop, ReportTable report) {
    final excel = x.Excel.createExcel();
    excel.rename('Sheet1', 'التقرير');
    final sheet = excel['التقرير'];
    sheet.isRTL = true;
    sheet.appendRow([x.TextCellValue(shop.name)]);
    sheet.appendRow([x.TextCellValue(report.title)]);
    sheet.appendRow([x.TextCellValue(report.subtitle)]);
    sheet.appendRow(report.columns.map(x.TextCellValue.new).toList());
    for (final row in report.rows) {
      sheet.appendRow(row.map(x.TextCellValue.new).toList());
    }
    for (final e in report.summary.entries) {
      sheet.appendRow([x.TextCellValue(e.key), x.TextCellValue(e.value)]);
    }
    for (var i = 0; i < report.columns.length; i++) {
      sheet.setColumnWidth(i, i == 0 ? 30 : 24);
    }
    for (var c = 0; c < report.columns.length; c++) {
      sheet
          .cell(x.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 3))
          .cellStyle = x.CellStyle(
        bold: true,
        backgroundColorHex: x.ExcelColor.fromHexString('#17654D'),
        fontColorHex: x.ExcelColor.white,
      );
    }
    // excel 4 creates/parses worksheet XML on first encoding, resetting its view.
    excel.encode();
    sheet.isRTL = true;
    return Uint8List.fromList(excel.encode()!);
  }

  ReportTable document(Shop shop, Document doc, {String? party, int? due}) {
    final currency = shop.currencyLabel;
    return ReportTable(
      title: '${doc.label} · ${doc.number}',
      subtitle:
          '${doc.date}${party == null ? '' : ' · $party'}\n${doc.notes}${doc.reason.isEmpty ? '' : '\nالسبب: ${doc.reason}'}',
      columns: const [
        'الصنف',
        'الوحدة',
        'الكمية',
        'سعر الوحدة',
        'الخصم',
        'القيمة',
      ],
      rows: [
        for (var i = 0; i < doc.lines.length; i++)
          [
            doc.lines[i].name,
            doc.lines[i].unit,
            Numbers.format(doc.lines[i].quantity, decimals: 3),
            Numbers.format(doc.lines[i].price),
            Numbers.format(doc.lines[i].discount),
            Numbers.format(
              ['sale_return', 'purchase_return'].contains(doc.kind)
                  ? doc.extra['returns'][i]['value'] as int
                  : doc.lines[i].total,
            ),
          ],
      ],
      summary: {
        if (doc.discount > 0)
          'خصم الفاتورة': '${Numbers.format(doc.discount)} $currency',
        if (doc.shipping > 0)
          'الشحن': '${Numbers.format(doc.shipping)} $currency',
        'الإجمالي': '${Numbers.format(doc.total)} $currency',
        if (doc.payments.isNotEmpty)
          'المدفوع / الرد النقدي': '${Numbers.format(doc.paid)} $currency',
        if (due != null) 'المتبقي': '${Numbers.format(due)} $currency',
      },
    );
  }

  Future<void> printReport(
    Shop shop,
    ReportTable report, {
    bool thermal = false,
  }) async {
    final bytes = await reportPdf(shop, report, thermal: thermal);
    await Printing.layoutPdf(name: report.title, onLayout: (_) => bytes);
  }

  Future<void> share(
    Shop shop,
    ReportTable report, {
    bool thermal = false,
  }) async {
    final bytes = await reportPdf(shop, report, thermal: thermal);
    await Printing.sharePdf(bytes: bytes, filename: 'dukan-document.pdf');
  }

  Future<void> savePdf(Shop shop, ReportTable report) async {
    await FilePicker.saveFile(
      fileName: 'dukan-report.pdf',
      bytes: await reportPdf(shop, report),
    );
  }

  Future<void> saveExcel(Shop shop, ReportTable report) async {
    await FilePicker.saveFile(
      fileName: 'dukan-report.xlsx',
      bytes: reportExcel(shop, report),
    );
  }
}
