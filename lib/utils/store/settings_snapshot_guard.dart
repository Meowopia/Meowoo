/// Full backend reads must not undo preferences edited during this app session.
/// This is a local-intent policy, not cross-device conflict resolution.
class SettingsSnapshotGuard {
  final _localEdits = <String>{};
  int _readEpoch = 0;

  int beginRead() => ++_readEpoch;
  bool accepts(int epoch) => epoch == _readEpoch;
  void edited(Iterable<String> keys) => _localEdits.addAll(keys);

  Map<String, String> merge({
    required Map<String, String> remote,
    required Map<String, String> defaults,
    required Map<String, String> local,
    Set<String> deviceLocalKeys = const {},
  }) {
    // Missing backend keys do not erase the last-known bootstrap/session value.
    final next = {...defaults, ...local, ...remote};
    for (final key in {..._localEdits, ...deviceLocalKeys}) {
      if (local.containsKey(key)) next[key] = local[key]!;
    }
    return next;
  }

  /// Invalidate in-flight test reads as well as clearing the remembered intent.
  void reset() {
    _readEpoch++;
    _localEdits.clear();
  }
}
