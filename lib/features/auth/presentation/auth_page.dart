import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/dependencies.dart';
import '../../../core/app_identity.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../../backup/data/backup_codec.dart';
import '../../backup/presentation/backup_file_selection.dart';
import '../data/auth_models.dart';
import 'auth_view_model.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.dependencies, required this.setup});
  final AppDependencies dependencies;
  final bool setup;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final vm = AuthViewModel(widget.dependencies.store);
  final form = GlobalKey<FormState>();
  final shop = TextEditingController(),
      name = TextEditingController(),
      username = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      code = TextEditingController(),
      restoreKey = TextEditingController();
  String currency = 'YER';
  bool recovery = false;
  bool attemptedSetup = false;

  @override
  void dispose() {
    for (final c in [
      shop,
      name,
      username,
      password,
      confirm,
      code,
      restoreKey,
    ]) {
      c.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (vm.busy) return;
    if (widget.setup) {
      setState(() => attemptedSetup = true);
      final invalidFields = form.currentState!.validateGranularly();
      if (invalidFields.isNotEmpty) {
        await Scrollable.ensureVisible(
          invalidFields.first.context,
          duration: const Duration(milliseconds: 250),
          alignment: .2,
        );
        return;
      }
      await vm.setup(
        Shop(name: shop.text.trim(), currency: currency),
        name.text,
        username.text,
        password.text,
      );
    } else if (recovery) {
      final ok = await vm.recover(code.text, password.text);
      if (ok && mounted) {
        setState(() => recovery = false);
        showMessage(context, 'تم تغيير كلمة مرور المالك. سجل الدخول.');
      }
    } else {
      await vm.login(username.text, password.text);
    }
  }

  Future<bool> restore() => vm.run(() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: BackupCodec.supportedExtensions,
    );
    if (file == null) return;
    await withSelectedBackup(file, (backupFile) async {
      final info = await widget.dependencies.backups.inspectFile(
        backupFile,
        restoreKey.text,
      );
      if (!mounted) return;
      if (await showDeptAccountingConfirmation(
        context,
        title: 'استعادة ${info.shop.name}؟',
        message:
            'سيُنقل المحل بعملته ${info.shop.currency} وبياناته المسجلة في ${info.date}. استخدم بيانات دخوله الأصلية بعد الاستعادة.',
        confirmLabel: 'استعادة',
      )) {
        await widget.dependencies.backups.restoreFreshFile(
          backupFile,
          restoreKey.text,
        );
      }
    });
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DeptAccountingSpace.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.setup ? 760 : 440),
            child: ListenableBuilder(
              listenable: vm,
              builder: (context, _) => SectionStack(
                children: [
                  const Text(
                    appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'NotoKufiArabic',
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: DeptAccountingColors.primary,
                    ),
                  ),
                  if (widget.setup) _setupForm(context) else _loginForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _setupForm(BuildContext context) => Form(
    key: form,
    autovalidateMode: attemptedSetup
        ? AutovalidateMode.onUserInteraction
        : AutovalidateMode.disabled,
    child: SectionStack(
      children: [
        Column(
          children: [
            Text(
              'مرحبًا، لنجهّز محلك',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: DeptAccountingSpace.xs),
            const Text(
              'أكمل بياناتك، اختر بيانات الدخول، ثم احفظ مفاتيح الاسترداد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DeptAccountingColors.muted),
            ),
          ],
        ),
        DeptAccountingPanel(
          title: '١. معلومات المستخدم',
          child: FieldGrid(
            children: [
              DeptAccountingField(
                label: 'اسم المالك',
                controller: name,
                validator: (value) => _required(value, 'أدخل اسم المالك.'),
              ),
              DeptAccountingField(
                label: 'اسم المحل',
                controller: shop,
                validator: (value) => _required(value, 'أدخل اسم المحل.'),
              ),
              ChoiceField(
                label: 'عملة المحل',
                value: currency,
                items: const [
                  (value: 'YER', label: 'ريال يمني — ر.ي'),
                  (value: 'SAR', label: 'ريال سعودي — ر.س'),
                ],
                onChanged: (v) => setState(() => currency = v!),
              ),
              const Text(
                'اختر العملة التي ستستخدمها في محلك. تُثبت بعد أول عملية مالية.',
                style: TextStyle(color: DeptAccountingColors.muted),
              ),
            ],
          ),
        ),
        DeptAccountingPanel(
          title: '٢. بيانات الدخول',
          child: SectionStack.form(
            children: [
              DeptAccountingField(
                label: 'اسم المستخدم',
                controller: username,
                helper: 'ستستخدمه مع كلمة المرور للدخول إلى $appName.',
                validator: (value) => _required(value, 'أدخل اسم المستخدم.'),
              ),
              FieldGrid(
                children: [
                  DeptAccountingPasswordField(
                    label: 'كلمة المرور',
                    controller: password,
                    helper: '8 أحرف على الأقل',
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'استخدم كلمة مرور من 8 أحرف على الأقل.'
                        : null,
                  ),
                  DeptAccountingPasswordField(
                    label: 'تأكيد كلمة المرور',
                    controller: confirm,
                    validator: (value) =>
                        value != password.text || (value?.isEmpty ?? true)
                        ? 'كلمتا المرور غير متطابقتين.'
                        : null,
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
            ],
          ),
        ),
        DeptAccountingPanel(
          title: '٣. مفاتيح الاسترداد',
          child: SectionStack(
            children: [
              const Text(
                'احتفظ بالمفتاحين لاسترداد الدخول واستعادة بيانات محلك عند الحاجة.',
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'رمز استرداد الدخول',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    'لإعادة تعيين كلمة مرور المالك إذا نسيتها.',
                    style: TextStyle(color: DeptAccountingColors.muted),
                  ),
                  SizedBox(height: DeptAccountingSpace.md),
                  Text(
                    'مفتاح استعادة النسخ الاحتياطية',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    'لاستعادة بيانات محلك من نسخة احتياطية مشفرة.',
                    style: TextStyle(color: DeptAccountingColors.muted),
                  ),
                ],
              ),
              DeptAccountingButton(
                label: vm.recoveryFileDownloaded
                    ? 'تنزيل ملف المفاتيح مرة أخرى'
                    : 'تنزيل ملف مفاتيح الاسترداد',
                icon: Icons.download_outlined,
                variant: DeptAccountingButtonVariant.secondary,
                loading: vm.downloadingRecoveryKeys,
                onPressed: vm.busy ? null : vm.downloadRecoveryKeys,
              ),
              if (vm.recoveryDownloadError != null)
                DeptAccountingNotice(
                  title: 'لم يُحفظ الملف',
                  message: vm.recoveryDownloadError,
                  tone: DeptAccountingTone.danger,
                ),
              if (vm.recoveryFileDownloaded)
                const DeptAccountingNotice(
                  title: 'تم حفظ ملف المفاتيح',
                  message: 'احتفظ بنسخة آمنة خارج جهاز المحل قبل بدء العمل.',
                  tone: DeptAccountingTone.success,
                ),
              const DeptAccountingNotice(
                title: 'احفظ الملف في مكان آمن خارج هذا الجهاز',
                message: 'لا تشاركه مع الآخرين. ملف المفاتيح لا يحتوي بيانات المحل؛ لاستعادة بياناتك ستحتاج إلى ملف نسخة احتياطية أيضًا. بعد إنشاء المحل، افتح «الإعدادات والنسخ» لإعداد النسخ إلى USB أو قرص خارجي. فقدان مفتاح النسخ يمنع استعادة النسخ المشفرة.',
                tone: DeptAccountingTone.warning,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: vm.recoveryStorageConfirmed,
                title: const Text(
                  'حفظت ملف المفاتيح في مكان آمن خارج جهاز المحل',
                ),
                subtitle: vm.recoveryFileDownloaded
                    ? null
                    : const Text('نزّل الملف أولًا لتأكيد حفظه.'),
                onChanged:
                    vm.recoveryFileDownloaded &&
                        !vm.busy &&
                        !vm.downloadingRecoveryKeys
                    ? (value) => vm.confirmRecoveryStorage(value ?? false)
                    : null,
              ),
            ],
          ),
        ),
        if (vm.error != null) ErrorNotice(vm.error),
        DeptAccountingButton(
          label: 'إنشاء المحل وبدء العمل',
          loading: vm.busy,
          onPressed: vm.canSetup ? submit : null,
        ),
        const Text(
          'بياناتك محفوظة على هذا الجهاز · يعمل دون إنترنت',
          textAlign: TextAlign.center,
          style: TextStyle(color: DeptAccountingColors.muted),
        ),
        DeptAccountingPanel(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            title: const Text('لديك نسخة احتياطية من محل سابق؟'),
            subtitle: const Text('استعد بيانات محلك بدل إنشاء محل جديد'),
            childrenPadding: const EdgeInsets.all(DeptAccountingSpace.xl),
            children: [
              SectionStack.form(
                children: [
                  DeptAccountingField(
                    label: 'مفتاح استعادة النسخة',
                    controller: restoreKey,
                  ),
                  DeptAccountingButton(
                    label: 'اختيار نسخة احتياطية واستعادتها',
                    variant: DeptAccountingButtonVariant.secondary,
                    loading: vm.busy,
                    onPressed: vm.downloadingRecoveryKeys ? null : restore,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _loginForm() => DeptAccountingPanel(
    title: recovery ? 'استرداد دخول المالك' : 'أهلًا بعودتك',
    description: 'بياناتك محفوظة على هذا الجهاز · يعمل دون إنترنت',
    child: SectionStack.form(
      children: [
        if (vm.error != null) ErrorNotice(vm.error),
        if (!recovery)
          DeptAccountingField(label: 'اسم المستخدم', controller: username)
        else
          DeptAccountingField(
            label: 'رمز استرداد دخول المالك',
            controller: code,
          ),
        DeptAccountingPasswordField(
          label: recovery ? 'كلمة المرور الجديدة' : 'كلمة المرور',
          controller: password,
          helper: recovery ? '8 أحرف على الأقل' : null,
          onSubmitted: (_) => submit(),
        ),
        DeptAccountingButton(
          label: recovery ? 'تعيين كلمة المرور' : 'دخول',
          loading: vm.busy,
          onPressed: submit,
        ),
        TextButton(
          onPressed: () => setState(() {
            recovery = !recovery;
            vm.changed();
          }),
          child: Text(recovery ? 'العودة للدخول' : 'نسيت كلمة مرور المالك؟'),
        ),
      ],
    ),
  );

  String? _required(String? value, String message) =>
      value == null || value.trim().isEmpty ? message : null;
}
