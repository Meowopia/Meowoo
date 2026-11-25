import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miru_alpha/model/user_data.dart';
import 'package:miru_alpha/provider/home/history_page_provider.dart';

class FixtureHistoryNotifier extends HistoryPageNotifier {
  final requests = <Completer<List<History>>>[];
  @override
  Future<List<History>> fetchHistories() {
    final request = Completer<List<History>>();
    requests.add(request);
    return request.future;
  }
}

History row(String title) => History(
  package: 'fixture.public',
  url: title,
  detailUrl: 'work',
  type: 'bangumi',
  episodeGroupId: 0,
  episodeId: 0,
  title: title,
  episodeTitle: 'Episode 1',
  progress: 10,
  totalProgress: 100,
  date: DateTime(2026, 11, 25),
);
Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late ProviderContainer container;
  late FixtureHistoryNotifier notifier;
  var disposed = false;
  setUp(() async {
    disposed = false;
    notifier = FixtureHistoryNotifier();
    container = ProviderContainer(
      overrides: [historyPageProvider.overrideWith(() => notifier)],
    );
    container.listen(historyPageProvider, (_, _) {});
    await tick();
  });
  tearDown(() {
    if (!disposed) container.dispose();
  });

  test(
    'initial loading, failure, retry, and genuine empty are distinct',
    () async {
      expect(container.read(historyPageProvider).isLoading, isTrue);
      notifier.requests.single.completeError(StateError('offline fixture'));
      await tick();
      expect(container.read(historyPageProvider).loadFailed, isTrue);
      expect(container.read(historyPageProvider).isLoading, isFalse);
      final retry = notifier.refresh();
      expect(container.read(historyPageProvider).loadFailed, isFalse);
      notifier.requests.last.complete([]);
      await retry;
      expect(container.read(historyPageProvider).history, isEmpty);
      expect(container.read(historyPageProvider).loadFailed, isFalse);
      expect(container.read(historyPageProvider).isLoading, isFalse);
    },
  );

  test('refresh failure preserves already loaded rows', () async {
    notifier.requests.single.complete([row('Saved')]);
    await tick();
    final retry = notifier.refresh();
    notifier.requests.last.completeError(StateError('offline fixture'));
    await retry;
    final state = container.read(historyPageProvider);
    expect(state.history.single.title, 'Saved');
    expect(state.filteredHistory.single.title, 'Saved');
    expect(state.loadFailed, isTrue);
  });

  test('stale refresh cannot overwrite a newer result or status', () async {
    final old = notifier.requests.single;
    final retry = notifier.refresh();
    notifier.requests.last.complete([row('New')]);
    await retry;
    old.complete([row('Old')]);
    await tick();
    final state = container.read(historyPageProvider);
    expect(state.history.map((e) => e.title), ['New']);
    expect(state.isLoading || state.loadFailed, isFalse);
  });

  test('late completion after disposal is ignored', () async {
    final pending = notifier.requests.single;
    container.dispose();
    disposed = true;
    pending.complete([row('Late')]);
    await tick();
  });
}
