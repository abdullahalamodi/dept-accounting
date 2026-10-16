import 'package:dept_accounting/features/finance/presentation/finance_view_model.dart';
import 'package:dept_accounting/features/invoices/presentation/invoice_view_model.dart';
import 'package:dept_accounting/features/catalog/data/catalog_tasks.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/auth/data/passwords.dart';

import 'dart:async';
import 'dart:io';

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/database_task.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/core/numbers.dart';
import 'package:flutter_test/flutter_test.dart';

abstract final class Jobs {
  static DatabaseTask<void> payload() => DatabaseTask('test.payload', (data) {
    data.store.write(() {
      data.store.database.handle.execute(
        'CREATE TABLE test_payload (data BLOB)',
      );
      data.store.database.handle.execute(
        'INSERT INTO test_payload VALUES(zeroblob(4194304))',
      );
    });
  });
  static DatabaseTask<void> externalRole(String role) =>
      DatabaseTask('test.external-role', (data) {
        final user = data.store.user!.copyWith(role: role);
        data.store.write(
          () => data.store.database.handle.execute(
            'UPDATE users SET data=? WHERE id=?',
            [user.toJson(), user.id],
          ),
        );
      });
  static DatabaseTask<void> write(
    String value, {
    int milliseconds = 0,
    bool fail = false,
  }) => DatabaseTask('test.write', (data) {
    data.store.require(owner: true);
    final end = DateTime.now().add(Duration(milliseconds: milliseconds));
    while (DateTime.now().isBefore(end)) {
      /* simulate expensive native work */
    }
    data.store.write(() {
      data.store.setSetting('test', value);
      if (fail) throw const BusinessException('rollback');
    });
  });
  static DatabaseTask<String?> read() =>
      DatabaseTask('test.read', (data) => data.store.setting('test'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('file worker preserves ordering, rollback, responsiveness and session boundaries', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dept-worker-test-',
    );
    final d = await AppDependencies.open(path: '${directory.path}/test.sqlite');
    final key = Passwords.token(32);
    try {
      await d.store.setup(
        shop: const Shop(name: 'Fixture', currency: 'SAR'),
        ownerName: 'Owner',
        username: 'owner',
        password: 'password123',
        recovery: 'recovery',
        backupKey: key,
      );
      await d.backups.shutdown();
      expect(d.store.user?.isOwner, true);
      expect(() => d.store.setSetting('forbidden', 'value'), throwsA(anything));
      final finance = FinanceViewModel(d);
      expect(await finance.opening('1100', '100'), true, reason: finance.error);
      finance.dispose();
      expect(d.engine.balance('1100'), 10000);
      await d.store.run(
        CatalogTasks.save(
          const Product(
            id: 'service',
            name: 'Service',
            service: true,
            barcode: 'TEST-SCAN',
            salePrice: 1000,
          ),
        ),
      );
      final editor = InvoiceViewModel(d, sale: true, id: 'worker-sale');
      expect(editor.addBarcode('TEST-SCAN'), true);
      await editor.saveDraft();
      expect(d.invoices.loadDraft(editor.id), isNotNull);
      expect(await editor.post(), isNotNull, reason: editor.error);
      expect(d.invoices.loadDraft(editor.id), isNull);
      expect(d.engine.balance('1100'), 11000);
      editor.dispose();
      var ticks = 0;
      final timer = Timer.periodic(
        const Duration(milliseconds: 20),
        (_) => ticks++,
      );
      final first = d.store.run(Jobs.write('first', milliseconds: 150));
      final read = d.store.run(Jobs.read());
      await first;
      expect(await read, 'first');
      timer.cancel();
      expect(ticks, greaterThan(0));
      expect(d.store.setting('test'), 'first');
      await expectLater(
        d.store.run(Jobs.write('rolled back', fail: true)),
        throwsA(isA<BusinessException>()),
      );
      expect(await d.store.run(Jobs.read()), 'first');
      final entered = Completer<void>(), release = Completer<void>();
      final maintenance = d.store.executor!.exclusive(() async {
        await d.store.run(Jobs.write('exclusive'));
        entered.complete();
        await release.future;
        expect(await d.store.run(Jobs.read()), 'exclusive');
      });
      await entered.future;
      var outsideComplete = false;
      final outside = d.store
          .run(Jobs.write('outside'))
          .then((_) => outsideComplete = true);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(outsideComplete, false);
      release.complete();
      await maintenance;
      await outside;
      expect(await d.store.run(Jobs.read()), 'outside');
      await d.store.run(Jobs.externalRole('seller'));
      // UI still has the previous owner principal. Worker must reload the stored role.
      await expectLater(
        d.store.run(Jobs.write('forbidden')),
        throwsA(isA<BusinessException>()),
      );
      expect(d.store.user!.role, 'seller');
      await d.store.run(Jobs.externalRole('owner'));
      await d.store.run(Jobs.read());
      await d.store.run(Jobs.payload());
      final archive = File(
        await d.backups
            .backup(forceLocal: true)
            .timeout(const Duration(seconds: 10)),
      );
      await d.store.run(Jobs.write('newer'));
      await d.backups
          .restoreFile(archive, key)
          .timeout(const Duration(seconds: 10));
      expect(d.store.user, isNull);
      await d.store.login('owner', 'password123');
      expect(await d.store.run(Jobs.read()), 'outside');
      final safetyCopies = await Directory(d.backups.localDirectory)
          .list()
          .where((f) => f.path.endsWith('.dept_accounting'))
          .toList();
      expect(safetyCopies.length, greaterThanOrEqualTo(2));
      expect(
        d.store.executor!.slowOperations.map((s) => s.name),
        contains('test.write'),
      );
      final late = d.store.run(Jobs.write('late', milliseconds: 50));
      d.store.logout();
      await late;
      expect(d.store.user, isNull);
      await expectLater(
        d.store.run(Jobs.write('unauthorized')),
        throwsA(isA<BusinessException>()),
      );
      expect(await d.store.run(Jobs.read()), 'late');
    } finally {
      await d.shutdown();
      await directory.delete(recursive: true);
    }
  });
}
