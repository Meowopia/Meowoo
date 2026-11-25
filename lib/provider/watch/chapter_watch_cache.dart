import 'package:miru_alpha/model/extension_meta_data.dart';
import 'package:miru_alpha/model/watch_result.dart';
import 'package:miru_alpha/provider/extension_provider.dart' show resolveWatch;
import 'package:miru_alpha/utils/store/nsfw_session.dart';
import 'package:miru_alpha/utils/watch/scoped_chapter_cache.dart';

/// Resolved-watch cache shared by the watch session and the reader windows.
///
/// The webtoon window prefetches adjacent chapters as the reader scrolls and
/// flips the tracked chapter mid-session. Without a store every flip
/// re-issued the watch call and flipped the session to `AsyncLoading`, which
/// mounted the loading screen over the whole reader while the chapter
/// re-resolved. This is a small bounded LRU: only a handful of chapters are
/// ever near the viewport, so a six-entry cap is generous.
class WatchChapterCache {
  static const int maxEntries = 6;

  static final _cache = ScopedChapterCache<WatchResult>(maxEntries: maxEntries);

  /// Overridable resolver so tests can count calls and avoid the network.
  /// Production uses [resolveWatch].
  static Future<WatchResult> Function({
    required String watchUrl,
    required String detailUrl,
    required ExtensionMeta meta,
    String? mirrorUrl,
  })
  resolver = _defaultResolve;

  static Future<WatchResult> _defaultResolve({
    required String watchUrl,
    required String detailUrl,
    required ExtensionMeta meta,
    String? mirrorUrl,
  }) {
    return resolveWatch(
      watchUrl: watchUrl,
      detailUrl: detailUrl,
      meta: meta,
      mirrorUrl: mirrorUrl,
    );
  }

  static ChapterCacheKey _key({
    required String package,
    required String detailUrl,
    required String watchUrl,
    String? mirrorUrl,
  }) => (
    package: package,
    detailUrl: detailUrl,
    watchUrl: watchUrl,
    mirrorUrl: mirrorUrl,
  );

  static WatchResult? peek(
    String watchUrl, {
    required String package,
    required String detailUrl,
    String? mirrorUrl,
  }) => _cache.peek(
    _key(
      package: package,
      detailUrl: detailUrl,
      watchUrl: watchUrl,
      mirrorUrl: mirrorUrl,
    ),
  );

  static Future<WatchResult> resolve({
    required String watchUrl,
    required String detailUrl,
    required ExtensionMeta meta,
    String? mirrorUrl,
  }) async {
    if (meta.nsfw) nsfwSession.markRestricted(meta.packageName);
    if (nsfwSession.isRestricted(meta.packageName)) {
      return nsfwSession.run(
        meta.packageName,
        () => resolver(
          watchUrl: watchUrl,
          detailUrl: detailUrl,
          meta: meta,
          mirrorUrl: mirrorUrl,
        ),
      );
    }
    return _cache.resolve(
      _key(
        package: meta.packageName,
        detailUrl: detailUrl,
        watchUrl: watchUrl,
        mirrorUrl: mirrorUrl,
      ),
      () => resolver(
        watchUrl: watchUrl,
        detailUrl: detailUrl,
        meta: meta,
        mirrorUrl: mirrorUrl,
      ),
    );
  }

  static void clear() => _cache.clear();
}
