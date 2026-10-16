import 'dart:async';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../../app/app_data.dart';
import '../../app/upgrade_backup.dart';
import '../../features/auth/data/auth_models.dart';
import '../numbers.dart';
import 'app_store.dart';
import 'database_task.dart';
import 'local_database.dart';

class _Request {
  const _Request(this.id, this.task, this.userId);
  final int id;
  final DatabaseTask<dynamic> task;
  final String? userId;
}

class _Reply {
  const _Reply(
    this.id,
    this.value,
    this.user,
    this.changed,
    this.error,
    this.businessError, [
    this.microseconds = 0,
  ]);
  final int id;
  final Object? value;
  final AppUser? user;
  final bool changed;
  final String? error;
  final bool businessError;
  final int microseconds;
}

class DatabaseOperation {
  const DatabaseOperation(this.name, this.microseconds, this.failed);
  final String name;
  final int microseconds;
  final bool failed;
}

class DatabaseExecutor {
  DatabaseExecutor.local(AppData data) : _local = data;
  DatabaseExecutor._remote() : _local = null;
  final AppData? _local;
  int completed = 0;
  final _slowOperations = <DatabaseOperation>[];
  List<DatabaseOperation> get slowOperations =>
      List.unmodifiable(_slowOperations);
  bool get isRemote => _local == null;
  final _pending =
      <
        int,
        ({
          Completer<Object?> completion,
          DatabaseTask<dynamic> task,
          int epoch,
          String? userId,
        })
      >{};
  AppStore? _store;
  ReceivePort? _responses, _errors, _exit;
  StreamSubscription<dynamic>? _responseSubscription,
      _errorSubscription,
      _exitSubscription;
  SendPort? _requests;
  final _exited = Completer<void>();
  bool _closing = false;
  Completer<void>? _maintenance;
  static final _maintenanceOwner = Object();
  bool get maintenance => _maintenance != null;
  int _sequence = 0;

  void attach(AppStore store) => _store = store;

  static Future<DatabaseExecutor> open(String path) async {
    final executor = DatabaseExecutor._remote();
    final ready = Completer<void>();
    executor._responses = ReceivePort();
    executor._errors = ReceivePort();
    executor._exit = ReceivePort();
    executor._responseSubscription = executor._responses!.listen((message) {
      if (message is SendPort) {
        executor._requests = message;
        ready.complete();
      } else if (message is _Reply) {
        final request = executor._pending.remove(message.id);
        if (request == null) return;
        executor.completed++;
        if (message.microseconds >= 50000) {
          executor._slowOperations.add(
            DatabaseOperation(
              request.task.name,
              message.microseconds,
              message.error != null,
            ),
          );
          if (executor._slowOperations.length > 20) {
            executor._slowOperations.removeAt(0);
          }
        }
        executor._store?.acceptWorkerState(
          message.user,
          changed: message.changed,
          notify: request.task.notify,
          updatesSession: request.task.updatesSession,
          requestEpoch: request.epoch,
          requestedUserId: request.userId,
        );
        if (message.error == null) {
          request.completion.complete(message.value);
        } else {
          request.completion.completeError(
            message.businessError
                ? BusinessException(message.error!)
                : StateError(message.error!),
          );
        }
      } else if (message is String && !ready.isCompleted) {
        ready.completeError(StateError(message));
      }
    });
    executor._errorSubscription = executor._errors!.listen((message) {
      final error = StateError('Database worker failed: $message');
      if (!ready.isCompleted) ready.completeError(error);
      executor._failPending(error);
    });
    executor._exitSubscription = executor._exit!.listen((_) {
      if (!ready.isCompleted) {
        ready.completeError(
          StateError('Database worker exited during startup'),
        );
      }
      executor._failPending(StateError('Database worker stopped'));
      if (!executor._exited.isCompleted) executor._exited.complete();
    });
    try {
      await Isolate.spawn(
        _databaseMain,
        (path, executor._responses!.sendPort),
        onError: executor._errors!.sendPort,
        onExit: executor._exit!.sendPort,
      );
      await ready.future;
      return executor;
    } catch (_) {
      await executor._disposePorts();
      rethrow;
    }
  }

  void _failPending(Object error) {
    for (final request in _pending.values) {
      request.completion.completeError(error);
    }
    _pending.clear();
  }

  Future<T> exclusive<T>(Future<T> Function() operation) async {
    while (_maintenance != null) {
      await _maintenance!.future;
    }
    if (_closing) throw StateError('Database executor is closed');
    final completion = _maintenance = Completer<void>();
    try {
      await _drain();
      return await runZoned(operation, zoneValues: {_maintenanceOwner: this});
    } finally {
      _maintenance = null;
      completion.complete();
    }
  }

  Future<void> _drain() => Future.wait(
    _pending.values
        .map(
          (r) => r.completion.future.then<void>((_) {}, onError: (Object _) {}),
        )
        .toList(),
  );

  Future<T> run<T>(DatabaseTask<T> task) {
    if (_maintenance != null && Zone.current[_maintenanceOwner] != this) {
      return _maintenance!.future.then((_) => run(task));
    }
    if (_closing) {
      return Future.error(StateError('Database executor is closed'));
    }
    final local = _local;
    if (local != null) return Future.sync(() => task.run(local));
    if (_exited.isCompleted) {
      return Future.error(StateError('Database worker stopped'));
    }
    final completion = Completer<Object?>(), id = ++_sequence;
    _pending[id] = (
      completion: completion,
      task: task,
      epoch: _store?.sessionEpoch ?? 0,
      userId: _store?.user?.id,
    );
    try {
      _requests!.send(_Request(id, task, _store?.user?.id));
    } catch (error, stack) {
      _pending.remove(id);
      completion.completeError(error, stack);
    }
    return completion.future.then((value) => value as T);
  }

  Future<void> close() async {
    if (_closing) return;
    await _maintenance?.future;
    _closing = true;
    if (_local != null) return;
    await _drain();
    if (!_exited.isCompleted) {
      _requests!.send(null);
      await _exited.future;
    }
    await _disposePorts();
  }

  Future<void> _disposePorts() async {
    await _responseSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _exitSubscription?.cancel();
    _responses?.close();
    _errors?.close();
    _exit?.close();
  }
}

Future<void> _databaseMain((String, SendPort) configuration) async {
  final (path, replies) = configuration;
  Database? handle;
  AppData? data;
  final requests = ReceivePort();
  try {
    handle = sqlite3.open(path);
    await backupBeforeUpgrade(handle, path);
    data = AppData(LocalDatabase.fromHandle(handle, path));
    data.store.setSetting('app_version', applicationVersion);
    handle.execute('PRAGMA optimize=0x10002');
    replies.send(requests.sendPort);
    var writesSinceOptimize = 0;
    var lastOptimize = DateTime.now();
    await for (final message in requests) {
      if (message == null) break;
      final request = message as _Request;
      final before = data.store.revision;
      final clock = Stopwatch()..start();
      try {
        final users = request.userId == null
            ? null
            : handle.select('SELECT data FROM users WHERE id = ?', [
                request.userId,
              ]);
        data.store.user = users == null || users.isEmpty
            ? null
            : AppUserMapper.fromJson(users.first['data'] as String);
        final result = await request.task.run(data);
        replies.send(
          _Reply(
            request.id,
            result,
            data.store.user,
            data.store.revision != before,
            null,
            false,
            clock.elapsedMicroseconds,
          ),
        );
      } catch (e) {
        replies.send(
          _Reply(
            request.id,
            null,
            data.store.user,
            data.store.revision != before,
            e.toString(),
            e is BusinessException,
            clock.elapsedMicroseconds,
          ),
        );
      }
      if (data.store.revision != before) writesSinceOptimize++;
      if (writesSinceOptimize >= 1000 ||
          DateTime.now().difference(lastOptimize) >= const Duration(days: 1)) {
        handle.execute('PRAGMA optimize');
        writesSinceOptimize = 0;
        lastOptimize = DateTime.now();
      }
    }
    handle.execute('PRAGMA optimize');
  } catch (e) {
    replies.send(e.toString());
  } finally {
    requests.close();
    data?.store.dispose();
    handle?.close();
  }
}
