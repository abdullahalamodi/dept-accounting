import 'dart:async';

import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/reports/data/export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('net.nfet.printing');
  const codec = StandardMethodCodec();

  for (final thermal in [false, true]) {
    test(
      'prints ${thermal ? 'thermal' : 'B5'} PDF without native dynamic layout',
      () async {
        final submitted = Completer<MethodCall>();
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          if (call.method == 'printPdf') submitted.complete(call);
          return null;
        });
        addTearDown(() {
          binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          );
        });

        var finished = false;
        final printing = ExportService()
            .printReport(
              const Shop(name: 'محل تجريبي', currency: 'YER'),
              const ReportTable(
                title: 'فاتورة تجريبية',
                columns: ['المنتج', 'القيمة'],
                rows: [
                  ['مصباح', '3,000'],
                ],
              ),
              thermal: thermal,
            )
            .then((_) => finished = true);

        final call = await submitted.future;
        final args = call.arguments as Map;
        final format = thermal
            ? PdfPageFormat(80 * PdfPageFormat.mm, 297 * PdfPageFormat.mm)
            : const PdfPageFormat(176 * PdfPageFormat.mm, 250 * PdfPageFormat.mm);

        // A cancelled print panel must also complete the pending print action.
        await binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          codec.encodeMethodCall(
            MethodCall('onCompleted', {'job': args['job'], 'completed': false}),
          ),
          null,
        );
        await printing;

        expect(finished, isTrue);
        expect(
          args['dynamic'],
          isFalse,
          reason: 'Prepared PDFs must bypass the macOS dynamic-layout blocking wait.',
        );
        expect(args['width'], format.width);
        expect(args['height'], format.height);
      },
    );
  }
}
