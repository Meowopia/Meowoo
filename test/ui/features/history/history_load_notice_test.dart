import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:miru_alpha/provider/home/history_page_provider.dart';
import 'package:miru_alpha/ui/features/history/views/history_load_notice.dart';

class RetryHistoryNotifier extends HistoryPageNotifier {
  int retries = 0;
  @override
  HistoryPageState build() =>
      HistoryPageState(history: [], filteredHistory: [], loadFailed: true);
  @override
  Future<void> refresh() async {
    retries++;
  }
}

void main() {
  for (final loading in [true, false]) {
    testWidgets(
      loading ? 'loading shows progress, not retry' : 'failure offers retry',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              historyPageProvider.overrideWithValue(
                HistoryPageState(
                  history: [],
                  filteredHistory: [],
                  isLoading: loading,
                  loadFailed: !loading,
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: HistoryLoadNotice())),
          ),
        );
        expect(
          find.byType(CircularProgressIndicator),
          loading ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(const ValueKey('history-retry')),
          loading ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('success has no loading or error notice', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          historyPageProvider.overrideWithValue(
            HistoryPageState(history: [], filteredHistory: []),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: HistoryLoadNotice())),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byKey(const ValueKey('history-retry')), findsNothing);
    expect(find.byType(Text), findsNothing);
  });
  testWidgets('retry control invokes the controller', (tester) async {
    final notifier = RetryHistoryNotifier();
    final container = ProviderContainer(
      overrides: [historyPageProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: HistoryLoadNotice())),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('history-retry')));
    await tester.pump();
    expect(notifier.retries, 1);
  });
}
