import 'dart:async';
import 'dart:collection';

/// Owns every active/staged resource of one player session. A newer operation
/// invalidates old completions; closing also releases resources whose post-frame
/// retirement callback may never run after the route disappears.
class AsyncResourceSession<T extends Object> {
  AsyncResourceSession({required this.dispose, this.onDisposeError});
  final Future<void> Function(T resource) dispose;
  final void Function(Object error, StackTrace stack)? onDisposeError;
  final _owned = HashSet<T>.identity();
  final _releasing = HashMap<T, Future<void>>.identity();
  int _epoch = 0;
  bool _closed = false;
  Future<void>? _closing;

  bool get closed => _closed;
  int begin() {
    if (_closed) throw StateError('Resource session is closed');
    return ++_epoch;
  }

  bool accepts(int epoch) => !_closed && epoch == _epoch;

  void own(T resource) {
    _owned.add(resource);
    if (_closed) unawaited(release(resource));
  }

  Future<void> release(T resource) {
    final running = _releasing[resource];
    if (running != null) return running;
    if (!_owned.remove(resource)) return Future<void>.value();
    final operation = Future<void>.value().then((_) async {
      try {
        await dispose(resource);
      } catch (error, stack) {
        // Framework onDispose is synchronous: cleanup must never leak an
        // unhandled error, including when its diagnostic callback fails.
        try {
          onDisposeError?.call(error, stack);
        } catch (_) {}
      }
    });
    _releasing[resource] = operation;
    unawaited(
      operation.then((_) {
        _releasing.remove(resource);
      }),
    );
    return operation;
  }

  Future<void> close() {
    if (_closing != null) return _closing!;
    final completion = Completer<void>();
    _closing = completion.future;
    _closed = true;
    _epoch++;
    final pending = [..._releasing.values, ..._owned.toList().map(release)];
    unawaited(
      Future.wait(pending).then((_) {
        completion.complete();
      }),
    );
    return _closing!;
  }
}

Duration clampPlaybackPosition(Duration position, Duration duration) {
  if (position.isNegative || duration <= Duration.zero) return Duration.zero;
  return position > duration ? duration : position;
}
