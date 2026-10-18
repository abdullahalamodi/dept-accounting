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
            child:
                MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact
                ? Material(
                    color: notice.warning
                        ? DeptAccountingColors.warningSoft
                        : DeptAccountingColors.infoSoft,
                    borderRadius: BorderRadius.circular(
                      DeptAccountingLayout.radius,
                    ),
                    child: ExpansionTile(
                      key: PageStorageKey('backup-${notice.title}'),
                      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      leading: Icon(
                        notice.warning
                            ? Icons.warning_amber_rounded
                            : Icons.info_outline,
                        color: notice.warning
                            ? DeptAccountingColors.warning
                            : DeptAccountingColors.info,
                        size: 20,
                      ),
                      title: Text(
                        notice.title,
                        style: TextStyle(
                          fontSize: 12,
                          color: notice.warning
                              ? DeptAccountingColors.warning
                              : DeptAccountingColors.info,
                        ),
                      ),
                      children: [
                        Text(
                          notice.message,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : DeptAccountingNotice(
                    title: notice.title,
                    message: notice.message,
                    tone: notice.warning
                        ? DeptAccountingTone.warning
                        : DeptAccountingTone.info,
                  ),
          ),
  );
}
