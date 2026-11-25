import 'package:miru_alpha/model/index.dart';
import 'package:miru_alpha/provider/backend_connection_provider.dart';
import 'package:miru_alpha/utils/core/log.dart';
import 'package:miru_alpha/utils/store/database_service.dart';
import 'package:miru_alpha/utils/store/history_list_rules.dart';
import 'package:miru_alpha/ui/core/core/toast.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'history_page_provider.g.dart';

class HistoryPageState {
  final List<History> history;
  final List<History> filteredHistory;
  final bool isLoading;
  final bool loadFailed;
  HistoryPageState({
    required this.history,
    required this.filteredHistory,
    this.isLoading = false,
    this.loadFailed = false,
  });

  HistoryPageState copyWith({
    List<History>? history,
    List<History>? filteredHistory,
    bool? isLoading,
    bool? loadFailed,
  }) {
    return HistoryPageState(
      filteredHistory: filteredHistory ?? this.filteredHistory,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      loadFailed: loadFailed ?? this.loadFailed,
    );
  }
}

@Riverpod(keepAlive: true)
class HistoryPageNotifier extends _$HistoryPageNotifier {
  final _deletedKeys = <HistoryDeleteIdentity>{};
  final _deletingKeys = <HistoryDeleteIdentity>{};
  final _rules = HistoryListRules<History>(
    (entry) => (
      package: entry.package,
      url: entry.url,
      detailUrl: entry.detailUrl,
      type: stringToExtensionType(entry.type).name,
      title: entry.title,
      date: entry.date,
    ),
  );
  String keyword = '';
  Duration duration = const Duration(days: 36500);
  Set<ExtensionType> _type = {};
  int _loadEpoch = 0;

  @override
  HistoryPageState build() {
    ref.onDispose(() => _loadEpoch++);
    Future.microtask(refresh);
    return HistoryPageState(history: [], filteredHistory: [], isLoading: true);
  }

  /// Overridable for offline provider tests; production uses the backend gate.
  Future<List<History>> fetchHistories() async {
    await ref.read(backendConnectionProvider.future);
    if (!ref.mounted) return [];
    return DatabaseService.getHistoriesByType();
  }

  /// Latest refresh wins. Keep existing rows when the backend is unavailable.
  Future<void> refresh() async {
    if (!ref.mounted) return;
    final epoch = ++_loadEpoch;
    state = state.copyWith(isLoading: true, loadFailed: false);
    try {
      final history = await fetchHistories().timeout(
        const Duration(seconds: 20),
      );
      if (!ref.mounted || epoch != _loadEpoch) return;
      state = state.copyWith(
        history: _rules.merge(state.history, history, deleted: _deletedKeys),
        isLoading: false,
        loadFailed: false,
      );
      filter(_type, keyword, duration);
    } catch (error, stack) {
      if (!ref.mounted || epoch != _loadEpoch) return;
      state = state.copyWith(isLoading: false, loadFailed: true);
      logger.warning('Failed to load history', error, stack);
    }
  }

  Future<void> addHistory(History history) async {
    await DatabaseService.putHistory(history);
    if (!ref.mounted) return;
    _deletedKeys.remove(_rules.deleteIdentity(history));
    state = state.copyWith(history: _rules.upsert(state.history, history));
    filter(_type, keyword, duration);
    logger.fine('register history ${history.title}');
  }

  Future<void> deleteHistory(History history) async {
    final key = _rules.deleteIdentity(history);
    if (!_deletingKeys.add(key)) return;
    try {
      // Do not hide data until the backend actually confirms deletion.
      await DatabaseService.deleteHistoryByPackageAndUrl(key.$1, key.$2);
      if (!ref.mounted) return;
      _deletedKeys.add(key);
      state = state.copyWith(history: _rules.remove(state.history, key));
      filter(_type, keyword, duration);
    } catch (error, stack) {
      logger.warning('Failed to delete history', error, stack);
      if (ref.mounted) showSimpleToast('history_tools.delete_failed'.i18n);
    } finally {
      _deletingKeys.remove(key);
    }
  }

  void filterWithDuration(Duration duration) =>
      filter(_type, keyword, duration);

  void filterWithType(Set<ExtensionType> type) =>
      filter(type, keyword, duration);

  /// Convenience used by the router-driven list views. `null` or
  /// [ExtensionType.all] clears the type filter; otherwise a single type is
  /// applied.
  void setTypeFilter(ExtensionType? type) {
    filterWithType(type == null || type == ExtensionType.all ? {} : {type});
  }

  void filter(Set<ExtensionType> type, String keyword, Duration duration) {
    _type = type.contains(ExtensionType.all) ? {} : Set.of(type);
    this.keyword = keyword;
    this.duration = duration;
    state = state.copyWith(
      filteredHistory: _rules.filter(
        state.history,
        types: _type.map((value) => value.name).toSet(),
        keyword: keyword,
        duration: duration,
        now: DateTime.now(),
      ),
    );
  }

  void filterWithKeyword(String keyword) => filter(_type, keyword, duration);
}
