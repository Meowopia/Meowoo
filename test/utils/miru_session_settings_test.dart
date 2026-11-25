import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:miru_alpha/utils/store/miru_settings.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('miru_session_settings');
    MiruSettings.sessionFilePathOverride =
        '${tempDir.path}/session_settings.json';
    MiruSettings.seedDefaultsForTest();
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
    MiruSettings.sessionFilePathOverride = null;
  });

  test('a tracked write mirrors into the session file', () {
    MiruSettings.setSettingSync('Theme', 'dark');

    final written = jsonDecode(
      File(MiruSettings.sessionFilePathOverride!).readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(written['Theme'], 'dark');
    expect(
      MiruSettings.getSettingSync<String>('Theme'),
      'dark',
      reason: 'cache stays the source the UI reads',
    );
  });

  test('untracked keys never land in the session file', () {
    MiruSettings.setSettingSync('DownloadPath', '/tmp/x');

    // No tracked write happened, so nothing was written at all.
    expect(File(MiruSettings.sessionFilePathOverride!).existsSync(), isFalse);
  });

  test('loadSessionSettings overrides the seeded defaults', () {
    File(MiruSettings.sessionFilePathOverride!).writeAsStringSync(
      jsonEncode({'Theme': 'light', SettingKey.language: 'en'}),
    );

    // Simulate the bootstrap order: defaults first, session copy second.
    MiruSettings.seedDefaultsForTest();
    MiruSettings.loadSessionSettings();

    expect(MiruSettings.getSettingSync<String>('Theme'), 'light');
    expect(MiruSettings.getSettingSync<String>(SettingKey.language), 'en');
    // Keys absent from the session file keep the default.
    expect(MiruSettings.getSettingSync<String>('BaseColor'), 'zinc');
  });

  test('old auto-written English does not override the Chinese default', () {
    File(MiruSettings.sessionFilePathOverride!)
        .writeAsStringSync(jsonEncode({'Theme': 'dark', 'Language': 'en'}));
    MiruSettings.loadSessionSettings();
    expect(MiruSettings.getSettingSync<String>(SettingKey.language), 'zh');
    expect(MiruSettings.getSettingSync<String>(SettingKey.theme), 'dark');
  });

  test('manual English survives restarting the app', () {
    MiruSettings.setSettingSync(SettingKey.language, 'en');
    MiruSettings.seedDefaultsForTest();
    MiruSettings.loadSessionSettings();
    expect(MiruSettings.getSettingSync<String>(SettingKey.language), 'en');
  });

  test('app-owned download fallback does not override a chosen path', () {
    MiruSettings.setDefaultDownloadPath('/private/meowoo/downloads');
    expect(
      MiruSettings.getSettingSync<String>(SettingKey.downloadPath),
      '/private/meowoo/downloads',
    );
    MiruSettings.setSettingSync(SettingKey.downloadPath, '/tmp/chosen');
    expect(
      MiruSettings.getSettingSync<String>(SettingKey.downloadPath),
      '/tmp/chosen',
    );
  });

  test('a corrupt session file is ignored, not fatal', () {
    File(MiruSettings.sessionFilePathOverride!).writeAsStringSync('{oops');

    MiruSettings.loadSessionSettings();

    expect(
      MiruSettings.getSettingSync<String>('Theme'),
      'system',
      reason: 'cache keeps the seeded default',
    );
  });
}
