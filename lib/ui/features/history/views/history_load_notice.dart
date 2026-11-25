import 'package:material_ui/material_ui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:miru_alpha/provider/home/history_page_provider.dart';
import 'package:miru_alpha/utils/core/i18n.dart';

/// Shared by history and continue-watching: never describe a failure as empty.
class HistoryLoadNotice extends ConsumerWidget {
  const HistoryLoadNotice({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(historyPageProvider);
    if (!state.isLoading && !state.loadFailed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(height: 8),
          Semantics(
            liveRegion: true,
            child: Text(
              (state.isLoading
                      ? 'history_tools.loading'
                      : 'history_tools.load_failed')
                  .i18n,
              textAlign: TextAlign.center,
            ),
          ),
          if (state.loadFailed)
            TextButton(
              key: const ValueKey('history-retry'),
              onPressed: () => ref.read(historyPageProvider.notifier).refresh(),
              child: Text('common.retry'.i18n),
            ),
        ],
      ),
    );
  }
}
