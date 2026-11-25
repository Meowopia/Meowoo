import 'dart:io';

import 'package:path/path.dart' as p;

// Explicit list, not a directory scan: downloaded or third-party code must
// never get silently installed through this path.
const bundledSourceFiles = [
  'meowoo.open-films.js',
  'meowoo.playback-samples.js',
];

/// Provisions the two app-owned sources before Core scans its extension store.
/// Removals and edits are respected across app restarts. Sources already present
/// at these paths are never replaced by assets from a newer app.
Future<void> seedBundledSources(
  Directory directory, {
  required Future<String> Function(String asset) loadAsset,
}) async {
  await directory.create(recursive: true);
  final state = await Directory(p.join(directory.path, '.meowoo-bundled'))
      .create();
  final lockFile = await File(p.join(state.path, 'lock'))
      .open(mode: FileMode.append);
  try {
    await lockFile.lock(FileLock.blockingExclusive);
    for (final name in bundledSourceFiles) {
      final marker = File(p.join(state.path, '$name.installed'));
      if (await marker.exists()) continue;
      final destination = p.join(directory.path, name);
      if (await _missing(destination)) {
        final source = await loadAsset('assets/bundled_sources/$name');
        final packageName = p.basenameWithoutExtension(name);
        if (!RegExp(
          '^// @package +${RegExp.escape(packageName)}\$',
          multiLine: true,
        ).hasMatch(source)) {
          throw FormatException('Bad bundled source metadata: $name');
        }
        final staging = await state.createTemp('source-');
        final temp = File(p.join(staging.path, 'content'));
        try {
          await temp.writeAsString(source, flush: true);
          if (await _missing(destination)) await temp.rename(destination);
        } finally {
          if (await temp.exists()) await temp.delete();
          await staging.delete();
        }
      }
      // A marker survives extension removal so a user can permanently opt out.
      await marker.create();
    }
  } finally {
    await lockFile.close(); // Also releases the advisory lock.
  }
}

Future<bool> _missing(String pathname) async =>
    await FileSystemEntity.type(pathname, followLinks: false) ==
    FileSystemEntityType.notFound;
