/// Relative chapter IDs are only unique within a source and work.
typedef ChapterCacheKey = ({
  String package,
  String detailUrl,
  String watchUrl,
  String? mirrorUrl,
});

/// Bounded LRU, single-flight loads and generation-safe invalidation.
/// Clearing does not cancel callers, but old loads cannot refill the cache.
class ScopedChapterCache<T extends Object> {
  ScopedChapterCache({this.maxEntries = 6}) {
    if (maxEntries < 1) throw ArgumentError.value(maxEntries, 'maxEntries');
  }
  final int maxEntries;
  final _entries = <ChapterCacheKey, T>{};
  final _pending = <ChapterCacheKey, Future<T>>{};
  int _generation = 0;

  T? peek(ChapterCacheKey key) {
    final value = _entries.remove(key);
    if (value != null) _entries[key] = value;
    return value;
  }

  Future<T> resolve(ChapterCacheKey key, Future<T> Function() load) {
    final hit = peek(key);
    if (hit != null) return Future.value(hit);
    final pending = _pending[key];
    if (pending != null) return pending;
    final generation = _generation;
    late final Future<T> task;
    task = Future<T>.sync(load)
        .then((value) {
          if (generation == _generation && identical(_pending[key], task)) {
            _entries[key] = value;
            while (_entries.length > maxEntries) {
              _entries.remove(_entries.keys.first);
            }
          }
          return value;
        })
        .whenComplete(() {
          if (identical(_pending[key], task)) _pending.remove(key);
        });
    _pending[key] = task;
    return task;
  }

  void clear() {
    _generation++;
    _entries.clear();
    _pending.clear();
  }
}
