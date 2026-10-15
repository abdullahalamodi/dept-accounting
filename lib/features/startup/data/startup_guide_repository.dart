import '../../../core/data/app_store.dart';

enum StartupTask {
  cash,
  categories,
  units,
  products,
  stock,
  suppliers,
  customers,
  backup,
}

class StartupGuideStep {
  const StartupGuideStep({
    required this.task,
    required this.title,
    required this.message,
    required this.path,
    required this.action,
    required this.complete,
    this.reviewLabel,
    this.skipLabel,
    this.skipped = false,
  });

  final StartupTask task;
  final String title, message, path, action;
  final String? reviewLabel, skipLabel;
  final bool complete, skipped;
  bool get resolved => complete || skipped;
}

class StartupGuideRepository {
  StartupGuideRepository(this.store);
  final AppStore store;

  bool get available => store.user?.canManage == true;

  bool get visible {
    if (!available) return false;
    final saved = store.setting('startup_guide_visible');
    if (saved == 'true') return true;
    // Offer the guide to existing empty shops, without interrupting active shops.
    return !_exists('SELECT 1 FROM products LIMIT 1') &&
        !_exists('SELECT 1 FROM documents LIMIT 1');
  }

  void start() {
    store.require(manage: true);
    if (store.setting('startup_guide_visible') == 'true') return;
    store.write(() => store.setSetting('startup_guide_visible', 'true'));
  }

  void review(StartupTask task, {bool skip = false}) {
    store.require(manage: true);
    final step = steps().where((step) => step.task == task).firstOrNull;
    if (step == null ||
        (skip ? step.skipLabel == null : step.reviewLabel == null)) {
      return;
    }
    store.write(() {
      store.setSetting('startup_guide_visible', 'true');
      store.setSetting(
        'startup_guide_${task.name}',
        skip ? 'skipped' : 'reviewed',
      );
    });
  }

  void revisit(StartupTask task) {
    store.require(manage: true);
    store.write(
      () => store.setSetting('startup_guide_${task.name}', 'pending'),
    );
  }

  bool _exists(String sql) => store.database.handle.select(sql).isNotEmpty;

  List<StartupGuideStep> steps() {
    store.require(manage: true);
    StartupGuideStep step({
      required StartupTask task,
      required String title,
      required String message,
      required String path,
      required String action,
      bool complete = false,
      String? reviewLabel,
      String skipLabel = 'تخطي الآن',
    }) {
      final saved = store.setting('startup_guide_${task.name}');
      return StartupGuideStep(
        task: task,
        title: title,
        message: message,
        path: path,
        action: action,
        complete: complete || saved == 'reviewed',
        skipped: !complete && saved == 'skipped',
        reviewLabel: reviewLabel,
        skipLabel: skipLabel,
      );
    }

    final products = _exists(
      "SELECT 1 FROM products WHERE json_extract(data,'\$.active')=1 LIMIT 1",
    );
    final closed = store.setting('opening_closed') == 'true';
    final firstStock = store.database.handle.select('''
      SELECT p.id FROM products p
      WHERE json_extract(p.data,'\$.active')=1 AND json_extract(p.data,'\$.service')=0
      AND NOT EXISTS(SELECT 1 FROM stock_moves m WHERE m.product_id=p.id)
      ORDER BY json_extract(p.data,'\$.name') LIMIT 1
    ''');
    return [
      step(
        task: StartupTask.cash,
        title: 'راجع الصندوق وأرصدة البداية',
        message: 'يوجد صندوق جاهز. أضف حساباتك البنكية عند الحاجة وسجّل أرصدتها السابقة قبل أول حركة. إذا كانت الأرصدة صفرًا، اكتفِ بالمراجعة.',
        path: '/finance',
        action: 'إعداد الحسابات',
        complete: closed,
        reviewLabel: 'راجعت الحسابات وأرصدة البداية',
      ),
      step(
        task: StartupTask.categories,
        title: 'جهّز التصنيفات',
        message: 'راجع التصنيفات الجاهزة، وأضف أو عدّل ما يناسب نشاطك لتنظيم المنتجات والخدمات.',
        path: '/catalog/categories',
        action: 'مراجعة التصنيفات',
        complete: _exists(
          'SELECT 1 FROM products WHERE category_id IS NOT NULL LIMIT 1',
        ),
        reviewLabel: 'التصنيفات مناسبة لنشاطي',
      ),
      step(
        task: StartupTask.units,
        title: 'جهّز وحدات البيع',
        message: 'راجع الوحدات مثل الحبة والكرتون والكيلوجرام. تحدد معامل التحويل لكل منتج عند إضافته.',
        path: '/catalog/units',
        action: 'مراجعة الوحدات',
        complete: products,
        reviewLabel: 'الوحدات مناسبة لنشاطي',
      ),
      step(
        task: StartupTask.products,
        title: 'أضف المنتجات والخدمات',
        message: 'أضف أول منتج أو خدمة مع التصنيف والوحدة وأسعار البيع والشراء. يمكنك إضافة المزيد في أي وقت.',
        path: '/catalog/new',
        action: 'إضافة منتج أو خدمة',
        complete: products,
      ),
      step(
        task: StartupTask.stock,
        title: 'سجّل المخزون الموجود',
        message: 'للبضاعة التي تملكها قبل استخدام التطبيق، أدخل الكمية الافتتاحية لكل منتج وسعر شرائه. البضاعة الجديدة تُسجل بفاتورة شراء.',
        path: firstStock.isEmpty
            ? '/catalog'
            : '/catalog/${firstStock.first['id']}/opening',
        action: 'إعداد المخزون الافتتاحي',
        complete: closed || (products && firstStock.isEmpty),
        skipLabel: 'لا يوجد مخزون سابق',
      ),
      step(
        task: StartupTask.suppliers,
        title: 'أضف الموردين',
        message: 'أضف من تشتري منهم البضاعة. أضف بيانات المورد ورصيده السابق إن وجد قبل تسجيل أول شراء.',
        path: '/parties/new?role=supplier',
        action: 'إضافة مورد',
        complete: _exists(
          "SELECT 1 FROM parties WHERE json_extract(data,'\$.supplier')=1 AND json_extract(data,'\$.active')=1 LIMIT 1",
        ),
        skipLabel: 'لا أتعامل مع موردين الآن',
      ),
      step(
        task: StartupTask.customers,
        title: 'أضف العملاء',
        message: 'أضف من تبيع لهم بالآجل وأرصدتهم السابقة إن وجدت. يمكنك البيع النقدي دون إضافة عميل.',
        path: '/parties/new',
        action: 'إضافة عميل',
        complete: _exists(
          "SELECT 1 FROM parties WHERE json_extract(data,'\$.customer')=1 AND json_extract(data,'\$.active')=1 LIMIT 1",
        ),
        skipLabel: 'أبيع نقدًا فقط الآن',
      ),
      if (store.user!.isOwner)
        step(
          task: StartupTask.backup,
          title: 'احمِ بيانات محلك',
          message: 'اختر مجلد النسخ ومجلدًا خارجيًا على USB، ثم أنشئ أول نسخة. احتفظ بمفاتيح الاسترداد في مكان آمن خارج الجهاز.',
          path: '/settings?section=backups',
          action: 'إعداد النسخ الاحتياطية',
          complete:
              store.setting('external_backup_directory') != null &&
              store.setting('external_backup_at') != null,
        ),
    ];
  }
}
