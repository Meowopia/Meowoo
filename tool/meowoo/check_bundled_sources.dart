import 'dart:io';

import 'package:miru_alpha/utils/store/bundled_sources.dart';

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  final sandbox = await Directory.systemTemp.createTemp('meowoo-source-seed-');
  int loads = 0;
  Future<String> loadAsset(String path) async {
    loads++;
    return File(path).readAsString();
  }

  try {
    final clean = await Directory('${sandbox.path}/clean').create();
    try {
      await seedBundledSources(clean, loadAsset: (_) async => '// invalid');
      throw StateError('accepted invalid metadata');
    } on FormatException {
      // The next run must still be able to install a valid bundle.
    }
    await seedBundledSources(clean, loadAsset: loadAsset);
    for (final name in bundledSourceFiles) {
      require(await File('${clean.path}/$name').exists(), 'install $name');
    }
    loads = 0;
    final existing = File('${sandbox.path}/${bundledSourceFiles.first}');
    await existing.writeAsString('user-owned source');
    await seedBundledSources(sandbox, loadAsset: loadAsset);
    require(await existing.readAsString() == 'user-owned source', 'overwrite');
    final bundled = File('${sandbox.path}/${bundledSourceFiles.last}');
    require(await bundled.exists(), 'initial install');
    require(loads == 1, 'only missing sources read from APK assets');

    await bundled.delete();
    await seedBundledSources(sandbox, loadAsset: loadAsset);
    require(!await bundled.exists(), 'uninstalled source reappeared');
    require(loads == 1, 'assets read again');
    stdout.writeln('Bundled source installation checks passed.');
  } finally {
    await sandbox.delete(recursive: true);
  }
}
