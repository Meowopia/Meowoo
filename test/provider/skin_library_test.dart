import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:miru_alpha/provider/application_controller_provider.dart';
import 'package:miru_alpha/utils/store/miru_settings.dart';
import 'package:miru_alpha/utils/theme/skin_library.dart';
import 'package:miru_alpha/utils/theme/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ProviderContainer container;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('meowoo_skin_test_');
    MiruSettings.sessionFilePathOverride = '${directory.path}/settings.json';
    MiruSettings.seedDefaultsForTest();
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
    MiruSettings.sessionFilePathOverride = null;
    directory.deleteSync(recursive: true);
  });

  test(
    'skin catalog contains unique valid palettes with reversible lookup',
    () {
      expect(
        miruSkinLibrary.map((s) => s.id).toSet().length,
        miruSkinLibrary.length,
      );
      for (final skin in miruSkinLibrary) {
        expect(selectableBaseColorNames, contains(skin.baseColor));
        expect(primaryColorNames, contains(skin.primaryColor));
        expect(miruSkinById(skin.id), same(skin));
        expect(currentMiruSkinId(skin.baseColor, skin.primaryColor), skin.id);
      }
      expect(miruSkinById('unknown'), isNull);
      expect(currentMiruSkinId('unknown', 'unknown'), isNull);
    },
  );

  for (final mode in ['system', 'light', 'dark']) {
    test('skin selection and session reload preserve $mode mode', () {
      MiruSettings.setSettingSync(SettingKey.theme, mode);
      final controller = container.read(applicationControllerProvider.notifier);
      controller.applySkin('ocean');
      final selected = container.read(applicationControllerProvider);
      expect(selected.baseColor, 'mist');
      expect(selected.primaryColor, 'cyan');
      expect(selected.themeText, mode);
      final written = jsonDecode(
        File(MiruSettings.sessionFilePathOverride!).readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(written[SettingKey.baseColor], 'mist');
      expect(written[SettingKey.accentColor], 'cyan');
      expect(written[SettingKey.theme], mode);

      MiruSettings.seedDefaultsForTest();
      MiruSettings.loadSessionSettings();
      controller.reloadFromSettings();
      final restored = container.read(applicationControllerProvider);
      expect(restored.baseColor, 'mist');
      expect(restored.primaryColor, 'cyan');
      expect(restored.themeText, mode);
      expect(restored.themeMode, selected.themeMode);
    });
  }

  test('unknown skin leaves state and session settings unchanged', () {
    final controller = container.read(applicationControllerProvider.notifier);
    final before = container.read(applicationControllerProvider);
    controller.applySkin('unknown');
    expect(container.read(applicationControllerProvider), same(before));
    expect(File(MiruSettings.sessionFilePathOverride!).existsSync(), isFalse);
  });

  test('Amoei restores its palette while allowing brightness changes', () {
    MiruSettings.setSettingSync(SettingKey.theme, 'light');
    final controller = container.read(applicationControllerProvider.notifier);
    controller.applySkin(amoeiSkin.id);
    expect(
      container.read(applicationControllerProvider).themeData.colors.primary,
      const Color(0xFF3658BE),
    );
    controller.changeTheme('dark');
    MiruSettings.seedDefaultsForTest();
    MiruSettings.loadSessionSettings();
    controller.reloadFromSettings();
    final restored = container.read(applicationControllerProvider);
    expect(
      currentMiruSkinId(restored.baseColor, restored.primaryColor),
      'amoei',
    );
    expect(restored.themeText, 'dark');
    expect(restored.themeData.colors.primary, const Color(0xFF8DAFFF));

    controller.applySkin('classic');
    final other = container.read(applicationControllerProvider);
    expect(currentMiruSkinId(other.baseColor, other.primaryColor), 'classic');
    expect(other.themeText, 'dark');
  });

  test('Amoei text pairs meet 4.5:1 contrast in both palettes', () {
    for (final light in [true, false]) {
      final colors = ThemeUtils.composeColors(
        amoeiSkin.baseColor,
        amoeiSkin.primaryColor,
        light,
      );
      for (final (foreground, background) in [
        (colors.foreground, colors.background),
        (colors.foreground, colors.card),
        (colors.primaryForeground, colors.primary),
        (colors.secondaryForeground, colors.secondary),
        (colors.mutedForeground, colors.muted),
        (colors.mutedForeground, colors.card),
        (colors.destructiveForeground, colors.destructive),
      ]) {
        final a = foreground.computeLuminance() + 0.05;
        final b = background.computeLuminance() + 0.05;
        expect(a > b ? a / b : b / a, greaterThanOrEqualTo(4.5));
      }
    }
  });
}
