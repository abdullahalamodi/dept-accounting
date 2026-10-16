import 'package:flutter/material.dart';

import '../../../design_system/dept_accounting_design_system.dart';
import '../data/username.dart';

class UsernameField extends StatelessWidget {
  const UsernameField({
    super.key,
    required this.controller,
    this.login = false,
  });

  final TextEditingController controller;
  final bool login;

  @override
  Widget build(BuildContext context) => DeptAccountingField(
    label: 'اسم المستخدم',
    controller: controller,
    textDirection: TextDirection.ltr,
    autocorrect: false,
    helper: login ? null : Username.hint,
    validator: login ? null : Username.validate,
  );
}
