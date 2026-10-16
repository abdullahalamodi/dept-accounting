import 'package:flutter/material.dart';

import '../../core/date_time.dart';
import 'dept_accounting_controls.dart';

class DeptAccountingDateTimeField extends StatefulWidget {
  const DeptAccountingDateTimeField({
    super.key,
    this.label = 'التاريخ',
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  @override
  State<DeptAccountingDateTimeField> createState() =>
      _DeptAccountingDateTimeFieldState();
}

class _DeptAccountingDateTimeFieldState
    extends State<DeptAccountingDateTimeField> {
  late final controller = TextEditingController(text: displayValue);
  bool picking = false;

  String get displayValue =>
      formatDocumentDateTime(widget.value.toIso8601String());

  @override
  void didUpdateWidget(DeptAccountingDateTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) controller.text = displayValue;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> pick() async {
    if (picking || !widget.enabled) return;
    picking = true;
    try {
      final now = DateTime.now();
      final first = DateTime(1900);
      final local = widget.value.toLocal();
      final initial = local.isBefore(first)
          ? first
          : local.isAfter(now)
          ? now
          : local;
      final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first,
        lastDate: now,
        helpText: 'اختر التاريخ',
        cancelText: 'إلغاء',
        confirmText: 'التالي',
      );
      if (date == null || !mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initial),
        helpText: 'اختر الوقت',
        cancelText: 'إلغاء',
        confirmText: 'تأكيد',
      );
      if (time == null || !mounted || !widget.enabled) return;
      widget.onChanged(
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    } finally {
      picking = false;
    }
  }

  @override
  Widget build(BuildContext context) => DeptAccountingField(
    label: widget.label,
    controller: controller,
    readOnly: true,
    enabled: widget.enabled,
    onTap: pick,
    suffixIcon: const Icon(Icons.calendar_month_outlined),
  );
}
