import 'dart:async';

import 'package:flutter/foundation.dart';

import 'form_widgets.dart';

class AsyncQueryViewModel<T> extends ChangeNotifier {
  T? value;
  String? error;
  bool loading = false;
  bool _disposed = false;
  int _request = 0;

  Future<void>? _current;
  Future<void>? _running;
  Future<void> load(Future<T> Function() read) => _current = _load(read);

  Future<void> get settled async {
    while (_current != null) {
      final current = _current;
      await current;
      if (current == _current) return;
    }
  }

  Future<void> _load(Future<T> Function() read) async {
    if (_disposed) return;
    final request = ++_request;
    loading = true;
    error = null;
    notifyListeners();
    // Finish the active read, then execute only the newest pending request.
    // Typing must not queue a scan for every intermediate search string.
    final running = _running;
    if (running != null) await running;
    if (_disposed || request != _request) return;
    final completion = Completer<void>();
    _running = completion.future;
    try {
      final result = await read();
      if (!_disposed && request == _request) value = result;
    } catch (e) {
      if (!_disposed && request == _request) error = errorMessage(e);
    } finally {
      _running = null;
      completion.complete();
      if (!_disposed && request == _request) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
