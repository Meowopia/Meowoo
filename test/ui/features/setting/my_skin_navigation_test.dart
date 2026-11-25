import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:miru_alpha/provider/application_controller_provider.dart';
import 'package:miru_alpha/ui/core/widget/skin_pack_scope.dart';
import 'package:miru_alpha/ui/features/setting/my_overview.dart';
import 'package:miru_alpha/ui/features/setting/widget/skin_pack_gallery.dart';
import 'package:miru_alpha/utils/store/miru_settings.dart';

void main() {
  _saveFailureTests();
  for (final mode in ['light', 'dark']) {
    testWidgets('My skin route and local preview stay isolated in $mode mode', (
      tester,
    ) async {
      final directory = Directory.systemTemp.createTempSync('meowoo-skin-ui-');
      MiruSettings.sessionFilePathOverride = '${directory.path}/session.json';
      MiruSettings.seedDefaultsForTest();
      MiruSettings.setSettingSync(SettingKey.theme, mode);
      final container = ProviderContainer();
      addTearDown(() {
        container.dispose();
        MiruSettings.sessionFilePathOverride = null;
        directory.deleteSync(recursive: true);
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = container.read(applicationControllerProvider.notifier);
      expect(controller.applySkinPack('ocean'), isTrue);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(applicationControllerProvider);
              return MaterialApp(
                // Deliberately no app-wide Material skin: the pushed route
                // must bridge its own tokens, just like the actual app.
                // ignore: deprecated_member_use
                builder: (_, child) => MaterialUiCompatibilityBridge(
                  child: FTheme(
                    data: state.themeData,
                    child: SkinPackScope(pack: state.skinPack, child: child!),
                  ),
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(child: MyOverview()),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final skins = find.byKey(const ValueKey('my-skins'));
      await tester.ensureVisible(skins);
      await tester.tap(skins);
      await tester.pumpAndSettle();
      final openSakura = find.byKey(const ValueKey('preview-pack-sakura'));
      final routeContext = tester.element(openSakura);
      final actualTheme = Theme.of(routeContext);
      final current = container.read(applicationControllerProvider);
      expect(actualTheme.colorScheme.primary, current.themeData.colors.primary);
      expect(actualTheme.brightness, current.themeData.colors.brightness);
      final before = File(MiruSettings.sessionFilePathOverride!)
          .readAsStringSync();
      await tester.tap(openSakura);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final previewHeader = find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(SkinPackHeader),
      );
      final previewContext = tester.element(previewHeader);
      expect(Theme.of(previewContext).brightness, Brightness.dark);
      expect(SkinPackScope.of(previewContext)?.id, 'sakura');
      expect(container.read(applicationControllerProvider), same(current));
      expect(
        File(MiruSettings.sessionFilePathOverride!).readAsStringSync(),
        before,
      );
      Navigator.of(previewContext).pop();
      await tester.pumpAndSettle();
      expect(container.read(applicationControllerProvider), same(current));
      await tester.tap(openSakura);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('apply-preview-pack')));
      await tester.pumpAndSettle();
      expect(
        container.read(applicationControllerProvider).skinPack?.id,
        'sakura',
      );
      expect(container.read(applicationControllerProvider).themeText, mode);
      final updatedContext = tester.element(openSakura);
      expect(
        Theme.of(updatedContext).colorScheme.primary,
        container.read(applicationControllerProvider).themeData.colors.primary,
      );
      Navigator.of(tester.element(find.byType(SkinPackGallery))).pop();
      await tester.pumpAndSettle();
      final header = tester.widget<SkinPackHeader>(find.byType(SkinPackHeader));
      expect(header.pack.id, 'sakura');
      expect(tester.takeException(), isNull);
      // Dispose widgets before releasing their provider scope and files.
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

void _saveFailureTests() {
  testWidgets('Skin save failures stay visible without a Material Scaffold', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'meowoo-skin-failure-',
    );
    final goodPath = '${directory.path}/session.json';
    MiruSettings.sessionFilePathOverride = goodPath;
    MiruSettings.seedDefaultsForTest();
    final container = ProviderContainer();
    addTearDown(() {
      container.dispose();
      MiruSettings.sessionFilePathOverride = null;
      directory.deleteSync(recursive: true);
    });
    final controller = container.read(applicationControllerProvider.notifier);
    expect(controller.applySkinPack('ocean'), isTrue);
    final before = container.read(applicationControllerProvider);
    MiruSettings.sessionFilePathOverride =
        '${directory.path}/missing/session.json';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          // ignore: deprecated_member_use
          builder: (_, child) => MaterialUiCompatibilityBridge(
            child: FTheme(data: before.themeData, child: child!),
          ),
          home: const SingleChildScrollView(child: SkinPackGallery()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('restore-default-pack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skin-pack-save-error')), findsOneWidget);
    expect(container.read(applicationControllerProvider), same(before));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('preview-pack-sakura')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-preview-pack')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byKey(const ValueKey('skin-pack-save-error')),
      ),
      findsOneWidget,
    );
    expect(container.read(applicationControllerProvider), same(before));
    expect(tester.takeException(), isNull);
    MiruSettings.sessionFilePathOverride = goodPath;
    await tester.tap(find.byKey(const ValueKey('apply-preview-pack')));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    expect(
      container.read(applicationControllerProvider).skinPack?.id,
      'sakura',
    );
    await tester.tap(find.byKey(const ValueKey('restore-default-pack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('skin-pack-save-error')), findsNothing);
    expect(
      container.read(applicationControllerProvider).skinPack?.id,
      'meowoo',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
