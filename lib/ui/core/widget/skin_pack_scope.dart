import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart' show FTheme;
import 'package:miru_alpha/utils/theme/skin_pack.dart';

class SkinPackScope extends InheritedWidget {
  const SkinPackScope({super.key, required this.pack, required super.child});
  final SkinPack? pack;

  static SkinPack? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkinPackScope>()?.pack;

  @override
  bool updateShouldNotify(SkinPackScope oldWidget) => pack != oldWidget.pack;
}

/// Keeps Material buttons/list tiles in sync with the Forui skin palette.
/// This is a presentation-only scope, also usable inside a local preview.
class SkinMaterialSurface extends StatelessWidget {
  const SkinMaterialSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = FTheme.of(context).colors;
    final base = Theme.of(context);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: colors.brightness,
        ).copyWith(
          primary: colors.primary,
          onPrimary: colors.primaryForeground,
          secondary: colors.secondary,
          onSecondary: colors.secondaryForeground,
          surface: colors.card,
          onSurface: colors.foreground,
          onSurfaceVariant: colors.mutedForeground,
          outline: colors.border,
          error: colors.error,
          onError: colors.errorForeground,
        );
    return Theme(
      data: base.copyWith(
        colorScheme: scheme,
        scaffoldBackgroundColor: colors.background,
        textTheme: base.textTheme.apply(
          bodyColor: colors.foreground,
          displayColor: colors.foreground,
        ),
        listTileTheme: ListTileThemeData(
          textColor: colors.foreground,
          iconColor: colors.primary,
        ),
        iconTheme: IconThemeData(color: colors.primary),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.primary,
            side: BorderSide(color: colors.border),
          ),
        ),
      ),
      child: ColoredBox(
        key: const ValueKey('skin-material-surface'),
        color: colors.background,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colors.foreground),
          child: child,
        ),
      ),
    );
  }
}

/// Original Meowoo header treatment; no third-party artwork or account data.
class SkinPackHeader extends StatelessWidget {
  const SkinPackHeader({super.key, required this.pack, required this.subtitle});
  final SkinPack pack;
  final String subtitle;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    key: const ValueKey('skin-pack-header'),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(pack.cardRadius),
      gradient: LinearGradient(
        colors: [Color(pack.headerStartColor), Color(pack.headerEndColor)],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          DecoratedBox(
            key: const ValueKey('skin-pack-avatar-frame'),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Color(pack.avatarFrameColor), width: 3),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  'assets/icon/meowoo-skin-avatar.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  excludeFromSemantics: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Color(0xff15354a)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meowoo',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
