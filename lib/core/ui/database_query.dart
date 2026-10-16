import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/dept_accounting_design_system.dart';
import '../data/app_store.dart';
import '../data/database_task.dart';
import 'async_query_view_model.dart';

/// Retains the current view while a new page is loaded, preserving input focus.
class DatabaseQuery<T> extends StatefulWidget {
  const DatabaseQuery({
    super.key,
    required this.store,
    required this.task,
    required this.queryKey,
    required this.builder,
    this.dialog = false,
  });
  final bool dialog;
  final AppStore store;
  final DatabaseTask<T> task;
  final Object? queryKey;
  final Widget Function(BuildContext, T) builder;
  @override
  State<DatabaseQuery<T>> createState() => _DatabaseQueryState<T>();
}

class _DatabaseQueryState<T> extends State<DatabaseQuery<T>> {
  final query = AsyncQueryViewModel<T>();
  Object? _key;
  @override
  void initState() {
    super.initState();
    widget.store.addListener(_load);
    _load();
  }

  void _load({bool force = false}) {
    final key = (
      widget.store.revision,
      widget.store.sessionEpoch,
      widget.queryKey,
    );
    if (!force && _key == key) return;
    _key = key;
    unawaited(query.load(() => widget.store.run(widget.task)));
  }

  @override
  void didUpdateWidget(covariant DatabaseQuery<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.store != widget.store) {
      oldWidget.store.removeListener(_load);
      widget.store.addListener(_load);
      _key = null;
    }
    _load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_load);
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: query,
    builder: (context, _) {
      final value = query.value;
      if (query.error != null) {
        final state = DeptAccountingStateView(
          state: DeptAccountingViewState.error,
          title: 'تعذر تحميل البيانات',
          message: query.error!,
          actionLabel: 'إعادة المحاولة',
          onAction: () => _load(force: true),
        );
        return widget.dialog ? Dialog(child: state) : state;
      }
      if (value == null) {
        const state = DeptAccountingStateView(
          state: DeptAccountingViewState.loading,
          title: 'جارٍ تحميل البيانات',
          message: '',
        );
        return widget.dialog ? const Dialog(child: state) : state;
      }
      if (widget.dialog) return widget.builder(context, value);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 4,
            child: query.loading ? const LinearProgressIndicator() : null,
          ),
          widget.builder(context, value),
        ],
      );
    },
  );
}
