import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:miru_alpha/ui/core/widget/miru_card.dart';
import 'package:miru_alpha/ui/core/widget/skin_pack_scope.dart';
import 'package:miru_alpha/utils/theme/skin_pack.dart';
import 'package:miru_alpha/utils/theme/theme.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('My surfaces follow the applied pack with dark=$dark', (
      tester,
    ) async {
      for (final pack in builtInSkinPacks) {
        final colors = ThemeUtils.composeColors(
          pack.baseColor,
          pack.primaryColor,
          !dark,
        );
        final skinTheme = ThemeUtils.getThemeData(
          dark
              ? ThemeUtils.resolveDarkTheme(pack.baseColor, pack.primaryColor)
              : ThemeUtils.resolveTheme(pack.baseColor, pack.primaryColor),
        );
        ThemeData? material;
        await tester.pumpWidget(
          MaterialApp(
            // ignore: deprecated_member_use
            builder: (_, child) => MaterialUiCompatibilityBridge(child: child!),
            home: FTheme(
              data: skinTheme,
              child: SkinPackScope(
                pack: pack,
                child: SkinMaterialSurface(
                  child: Builder(
                    builder: (context) {
                      material = Theme.of(context);
                      return Column(
                        children: [
                          SkinPackHeader(pack: pack, subtitle: 'test'),
                          const MiruCard(child: Text('card')),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(material!.colorScheme.primary, colors.primary);
        expect(material!.colorScheme.brightness, colors.brightness);
        expect(material!.listTileTheme.iconColor, colors.primary);
        final background = tester.widget<ColoredBox>(
          find.byKey(const ValueKey('skin-material-surface')),
        );
        expect(background.color, colors.background);
        final frame =
            tester
                    .widget<DecoratedBox>(
                      find.byKey(const ValueKey('skin-pack-avatar-frame')),
                    )
                    .decoration
                as BoxDecoration;
        expect(
          (frame.border as Border).top.color,
          Color(pack.avatarFrameColor),
        );
        final card = tester.widget<FCard>(find.byType(FCard));
        final style = card.style(skinTheme.cardStyle);
        final decoration = style.decoration as ShapeDecoration;
        expect(
          (decoration.shape as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(pack.cardRadius),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}
