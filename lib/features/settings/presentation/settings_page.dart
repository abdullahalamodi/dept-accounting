import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import '../../auth/data/auth_models.dart';
import '../../backup/presentation/backup_status_notice.dart';

enum _SettingsSection {
  shop('المحل'),
  backups('النسخ الاحتياطية'),
  users('المستخدمون'),
  activity('سجل العمليات');

  const _SettingsSection(this.label);
  final String label;
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final vm = ActionViewModel();
  late final name = TextEditingController(
        text: widget.dependencies.store.shop!.name,
      ),
      phone = TextEditingController(
        text: widget.dependencies.store.shop!.phone,
      ),
      address = TextEditingController(
        text: widget.dependencies.store.shop!.address,
      ),
      fullName = TextEditingController(
        text: widget.dependencies.store.user!.name,
      );
  final backupKey = TextEditingController();
  int auditPage = 1;
  _SettingsSection section = _SettingsSection.shop;
  late String currency = widget.dependencies.store.shop!.currency;
  @override
  void dispose() {
    for (final c in [name, phone, address, fullName, backupKey]) {
      c.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = widget.dependencies,
          s = d.store,
          audit = section == _SettingsSection.activity
              ? d.reports.audit()
              : const <Map<String, dynamic>>[];
      return SectionStack(
        children: [
          DukanPageHeader(
            title: 'إعدادات المحل',
            description: 'بيانات المحل، حماية البيانات، وصلاحيات فريقك',
            actions: [
              DukanButton(
                label: 'ملفي الشخصي',
                icon: Icons.person_outline,
                variant: DukanButtonVariant.secondary,
                onPressed: () => context.go('/profile'),
              ),
            ],
          ),
          Wrap(
            spacing: DukanSpace.sm,
            runSpacing: DukanSpace.sm,
            children: [
              for (final item in _SettingsSection.values)
                DukanFilterChip(
                  label: Text(item.label),
                  selected: section == item,
                  onSelected: vm.busy
                      ? null
                      : (_) => setState(() {
                          section = item;
                          vm.changed();
                        }),
                ),
            ],
          ),
          if (vm.error != null) ErrorNotice(vm.error),
          if (section == _SettingsSection.shop) ...[
            DukanPanel(
              title: 'بيانات المحل',
              child: SectionStack.form(
                children: [
                  FieldGrid(
                    minWidth: 400,
                    children: [
                      DukanField(
                        label: 'الاسم الكامل (اختياري)',
                        controller: fullName,
                      ),
                      DukanField(label: 'اسم المحل', controller: name),
                      DukanField(label: 'الهاتف', controller: phone),
                      DukanField(label: 'العنوان', controller: address),
                      ChoiceField(
                        label: 'العملة',
                        value: currency,
                        items: const [
                          (value: 'YER', label: 'ريال يمني'),
                          (value: 'SAR', label: 'ريال سعودي'),
                        ],
                        onChanged: (v) => setState(() => currency = v!),
                      ),
                    ],
                  ),
                  DukanButton(
                    label: 'حفظ إعدادات المحل',
                    onPressed: () {
                      if (vm.perform(
                        () => s.updateShop(
                          Shop(
                            name: name.text.trim(),
                            currency: currency,
                            phone: phone.text.trim(),
                            address: address.text.trim(),
                          ),
                          ownerName: fullName.text,
                        ),
                      )) {
                        showMessage(context, 'تم حفظ الإعدادات');
                      }
                    },
                  ),
                ],
              ),
            ),
            DukanPanel(
              title: 'تفضيلات العمل',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تفعيل نقطة البيع السريعة'),
                subtitle: const Text(
                  'نفس قواعد الفواتير والصلاحيات · F2 بيع، F3 منتجات، F4 أطراف، F6 شراء، Ctrl+L قفل',
                ),
                value: s.setting('pos_enabled') == 'true',
                onChanged: (v) =>
                    s.write(() => s.setSetting('pos_enabled', v.toString())),
              ),
            ),
          ],
          if (section == _SettingsSection.backups)
            DukanPanel(
              title: 'النسخ الاحتياطية والاستعادة',
              description: 'احمِ بيانات محلك بنسخ مشفرة ونسخة خارجية آمنة.',
              child: SectionStack(
                children: [
                  BackupStatusNotice(backups: d.backups),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('كيف تعمل النسخ التلقائية؟'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: DukanSpace.lg),
                        child: Text(
                          'يحفظ التطبيق نسخة مشفرة تلقائيًا كل ساعة عند وجود تغييرات أثناء تشغيله، وعند فتحه إذا فات الموعد. تُحفظ النسخة في مجلد التطبيق أو المجلد الذي تختاره، وتُحفظ نسخة إضافية في المجلد الخارجي إذا كان متصلًا ومتاحًا.',
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'آخر نسخة ناجحة: ${_backupTime(context, s.setting('backup_at'), 'لم تُنشأ بعد')}',
                  ),
                  Text(
                    'آخر نسخة خارجية: ${_backupTime(context, s.setting('external_backup_at'), 'لا توجد')}',
                  ),
                  Text(
                    'مجلد النسخ: ${s.setting('backup_directory') ?? d.backups.localDirectory}',
                  ),
                  Text(
                    'مجلد النسخة الخارجية: ${s.setting('external_backup_directory') ?? 'لم يُحدد بعد'}',
                  ),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      DukanButton(
                        label: 'اختيار مجلد النسخ',
                        variant: DukanButtonVariant.secondary,
                        onPressed: () => vm.run(() async {
                          final path = await FilePicker.getDirectoryPath();
                          if (path != null) {
                            await d.backups.folders.remember(
                              'backup_directory',
                              path,
                            );
                          }
                        }),
                      ),
                      DukanButton(
                        label: 'اختيار مجلد النسخة الخارجية',
                        variant: DukanButtonVariant.secondary,
                        onPressed: () => vm.run(() async {
                          final path = await FilePicker.getDirectoryPath();
                          if (path != null) {
                            await d.backups.folders.remember(
                              'external_backup_directory',
                              path,
                            );
                          }
                        }),
                      ),
                      DukanButton(
                        label: 'إنشاء نسخة احتياطية الآن',
                        loading: vm.busy,
                        onPressed: () => vm.run(() async {
                          final file = await d.backups.backup();
                          if (context.mounted) {
                            showMessage(context, 'تم حفظ النسخة: $file');
                          }
                        }),
                      ),
                    ],
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: DukanSpace.lg),
                    title: const Text('استعادة نسخة احتياطية'),
                    subtitle: const Text('استبدال بيانات المحل بنسخة سابقة'),
                    children: [
                      SectionStack.form(
                        children: [
                          const Text(
                            'لاستعادة بياناتك، أدخل مفتاح استعادة النسخ الاحتياطية من ملف مفاتيح الاسترداد الذي حفظته عند إنشاء المحل، ثم اختر ملف النسخة بامتداد .dukan. الاستعادة تستبدل البيانات الحالية ببيانات النسخة المختارة.',
                          ),
                          DukanField(
                            label: 'مفتاح استعادة النسخ الاحتياطية',
                            controller: backupKey,
                          ),
                          DukanButton(
                            label: 'اختيار نسخة واستعادتها',
                            variant: DukanButtonVariant.secondary,
                            loading: vm.busy,
                            onPressed: () => vm.run(() async {
                              final file = await FilePicker.pickFile(
                                type: FileType.custom,
                                allowedExtensions: ['dukan'],
                              );
                              if (file == null) return;
                              final bytes = await file.readAsBytes();
                              final info = await d.backups.inspect(
                                bytes,
                                backupKey.text,
                              );
                              if (!context.mounted) return;
                              if (await showDukanConfirmation(
                                context,
                                title: 'استعادة بيانات ${info.shop.name}؟',
                                message:
                                    'عملة ${info.shop.currency} · تاريخ البيانات ${info.date}. سيتم حفظ نسخة من البيانات الحالية قبل الاستبدال، ثم تسجيل الخروج.',
                                confirmLabel: 'استعادة البيانات',
                                destructive: true,
                              )) {
                                await d.backups.restore(bytes, backupKey.text);
                              }
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const DukanNotice(
                    title: 'احفظ ملف المفاتيح ونسخة من البيانات خارج الجهاز',
                    message: 'رمز استرداد الدخول يعيد تعيين كلمة مرور المالك. مفتاح استعادة النسخ الاحتياطية يفتح ملفات النسخ المشفرة، ولا يمكن استعادتها بدونه. ملف المفاتيح لا يحتوي بيانات المحل؛ ستحتاج إليه وإلى ملف نسخة احتياطية لاستعادة بياناتك عند فقد الجهاز.',
                    tone: DukanTone.warning,
                  ),
                ],
              ),
            ),
          if (section == _SettingsSection.activity)
            DukanPanel(
              title: 'سجل العمليات',
              child: DukanDataTable(
                columns: const [
                  DataColumn(label: Text('الوقت')),
                  DataColumn(label: Text('المستخدم')),
                  DataColumn(label: Text('العملية')),
                  DataColumn(label: Text('المرجع')),
                ],
                rows: [
                  for (final row in audit.skip((auditPage - 1) * 10).take(10))
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            (row['at'] as String)
                                .substring(0, 16)
                                .replaceAll('T', ' '),
                          ),
                        ),
                        DataCell(Text(row['name'] as String? ?? 'النظام')),
                        DataCell(Text(row['action'] as String)),
                        DataCell(Text(row['entity'] as String)),
                      ],
                    ),
                ],
                totalRows: audit.length,
                page: auditPage,
                pageSize: 10,
                onPageChanged: (v) => setState(() => auditPage = v),
              ),
            ),
          if (section == _SettingsSection.users)
            DukanPanel(
              title: 'المستخدمون والصلاحيات',
              action: DukanButton(
                label: 'مستخدم جديد',
                variant: DukanButtonVariant.secondary,
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => _UserDialog(d: d),
                ),
              ),
              child: Column(
                children: [
                  for (final user in s.users())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(user.displayName),
                      subtitle: Text(
                        '${user.username} · ${user.roleLabel}${user.active ? '' : ' · موقوف'}',
                      ),
                      trailing: TextButton(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (context) => _UserDialog(d: d, user: user),
                        ),
                        child: const Text('تعديل'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

String _backupTime(BuildContext context, String? value, String fallback) {
  final date = DateTime.tryParse(value ?? '')?.toLocal();
  if (date == null) return fallback;
  final localizations = MaterialLocalizations.of(context);
  return '${localizations.formatMediumDate(date)} · ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(date), alwaysUse24HourFormat: true)}';
}

class _UserDialog extends StatefulWidget {
  const _UserDialog({required this.d, this.user});
  final AppDependencies d;
  final AppUser? user;
  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final vm = ActionViewModel();
  late final name = TextEditingController(text: widget.user?.name),
      username = TextEditingController(text: widget.user?.username),
      password = TextEditingController(),
      limit = TextEditingController(text: '${widget.user?.discountLimit ?? 0}');
  late String role = widget.user?.role ?? 'seller';
  late bool active = widget.user?.active ?? true,
      changePrice = widget.user?.canChangePrice ?? false;
  @override
  void dispose() {
    for (final c in [name, username, password, limit]) {
      c.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => AlertDialog(
      title: Text(widget.user == null ? 'مستخدم جديد' : 'تعديل المستخدم'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: SectionStack.form(
            children: [
              if (vm.error != null) ErrorNotice(vm.error),
              DukanField(label: 'الاسم', controller: name),
              DukanField(label: 'اسم المستخدم', controller: username),
              DukanPasswordField(
                controller: password,
                label: widget.user == null
                    ? 'كلمة المرور'
                    : 'كلمة جديدة (اختياري)',
              ),
              ChoiceField(
                label: 'الدور',
                value: role,
                items: [
                  if (widget.user?.isOwner ?? false)
                    (value: 'owner', label: 'المالك'),
                  (value: 'seller', label: 'بائع'),
                  (value: 'accountant', label: 'محاسب'),
                ],
                enabled: !(widget.user?.isOwner ?? false),
                onChanged: (v) => setState(() => role = v!),
              ),
              DukanField(label: 'حد الخصم ٪', controller: limit, numeric: true),
              SwitchListTile(
                title: const Text('السماح بتغيير سعر البيع'),
                value: changePrice,
                onChanged: (v) => setState(() => changePrice = v),
              ),
              if (!(widget.user?.isOwner ?? false))
                SwitchListTile(
                  title: const Text('المستخدم نشط'),
                  value: active,
                  onChanged: (v) => setState(() => active = v),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('العودة'),
        ),
        DukanButton(
          label: 'حفظ',
          loading: vm.busy,
          onPressed: () async {
            final ok = await vm.run(
              () => widget.d.store.saveUser(
                AppUser(
                  id: widget.user?.id ?? widget.d.store.id(),
                  name: name.text.trim(),
                  username: username.text.trim(),
                  role: role,
                  discountLimit: int.tryParse(limit.text) ?? -1,
                  canChangePrice: changePrice,
                  active: active,
                ),
                password.text,
              ),
            );
            if (ok && context.mounted) Navigator.pop(context);
          },
        ),
      ],
    ),
  );
}
