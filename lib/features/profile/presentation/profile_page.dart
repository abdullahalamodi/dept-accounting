import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'profile_view_model.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final vm = ProfileViewModel(widget.dependencies.store);
  final usernameForm = GlobalKey<FormState>();
  late final username = TextEditingController(text: vm.store.user!.username);

  @override
  void dispose() {
    username.dispose();
    vm.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChangePasswordDialog(dependencies: widget.dependencies),
    );
    if (changed == true && mounted) {
      showMessage(context, 'تم تحديث كلمة المرور.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final user = vm.store.user;
      if (user == null) return const SizedBox.shrink();
      return SectionStack(
        children: [
          const DeptAccountingPageHeader(
            title: 'الملف الشخصي',
            description: 'بيانات حسابك، كلمة المرور، وإدارة جلستك',
          ),
          DeptAccountingPanel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: DeptAccountingColors.primarySoft,
                  foregroundColor: DeptAccountingColors.primary,
                  child: Text(
                    user.displayName.characters.first,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: DeptAccountingColors.primary),
                  ),
                ),
                const SizedBox(width: DeptAccountingSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: DeptAccountingSpace.xs),
                      Row(
                        children: [
                          DeptAccountingStatusTag(
                            user.roleLabel,
                            compact: true,
                          ),
                          const SizedBox(width: DeptAccountingSpace.sm),
                          Flexible(
                            child: DeptAccountingStatusTag(
                              vm.store.shop!.name,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DeptAccountingPanel(
            title: 'اسم المستخدم وكلمة المرور',
            child: Form(
              key: usernameForm,
              child: SectionStack.form(
                children: [
                  if (vm.error != null) ErrorNotice(vm.error),
                  DeptAccountingField(
                    label: 'اسم المستخدم',
                    controller: username,
                    helper: 'استخدم الاسم الجديد عند تسجيل الدخول لاحقًا.',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل اسم المستخدم.'
                        : null,
                  ),
                  Wrap(
                    spacing: DeptAccountingSpace.md,
                    runSpacing: DeptAccountingSpace.md,
                    children: [
                      DeptAccountingButton(
                        label: 'حفظ اسم المستخدم',
                        onPressed: vm.busy
                            ? null
                            : () {
                                if (usernameForm.currentState!.validate() &&
                                    vm.saveUsername(username.text)) {
                                  showMessage(context, 'تم حفظ اسم المستخدم.');
                                }
                              },
                      ),
                      DeptAccountingButton(
                        label: 'تغيير كلمة المرور',
                        variant: DeptAccountingButtonVariant.secondary,
                        onPressed: vm.busy ? null : _changePassword,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          DeptAccountingPanel(
            title: 'الجلسة الحالية',
            child: SectionStack.form(
              children: [
                const Text(
                  'عند تسجيل الخروج ستبقى بيانات المحل محفوظة على هذا الجهاز.',
                  style: TextStyle(color: DeptAccountingColors.muted),
                ),
                Wrap(
                  spacing: DeptAccountingSpace.md,
                  runSpacing: DeptAccountingSpace.md,
                  children: [
                    if (user.isOwner)
                      DeptAccountingButton(
                        label: 'إعدادات المحل',
                        variant: DeptAccountingButtonVariant.secondary,
                        onPressed: vm.busy
                            ? null
                            : () => context.go('/settings'),
                      ),
                    DeptAccountingButton(
                      label: 'تسجيل الخروج',
                      icon: Icons.logout,
                      variant: DeptAccountingButtonVariant.danger,
                      onPressed: vm.busy ? null : vm.logout,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final vm = ActionViewModel();
  final form = GlobalKey<FormState>();
  final currentPassword = TextEditingController(),
      newPassword = TextEditingController(),
      confirmation = TextEditingController();

  @override
  void dispose() {
    for (final controller in [currentPassword, newPassword, confirmation]) {
      controller.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (vm.busy || !form.currentState!.validate()) return;
    final changed = await vm.run(
      () => widget.dependencies.store.changePassword(
        currentPassword.text,
        newPassword.text,
      ),
    );
    if (changed && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => PopScope(
      canPop: !vm.busy,
      child: AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: SectionStack.form(
                children: [
                  const Text(
                    'لتغيير كلمة المرور، أدخل كلمتك الحالية أولًا.',
                    style: TextStyle(color: DeptAccountingColors.muted),
                  ),
                  if (vm.error != null) ErrorNotice(vm.error),
                  DeptAccountingPasswordField(
                    label: 'كلمة المرور الحالية',
                    controller: currentPassword,
                    validator: (value) => value == null || value.isEmpty
                        ? 'أدخل كلمة المرور الحالية.'
                        : null,
                  ),
                  DeptAccountingPasswordField(
                    label: 'كلمة المرور الجديدة',
                    controller: newPassword,
                    helper: '8 أحرف على الأقل',
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'استخدم 8 أحرف على الأقل.'
                        : null,
                  ),
                  DeptAccountingPasswordField(
                    label: 'تأكيد كلمة المرور الجديدة',
                    controller: confirmation,
                    validator: (value) =>
                        value != newPassword.text || (value?.isEmpty ?? true)
                        ? 'كلمتا المرور غير متطابقتين.'
                        : null,
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: vm.busy ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          DeptAccountingButton(
            label: 'تحديث كلمة المرور',
            loading: vm.busy,
            onPressed: submit,
          ),
        ],
      ),
    ),
  );
}
