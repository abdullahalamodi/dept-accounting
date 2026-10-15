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
  final detailsForm = GlobalKey<FormState>(),
      passwordForm = GlobalKey<FormState>();
  late final name = TextEditingController(text: vm.store.user!.name),
      username = TextEditingController(text: vm.store.user!.username);
  final currentPassword = TextEditingController(),
      newPassword = TextEditingController(),
      confirmation = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      name,
      username,
      currentPassword,
      newPassword,
      confirmation,
    ]) {
      controller.dispose();
    }
    vm.dispose();
    super.dispose();
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
                    user.name.characters.first,
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
                        user.name,
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
            title: 'بيانات الحساب',
            child: Form(
              key: detailsForm,
              child: SectionStack.form(
                children: [
                  if (vm.error != null && !vm.editingPassword)
                    ErrorNotice(vm.error),
                  FieldGrid(
                    children: [
                      DukanField(
                        label: 'الاسم',
                        controller: name,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'أدخل اسمك.'
                            : null,
                      ),
                      DukanField(
                        label: 'اسم المستخدم',
                        controller: username,
                        helper: 'استخدم الاسم الجديد عند تسجيل الدخول لاحقًا.',
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'أدخل اسم المستخدم.'
                            : null,
                      ),
                    ],
                  ),
                  Text(
                    user.isOwner
                        ? 'حساب المالك · إدارة المحل والمستخدمين والصلاحيات.'
                        : 'صلاحية الحساب: ${user.roleLabel} · يحدد المالك الصلاحيات من إعدادات المحل.',
                    style: const TextStyle(color: DukanColors.muted),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DukanButton(
                      label: 'حفظ بيانات الحساب',
                      onPressed: vm.busy
                          ? null
                          : () {
                              if (detailsForm.currentState!.validate() &&
                                  vm.saveDetails(name.text, username.text)) {
                                showMessage(context, 'تم حفظ بيانات حسابك.');
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
          DukanPanel(
            title: 'كلمة المرور',
            child: Form(
              key: passwordForm,
              child: SectionStack.form(
                children: [
                  if (vm.error != null && vm.editingPassword)
                    ErrorNotice(vm.error),
                  const Text(
                    'لتغيير كلمة المرور، أدخل كلمتك الحالية أولًا.',
                    style: TextStyle(color: DukanColors.muted),
                  ),
                  FieldGrid(
                    children: [
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
                            value != newPassword.text ||
                                (value?.isEmpty ?? true)
                            ? 'كلمتا المرور غير متطابقتين.'
                            : null,
                      ),
                    ],
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: DukanButton(
                      label: 'تحديث كلمة المرور',
                      variant: DukanButtonVariant.secondary,
                      loading: vm.busy,
                      onPressed: () async {
                        if (!passwordForm.currentState!.validate()) return;
                        if (await vm.changePassword(
                              currentPassword.text,
                              newPassword.text,
                            ) &&
                            context.mounted) {
                          passwordForm.currentState!.reset();
                          for (final controller in [
                            currentPassword,
                            newPassword,
                            confirmation,
                          ]) {
                            controller.clear();
                          }
                          showMessage(context, 'تم تحديث كلمة المرور.');
                        }
                      },
                    ),
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
