/// The Core upsert key is (package, episode URL, detail URL). IDs can still be
/// zero on locally created rows, so they must not identify a list operation.
typedef HistoryIdentity = (String, String, String);

/// The existing Core delete RPC removes all rows for (package, episode URL).
/// Keep the visible list consistent with that contract, not a pretend ID delete.
typedef HistoryDeleteIdentity = (String, String);
typedef HistoryFields = ({
  String package,
  String url,
  String detailUrl,
  String type,
  String title,
  DateTime date,
});

class HistoryListRules<T> {
  const HistoryListRules(this.fields);
  final HistoryFields Function(T) fields;

  HistoryIdentity identity(T value) {
    final f = fields(value);
    return (f.package, f.url, f.detailUrl);
  }

  HistoryDeleteIdentity deleteIdentity(T value) {
    final f = fields(value);
    return (f.package, f.url);
  }

  /// Current local writes win over a delayed bootstrap snapshot. Successful
  /// deletes stay excluded until an explicit new local write clears the marker.
  List<T> merge(
    List<T> current,
    List<T> incoming, {
    Set<HistoryDeleteIdentity> deleted = const {},
  }) {
    final rows = <HistoryIdentity, T>{};
    for (final row in [...current, ...incoming]) {
      if (!deleted.contains(deleteIdentity(row))) {
        rows.putIfAbsent(identity(row), () => row);
      }
    }
    return rows.values.toList()
      ..sort((a, b) => fields(b).date.compareTo(fields(a).date));
  }

  /// Network acknowledgements may finish out of order. A late older checkpoint
  /// cannot replace a more recent local checkpoint for the same episode.
  List<T> upsert(List<T> rows, T value) {
    var latest = value;
    for (final row in rows) {
      if (identity(row) == identity(value) &&
          fields(row).date.isAfter(fields(latest).date)) {
        latest = row;
      }
    }
    final others = rows
        .where((row) => identity(row) != identity(value))
        .toList();
    return merge([latest], others);
  }

  List<T> remove(List<T> rows, HistoryDeleteIdentity key) =>
      rows.where((row) => deleteIdentity(row) != key).toList();

  /// Every control uses the same combined predicate. Empty/all means no type
  /// restriction; changing a type must not silently erase keyword/date filters.
  List<T> filter(
    List<T> rows, {
    Set<String> types = const {},
    String keyword = '',
    required Duration duration,
    required DateTime now,
  }) {
    final query = keyword.trim().toLowerCase();
    final allTypes = types.isEmpty || types.contains('all');
    return rows.where((row) {
      final f = fields(row);
      return (allTypes || types.contains(f.type)) &&
          (query.isEmpty || f.title.toLowerCase().contains(query)) &&
          (duration == const Duration(days: 36500) ||
              now.difference(f.date) <= duration);
    }).toList();
  }
}

/// Until Core has a type-scoped, transactional delete RPC, only an explicit
/// global-clear request may reach its deleteAllHistory method.
void requireGlobalHistoryClear(String type) {
  if (type != 'all') {
    throw UnsupportedError(
      'Core does not support type-scoped history clearing.',
    );
  }
}
