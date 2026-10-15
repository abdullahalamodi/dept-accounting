import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../app/dependencies.dart';
import '../../../core/app_identity.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
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
      allowedExtensions: ['dukan'],
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final info = await widget.dependencies.backups.inspect(
      bytes,
      restoreKey.text,
    );
    if (!mounted) return;
    if (await showDukanConfirmation(
      context,
      title: 'استعادة ${info.shop.name}؟',
      message:
          'سيُنقل المحل بعملته ${info.shop.currency} وبياناته المسجلة في ${info.date}. استخدم بيانات دخوله الأصلية بعد الاستعادة.',
      confirmLabel: 'استعادة',
    )) {
      await widget.dependencies.backups.restoreFresh(bytes, restoreKey.text);
    }
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DukanSpace.xl),
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
                      color: DukanColors.primary,
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
            const SizedBox(height: DukanSpace.xs),
            const Text(
              'أكمل بياناتك، اختر بيانات الدخول، ثم احفظ مفاتيح الاسترداد.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DukanColors.muted),
            ),
          ],
        ),
        DukanPanel(
          title: '١. معلومات المستخدم',
          child: FieldGrid(
            children: [
              DukanField(
                label: 'اسم المالك',
                controller: name,
                validator: (value) => _required(value, 'أدخل اسم المالك.'),
              ),
              DukanField(
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
                style: TextStyle(color: DukanColors.muted),
              ),
            ],
          ),
        ),
        DukanPanel(
          title: '٢. بيانات الدخول',
          child: SectionStack.form(
            children: [
              DukanField(
                label: 'اسم المستخدم',
                controller: username,
                helper: 'ستستخدمه مع كلمة المرور للدخول إلى $appName.',
                validator: (value) => _required(value, 'أدخل اسم المستخدم.'),
              ),
              FieldGrid(
                children: [
                  DukanPasswordField(
                    label: 'كلمة المرور',
                    controller: password,
                    helper: '8 أحرف على الأقل',
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'استخدم كلمة مرور من 8 أحرف على الأقل.'
                        : null,
                  ),
                  DukanPasswordField(
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
        DukanPanel(
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
                    style: TextStyle(color: DukanColors.muted),
                  ),
                  SizedBox(height: DukanSpace.md),
                  Text(
                    'مفتاح استعادة النسخ الاحتياطية',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  Text(
                    'لاستعادة بيانات محلك من نسخة احتياطية مشفرة.',
                    style: TextStyle(color: DukanColors.muted),
                  ),
                ],
              ),
              DukanButton(
                label: vm.recoveryFileDownloaded
                    ? 'تنزيل ملف المفاتيح مرة أخرى'
                    : 'تنزيل ملف مفاتيح الاسترداد',
                icon: Icons.download_outlined,
                variant: DukanButtonVariant.secondary,
                loading: vm.downloadingRecoveryKeys,
                onPressed: vm.busy ? null : vm.downloadRecoveryKeys,
              ),
              if (vm.recoveryDownloadError != null)
                DukanNotice(
                  title: 'لم يُحفظ الملف',
                  message: vm.recoveryDownloadError,
                  tone: DukanTone.danger,
                ),
              if (vm.recoveryFileDownloaded)
                const DukanNotice(
                  title: 'تم حفظ ملف المفاتيح',
                  message: 'احتفظ بنسخة آمنة خارج جهاز المحل قبل بدء العمل.',
                  tone: DukanTone.success,
                ),
              const DukanNotice(
                title: 'احفظ الملف في مكان آمن خارج هذا الجهاز',
                message: 'لا تشاركه مع الآخرين. ملف المفاتيح لا يحتوي بيانات المحل؛ لاستعادة بياناتك ستحتاج إلى ملف نسخة احتياطية أيضًا. بعد إنشاء المحل، افتح «الإعدادات والنسخ» لإعداد النسخ إلى USB أو قرص خارجي. فقدان مفتاح النسخ يمنع استعادة النسخ المشفرة.',
                tone: DukanTone.warning,
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
        DukanButton(
          label: 'إنشاء المحل وبدء العمل',
          loading: vm.busy,
          onPressed: vm.canSetup ? submit : null,
        ),
        const Text(
          'بياناتك محفوظة على هذا الجهاز · يعمل دون إنترنت',
          textAlign: TextAlign.center,
          style: TextStyle(color: DukanColors.muted),
        ),
        DukanPanel(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            title: const Text('لديك نسخة احتياطية من محل سابق؟'),
            subtitle: const Text('استعد بيانات محلك بدل إنشاء محل جديد'),
            childrenPadding: const EdgeInsets.all(DukanSpace.xl),
            children: [
              SectionStack.form(
                children: [
                  DukanField(
                    label: 'مفتاح استعادة النسخة',
                    controller: restoreKey,
                  ),
                  DukanButton(
                    label: 'اختيار نسخة احتياطية واستعادتها',
                    variant: DukanButtonVariant.secondary,
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

  Widget _loginForm() => DukanPanel(
    title: recovery ? 'استرداد دخول المالك' : 'أهلًا بعودتك',
    description: 'بياناتك محفوظة على هذا الجهاز · يعمل دون إنترنت',
    child: SectionStack.form(
      children: [
        if (vm.error != null) ErrorNotice(vm.error),
        if (!recovery)
          DukanField(label: 'اسم المستخدم', controller: username)
        else
          DukanField(label: 'رمز استرداد دخول المالك', controller: code),
        DukanPasswordField(
          label: recovery ? 'كلمة المرور الجديدة' : 'كلمة المرور',
          controller: password,
          helper: recovery ? '8 أحرف على الأقل' : null,
          onSubmitted: (_) => submit(),
        ),
        DukanButton(
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
