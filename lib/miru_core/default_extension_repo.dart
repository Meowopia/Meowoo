import 'package:miru_alpha/model/model.dart';

/// Replaces the retired repository seeded by the pinned Miru Alpha Core.
/// This updates a catalogue pointer only; it never downloads extensions.
class DefaultExtensionRepoRepair {
  static const retiredName = 'Miru AlphaExtension';
  static const retiredUrl =
      'https://raw.githubusercontent.com/appdevelpo/repo/refs/heads/miru_alpha/index.json';
  static const replacementName = 'Miru Project';
  static const replacementUrl =
      'https://raw.githubusercontent.com/miru-project/repo/main/index.json';

  DefaultExtensionRepoRepair({
    required this.read,
    required this.add,
    required this.remove,
    required this.onError,
  });

  final Future<List<RepoConfig>> Function() read;
  final Future<void> Function(String url, String name) add;
  final Future<void> Function(String url) remove;
  final void Function(Object error, StackTrace stack) onError;

  Future<List<RepoConfig>>? _pending;

  // Both extension-store implementations and settings can request the list.
  // Do not let overlapping callers migrate the same row independently.
  Future<List<RepoConfig>> load() => _pending ??= _load().whenComplete(() {
    _pending = null;
  });

  Future<List<RepoConfig>> _load() async {
    final repos = await read();
    if (!repos.any((r) => r.link == retiredUrl && r.name == retiredName)) {
      return repos;
    }

    if (!repos.any((r) => r.link == replacementUrl)) {
      try {
        await add(replacementUrl, replacementName);
      } on Exception catch (error, stack) {
        // Keep the existing row if registration failed. A refresh retries.
        onError(error, stack);
        return repos;
      }
    }
    try {
      await remove(retiredUrl);
    } on Exception catch (error, stack) {
      // A cleanup failure does not prevent the replacement from being used.
      onError(error, stack);
    }
    return read();
  }
}
