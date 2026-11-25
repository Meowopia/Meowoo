import 'dart:convert';
import 'dart:io';

import 'package:miru_alpha/utils/store/appearance_session.dart';
import 'package:miru_alpha/utils/theme/skin_pack.dart';

void require(bool value, String message) {
  if (!value) throw StateError(message);
}

void main() {
  final directory = Directory.systemTemp.createTempSync('meowoo-appearance-');
  try {
    final file = File('${directory.path}/session.json');
    for (final skin in builtInSkinPacks) {
      writeAppearanceSession(file, {
        'MeowooSkinPackId': skin.id,
        'Theme': 'dark',
        'BaseColor': skin.baseColor,
        'PrimaryColor': skin.primaryColor,
      });
      final loaded =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      require(loaded['MeowooSkinPackId'] == skin.id, 'Pack identity was lost');
      require(loaded['Theme'] == 'dark', 'Mode changed');
      require(
        skinPackById(loaded['MeowooSkinPackId'] as String) == skin,
        'Restart lookup failed',
      );
    }
    final prior =
        jsonDecode(File('${file.path}.bak').readAsStringSync()) as Map;
    require(prior['MeowooSkinPackId'] == 'ocean', 'Old snapshot not backed up');
    final current = file.readAsStringSync();
    final blocked = Directory('${file.path}.$pid.tmp')..createSync();
    try {
      writeAppearanceSession(file, {'MeowooSkinPackId': 'meowoo'});
      throw StateError('Expected failed write');
    } on FileSystemException {
      require(
        file.readAsStringSync() == current,
        'Failed write damaged current skin',
      );
    } finally {
      blocked.deleteSync();
    }
    require(!File('${file.path}.$pid.tmp').existsSync(), 'Staging file leaked');
    stdout.writeln(
      'Passed pack reload, mode preservation, backup and failed-write checks.',
    );
  } finally {
    directory.deleteSync(recursive: true);
  }
}
