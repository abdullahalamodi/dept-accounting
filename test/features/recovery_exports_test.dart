import 'dart:io';

import 'package:dukan_app/app/dependencies.dart';
import 'package:dukan_app/core/data/local_database.dart';
import 'package:dukan_app/features/auth/data/auth_models.dart';
import 'package:dukan_app/features/auth/data/passwords.dart';
import 'package:dukan_app/features/reports/data/export_service.dart';
import 'package:excel/excel.dart' as x;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Encrypted database backup restores shop, login, and balances onto a fresh installation', () async {
    final source = AppDependencies(LocalDatabase.memory()),
        restored = AppDependencies(LocalDatabase.memory());
    final directory = await Directory.systemTemp.createTemp(
      'dukan-recovery-check-',
    );
    try {
      final key = Passwords.token(32);
      await source.store.setup(
        shop: const Shop(name: 'محل الاستعادة', currency: 'YER'),
        ownerName: 'المالك',
        username: 'owner',
        password: 'safe-password',
        recovery: 'recovery-code',
        backupKey: key,
      );
      source.store.setSetting('backup_directory', directory.path);
      source.finance.openAccount('1100', 2000000);
      final file = await source.backups.backup();
      final bytes = await File(file).readAsBytes();
      final info = await restored.backups.inspect(bytes, key);
      expect(info.shop.name, 'محل الاستعادة');
      await restored.backups.restoreFresh(bytes, key);
      await restored.store.login('owner', 'safe-password');
      expect(restored.engine.balance('1100'), 2000000);
      expect(restored.store.shop!.currency, 'YER');
      expect(restored.store.setting('backup_directory'), isNull);
    } finally {
      for (final d in [source, restored]) {
        d.backups.dispose();
        d.store.dispose();
        d.store.database.close();
      }
      await directory.delete(recursive: true);
    }
  });
  test('Arabic reports serialize as A4, thermal PDF, and a real RTL Excel workbook', () async {
    final service = ExportService(),
        shop = const Shop(name: 'دكان تجريبي', currency: 'YER');
    final report = ReportTable(
      title: 'فاتورة تجريبية',
      columns: ['الصنف', 'الكمية', 'القيمة'],
      rows: [
        ['مصباح', '2', '3,000'],
      ],
      summary: {'الإجمالي': '3,000 ر.ي'},
    );
    for (final thermal in [false, true]) {
      final pdf = await service.reportPdf(shop, report, thermal: thermal);
      expect(String.fromCharCodes(pdf.take(4)), '%PDF');
      expect(pdf.length, greaterThan(1000));
    }
    final excelBytes = service.reportExcel(shop, report);
    final workbook = x.Excel.decodeBytes(excelBytes);
    expect(workbook['التقرير'].isRTL, isTrue);
    expect(workbook['التقرير'].rows[4][0]!.value.toString(), 'مصباح');
  });
}
