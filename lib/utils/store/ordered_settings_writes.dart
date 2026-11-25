import 'dart:async';

/// Serialize each key independently. An old acknowledgement must not publish
/// over a newer choice, and a failed request must not poison subsequent writes.
class OrderedSettingsWrites {
  final _tails = <String, Future<void>>{};
  final _latest = <String, int>{};
  int _revision = 0;

  Future<void> write({
    required String key,
    required String value,
    required Future<void> Function(String key, String value) send,
    required void Function(String key, String value) onCommitted,
  }) {
    final revision = ++_revision;
    _latest[key] = revision;
    final previous = _tails[key] ?? Future<void>.value();
    final operation = previous.then((_) async {
      await send(key, value);
      if (_latest[key] == revision) onCommitted(key, value);
    });
    // Keep only an error-handled tail in the queue. The caller still receives
    // the original error through operation and can report it or retry.
    final tail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tails[key] = tail;
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[key], tail)) _tails.remove(key);
      }),
    );
    return operation;
  }
}
