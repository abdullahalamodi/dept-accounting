import 'package:flutter/material.dart';

import '../../../design_system/dept_accounting_design_system.dart';
import '../data/backup_service.dart';

class BackupStatusNotice extends StatelessWidget {
  const BackupStatusNotice({
    super.key,
    required this.backups,
    this.padding = EdgeInsets.zero,
  });

  final BackupService backups;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<BackupNotice?>(
    valueListenable: backups.status,
    builder: (context, notice, _) => notice == null
        ? const SizedBox.shrink()
        : Padding(
            padding: padding,
            child: DeptAccountingNotice(
              title: notice.title,
              message: notice.message,
              tone: notice.warning
                  ? DeptAccountingTone.warning
                  : DeptAccountingTone.info,
            ),
          ),
  );
}
