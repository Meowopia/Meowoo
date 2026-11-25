import 'dart:async';

final nsfwSession = NsfwSession();

class NsfwUnavailable implements Exception {
  const NsfwUnavailable();
  @override
  String toString() => 'NSFW is disabled';
}

/// No provider URL, title or mirror payload is exposed to generic error UIs.
class NsfwContentLoadFailed implements Exception {
  const NsfwContentLoadFailed();
  @override
  String toString() => 'Could not load restricted content';
}

/// Client-side gate for explicitly restricted packages. A revoked operation
/// remains revoked even if the setting is turned on again before it finishes.
class NsfwSession {
  final _packages = <String>{};
  final _changes = StreamController<bool>.broadcast(sync: true);
  bool _enabled = false;
  int _epoch = 0;

  bool get enabled => _enabled;
  int get epoch => _epoch;
  Stream<bool> get changes => _changes.stream;

  void setEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    _epoch++;
    _changes.add(value);
  }

  // Don't let a later false/missing flag erase a known restricted label.
  void markRestricted(String package) {
    if (package.isNotEmpty) _packages.add(package);
  }

  bool isRestricted(String package) => _packages.contains(package);

  Future<T> run<T>(
    String package,
    Future<T> Function() operation, {
    Future<void> Function()? cancel,
  }) async {
    if (!isRestricted(package)) return operation();
    if (!_enabled) throw const NsfwUnavailable();
    final epoch = _epoch;
    final listener = cancel == null
        ? null
        : changes.listen((enabled) {
            if (!enabled) unawaited(_cancelQuietly(cancel));
          });
    try {
      final result = await operation();
      if (_epoch != epoch) throw const NsfwUnavailable();
      return result;
    } catch (error) {
      if (_epoch != epoch) throw const NsfwUnavailable();
      if (error is NsfwUnavailable) rethrow;
      throw const NsfwContentLoadFailed();
    } finally {
      if (listener != null) unawaited(listener.cancel());
    }
  }

  static Future<void> _cancelQuietly(Future<void> Function() cancel) async {
    try {
      await cancel();
    } catch (_) {
      // The request may already have completed. Epoch checking still applies.
    }
  }
}
