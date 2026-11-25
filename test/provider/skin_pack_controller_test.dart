import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:miru_alpha/provider/application_controller_provider.dart';
import 'package:miru_alpha/utils/store/miru_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProviderContainer container;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('meowoo-pack-test-');
    MiruSettings.sessionFilePathOverride = '${directory.path}/session.json';
    MiruSettings.seedDefaultsForTest();
    container = ProviderContainer();
  });
  tearDown(() {
    container.dispose();
    MiruSettings.sessionFilePathOverride = null;
    directory.deleteSync(recursive: true);
  });
  for (final mode in ['light', 'dark', 'system']) {
    test('preview, apply, restart and restore preserve $mode mode', () {
      MiruSettings.setSettingSync(SettingKey.theme, mode);
      final controller = container.read(applicationControllerProvider.notifier);
      final before = container.read(applicationControllerProvider);
      final savedBefore = File(MiruSettings.sessionFilePathOverride!)
          .readAsStringSync();
      controller.currentThemeData('dark', 'mauve', 'pink');
      expect(container.read(applicationControllerProvider), same(before));
      expect(
        File(MiruSettings.sessionFilePathOverride!).readAsStringSync(),
        savedBefore,
      );
      expect(controller.applySkinPack('ocean'), isTrue);
      final applied = container.read(applicationControllerProvider);
      expect(applied.skinPack?.id, 'ocean');
      expect(applied.themeText, mode);
      MiruSettings.seedDefaultsForTest();
      MiruSettings.loadSessionSettings();
      controller.reloadFromSettings();
      expect(
        container.read(applicationControllerProvider).skinPack?.id,
        'ocean',
      );
      expect(controller.applySkinPack('meowoo'), isTrue);
      expect(
        container.read(applicationControllerProvider).skinPack?.id,
        'meowoo',
      );
      expect(container.read(applicationControllerProvider).themeText, mode);
      controller.applySkin('amoei');
      expect(container.read(applicationControllerProvider).skinPack, isNull);
      expect(MiruSettings.getSettingSync<String>(SettingKey.skinPackId), '');
    });
  }
  test('unknown pack and failed storage leave current appearance intact', () {
    final controller = container.read(applicationControllerProvider.notifier);
    final before = container.read(applicationControllerProvider);
    expect(controller.applySkinPack('untrusted-unknown'), isFalse);
    expect(container.read(applicationControllerProvider), same(before));
    MiruSettings.sessionFilePathOverride =
        '${directory.path}/missing/session.json';
    expect(controller.applySkinPack('sakura'), isFalse);
    expect(container.read(applicationControllerProvider), same(before));
  });
}
