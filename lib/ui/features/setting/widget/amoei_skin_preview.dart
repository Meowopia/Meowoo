import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:miru_alpha/utils/theme/skin_library.dart';
import 'package:miru_alpha/utils/theme/theme.dart';

/// In-place previews deliberately use their own palettes, not the app theme.
class AmoeiSkinPreview extends StatelessWidget with FTileMixin {
  const AmoeiSkinPreview({
    super.key,
    required this.isApplied,
    required this.onApply,
  });

  final bool isApplied;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = FTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'settings.labels.skins.amoei'.i18n,
            style: theme.typography.body.lg.copyWith(
              color: theme.colors.foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'settings.labels.amoei_skin.description'.i18n,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 320;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final light in [true, false])
                    SizedBox(
                      width: compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 8) / 2,
                      child: _BeaconSwatch(
                        light: light,
                        label:
                            (light
                                    ? 'settings.labels.light'
                                    : 'settings.labels.dark')
                                .i18n,
                        colors: ThemeUtils.composeColors(
                          amoeiSkin.baseColor,
                          amoeiSkin.primaryColor,
                          light,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (isApplied)
            Text(
              'settings.labels.amoei_skin.applied'.i18n,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.foreground,
              ),
            )
          else
            FButton(
              onPress: onApply,
              child: Text('settings.labels.amoei_skin.apply'.i18n),
            ),
        ],
      ),
    );
  }
}

class _BeaconSwatch extends StatelessWidget {
  const _BeaconSwatch({
    required this.light,
    required this.label,
    required this.colors,
  });

  final bool light;
  final String label;
  final FColors colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: CustomPaint(
                size: const Size.square(42),
                painter: _BeaconPainter(
                  blue: colors.primary,
                  wave: colors.mutedForeground,
                  gold: light
                      ? const Color(0xFF916315)
                      : const Color(0xFFF4CA76),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeaconPainter extends CustomPainter {
  const _BeaconPainter({
    required this.blue,
    required this.wave,
    required this.gold,
  });

  final Color blue;
  final Color wave;
  final Color gold;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 42, size.height / 42);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6
      ..color = blue;
    canvas.drawArc(const Rect.fromLTWH(10, 7, 22, 22), 2.6, 4.2, false, paint);
    final swell = Path()
      ..moveTo(8, 28)
      ..cubicTo(15, 28, 15, 23, 21, 23)
      ..cubicTo(27, 23, 27, 28, 34, 28);
    canvas.drawPath(swell, paint);
    paint.color = wave;
    final ripple = Path()
      ..moveTo(11, 33)
      ..quadraticBezierTo(15, 34, 19, 31)
      ..quadraticBezierTo(22, 29, 25, 31)
      ..quadraticBezierTo(29, 34, 33, 33);
    canvas.drawPath(ripple, paint);
    canvas.drawCircle(const Offset(26, 13), 2.4, Paint()..color = gold);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BeaconPainter oldDelegate) =>
      blue != oldDelegate.blue ||
      wave != oldDelegate.wave ||
      gold != oldDelegate.gold;
}
