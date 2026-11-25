import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:miru_alpha/ui/features/setting/my_overview.dart';
import 'package:miru_alpha/utils/theme/miru_themes.dart';

void main() {
  for (final shortcut in ['history', 'favorites', 'downloads']) {
    testWidgets('My page opens the existing $shortcut destination', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final destinations = {
        'history': '/home/history',
        'favorites': '/home/favorite',
        'downloads': '/home/download',
      };
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: MyOverview()),
            ),
          ),
          for (final entry in destinations.entries)
            GoRoute(
              path: entry.value,
              builder: (_, _) => Scaffold(body: Text('opened-${entry.key}')),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          // ignore: deprecated_member_use
          builder: (_, child) => MaterialUiCompatibilityBridge(
            child: FTheme(data: MiruThemes.neutral.light.touch, child: child!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cloud = tester.widget<ListTile>(
        find.byKey(const ValueKey('my-cloud-unavailable')),
      );
      expect(cloud.enabled, isFalse);
      expect(cloud.onTap, isNull);
      final target = find.byKey(ValueKey('my-$shortcut'));
      await tester.ensureVisible(target);
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(find.text('opened-$shortcut'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
