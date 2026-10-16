import 'dart:async';

import 'package:dept_accounting/core/ui/async_query_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Only the current query can update state, and disposal ignores pending results', () async {
    final vm = AsyncQueryViewModel<String>();
    final old = Completer<String>(), current = Completer<String>();
    final first = vm.load(() => old.future);
    var intermediateReads = 0;
    final skipped = vm.load(() async {
      intermediateReads++;
      return 'skipped';
    });
    final second = vm.load(() => current.future);
    var settled = false;
    final settling = vm.settled.then((_) => settled = true);
    old.complete('stale');
    await first;
    expect(vm.value, isNull);
    expect(vm.loading, isTrue);
    expect(settled, isFalse);
    expect(intermediateReads, 0);
    current.complete('current');
    await second;
    await skipped;
    await settling;
    expect(settled, isTrue);
    expect(vm.value, 'current');
    expect(vm.loading, isFalse);
    final delayedResult = Completer<String>();
    final pending = vm.load(() => delayedResult.future);
    vm.dispose();
    delayedResult.complete('disposed');
    await pending;
    expect(vm.value, 'current');
  });
}
