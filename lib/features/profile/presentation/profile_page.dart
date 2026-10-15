import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
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
          const DukanPageHeader(
            title: 'الملف الشخصي',
            description: 'بيانات حسابك، كلمة المرور، وإدارة جلستك',
          ),
          DukanPanel(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: DukanColors.primarySoft,
                  foregroundColor: DukanColors.primary,
                  child: Text(
                    user.displayName.characters.first,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: DukanColors.primary),
                  ),
                ),
                const SizedBox(width: DukanSpace.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '${user.username} · ${user.roleLabel}',
                        style: const TextStyle(color: DukanColors.muted),
                      ),
                      Text(
                        vm.store.shop!.name,
                        style: const TextStyle(color: DukanColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          DukanPanel(
            title: 'اسم المستخدم وكلمة المرور',
            child: Form(
              key: usernameForm,
              child: SectionStack.form(
                children: [
                  if (vm.error != null) ErrorNotice(vm.error),
                  DukanField(
                    label: 'اسم المستخدم',
                    controller: username,
                    helper: 'استخدم الاسم الجديد عند تسجيل الدخول لاحقًا.',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل اسم المستخدم.'
                        : null,
                  ),
                  Wrap(
                    spacing: DukanSpace.md,
                    runSpacing: DukanSpace.md,
                    children: [
                      DukanButton(
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
                      DukanButton(
                        label: 'تغيير كلمة المرور',
                        variant: DukanButtonVariant.secondary,
                        onPressed: vm.busy ? null : _changePassword,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          DukanPanel(
            title: 'الجلسة الحالية',
            child: SectionStack.form(
              children: [
                const Text(
                  'عند تسجيل الخروج ستبقى بيانات المحل محفوظة على هذا الجهاز.',
                  style: TextStyle(color: DukanColors.muted),
                ),
                Wrap(
                  spacing: DukanSpace.md,
                  runSpacing: DukanSpace.md,
                  children: [
                    if (user.isOwner)
                      DukanButton(
                        label: 'إعدادات المحل',
                        variant: DukanButtonVariant.secondary,
                        onPressed: vm.busy
                            ? null
                            : () => context.go('/settings'),
                      ),
                    DukanButton(
                      label: 'تسجيل الخروج',
                      icon: Icons.logout,
                      variant: DukanButtonVariant.danger,
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
                    style: TextStyle(color: DukanColors.muted),
                  ),
                  if (vm.error != null) ErrorNotice(vm.error),
                  DukanPasswordField(
                    label: 'كلمة المرور الحالية',
                    controller: currentPassword,
                    validator: (value) => value == null || value.isEmpty
                        ? 'أدخل كلمة المرور الحالية.'
                        : null,
                  ),
                  DukanPasswordField(
                    label: 'كلمة المرور الجديدة',
                    controller: newPassword,
                    helper: '8 أحرف على الأقل',
                    validator: (value) => (value?.length ?? 0) < 8
                        ? 'استخدم 8 أحرف على الأقل.'
                        : null,
                  ),
                  DukanPasswordField(
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
          DukanButton(
            label: 'تحديث كلمة المرور',
            loading: vm.busy,
            onPressed: submit,
          ),
        ],
      ),
    ),
  );
}
