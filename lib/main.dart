import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'app/app_router.dart';
import 'app/dependencies.dart';
import 'app/upgrade_backup.dart';
import 'core/app_identity.dart';
import 'core/data/local_database.dart';
import 'design_system/dept_accounting_design_system.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final database = await LocalDatabase.open(
      beforeMigration: backupBeforeUpgrade,
    );
    final dependencies = AppDependencies(database);
    dependencies.store.setSetting('app_version', applicationVersion);
    runApp(DeptAccountingApp(dependencies: dependencies));
  } catch (_) {
    runApp(
      MaterialApp(
        title: appName,
        theme: DeptAccountingTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(
          body: Center(
            child: DeptAccountingStateView(
              state: DeptAccountingViewState.error,
              title: 'تعذر فتح بيانات المحل',
              message: 'تحقق من مساحة القرص وأذونات البيانات ثم أعد التشغيل. احتفظ بملفات البيانات الحالية.',
            ),
          ),
        ),
      ),
    );
  }
}

class DeptAccountingApp extends StatefulWidget {
  const DeptAccountingApp({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<DeptAccountingApp> createState() => _DeptAccountingAppState();
}

class _DeptAccountingAppState extends State<DeptAccountingApp>
    with WidgetsBindingObserver {
  late final GoRouter router = createRouter(widget.dependencies);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.dependencies.backups.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    router.dispose();
    unawaited(_shutdown());
    super.dispose();
  }

  Future<void> _shutdown() async {
    await widget.dependencies.backups.shutdown();
    widget.dependencies.store.dispose();
    widget.dependencies.store.database.close();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: appName,
    debugShowCheckedModeBanner: false,
    theme: DeptAccountingTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    routerConfig: router,
  );
}
