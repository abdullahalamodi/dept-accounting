import 'package:dukan_app/app/dependencies.dart';
import 'package:dukan_app/core/data/local_database.dart';
import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:dukan_app/features/auth/data/auth_models.dart';
import 'package:dukan_app/features/catalog/data/product.dart';
import 'package:dukan_app/features/parties/data/party.dart';
import 'package:dukan_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Feature routes fit a phone and desktop and draft navigation stays safe',
    (tester) async {
      for (final width in [390.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        final d = AppDependencies(LocalDatabase.memory());
        d.store.setSetting(
          'shop',
          const Shop(name: 'محل اختبار', currency: 'YER').toJson(),
        );
        d.store.user = const AppUser(
          id: 'owner',
          name: 'مالك',
          username: 'owner',
          role: 'owner',
        );
        d.catalog.save(
          const Product(
            id: 'p',
            name: 'مصباح',
            salePrice: 150000,
            purchasePrice: 100000,
          ),
        );
        d.parties.save(
          const Party(id: 'party', name: 'العميل والمورد', supplier: true),
        );
        await tester.pumpWidget(DukanApp(dependencies: d));
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(DukanWorkspace)));
        for (final path in [
          '/catalog',
          '/catalog/p',
          '/inventory/p',
          '/parties',
          '/parties/party',
          '/sales',
          '/sales/new/sale',
          '/purchases/new/purchase',
          '/receiving',
          '/receiving/new/receive',
          '/finance',
          '/finance/new',
          '/reports',
          '/settings',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$path at $width');
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
