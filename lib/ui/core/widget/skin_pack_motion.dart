import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:miru_alpha/utils/theme/skin_pack.dart';

enum SkinMotionSurface { profile, launch }

/// Decorative local layer for a bounded Stack. Identity, toolbar actions,
/// dismissal, and the navigation lifetime all belong to the caller.
class SkinPackMotion extends StatefulWidget {
  const SkinPackMotion({
    super.key,
    required this.packId,
    required this.surface,
  });
  final String packId;
  final SkinMotionSurface surface;

  @override
  State<SkinPackMotion> createState() => _SkinPackMotionState();
}

class _SkinPackMotionState extends State<SkinPackMotion>
    with SingleTickerProviderStateMixin {
  late final _phase = AnimationController(vsync: this);
  bool? _playing;

  void _sync() {
    final launch = widget.surface == SkinMotionSurface.launch;
    final play =
        TickerMode.valuesOf(context).enabled &&
        !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);
    if (_playing == play) return;
    _playing = play;
    _phase.stop();
    _phase.duration = launch
        ? const Duration(milliseconds: 900)
        : const Duration(seconds: 9);
    if (!play) {
      _phase.value = launch ? 1 : 0;
    } else if (launch) {
      _phase.forward(from: 0);
    } else {
      _phase.repeat();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SkinPackMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.surface != oldWidget.surface ||
        widget.packId != oldWidget.packId) {
      _playing = null;
      _sync();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAmoei = widget.packId == 'amoei';
    final pack = skinPackById(widget.packId) ?? builtInSkinPacks.first;
    final launch = widget.surface == SkinMotionSurface.launch;
    final start = isAmoei
        ? const Color(0xfffaf7f7)
        : Color(pack.headerStartColor);
    final end = isAmoei ? const Color(0xffe6e8f8) : Color(pack.headerEndColor);
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [start, end]),
                  ),
                ),
                if (isAmoei)
                  AnimatedBuilder(
                    animation: _phase,
                    child: Image.asset(
                      'assets/skins/amoei/atelier.png',
                      fit: launch ? BoxFit.contain : BoxFit.cover,
                      alignment: launch
                          ? Alignment.center
                          : const Alignment(0.44, 0.15),
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                    builder: (_, child) {
                      final t = _phase.value;
                      final zoom = launch
                          ? 0.045 * (1 - Curves.easeOutCubic.transform(t))
                          : 0.008 * (1 - math.cos(t * 2 * math.pi));
                      return Transform.scale(
                        scale: 1 + zoom,
                        alignment: const Alignment(0.44, 0.12),
                        child: child,
                      );
                    },
                  ),
                CustomPaint(painter: _Glints(_phase, launch)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Keep glints below the right-hand toolbar and away from the avatar/text.
class _Glints extends CustomPainter {
  _Glints(this.phase, this.launch) : super(repaint: phase);
  final Animation<double> phase;
  final bool launch;

  @override
  void paint(Canvas canvas, Size size) {
    const points = [
      Offset(.60, .64),
      Offset(.82, .54),
      Offset(.90, .81),
      Offset(.67, .86),
    ];
    for (var i = 0; i < points.length; i++) {
      final angle = 2 * math.pi * (phase.value + i / points.length);
      final strength = launch
          ? math.sin(phase.value * math.pi)
          : (math.sin(angle) + 1) * .5;
      final p = Offset(
        points[i].dx * size.width,
        points[i].dy * size.height - strength * 4,
      );
      final r = 1.5 + 2.5 * strength;
      final path = Path()
        ..moveTo(p.dx, p.dy - r)
        ..lineTo(p.dx + r * .38, p.dy - r * .23)
        ..lineTo(p.dx + r, p.dy)
        ..lineTo(p.dx + r * .28, p.dy + r * .28)
        ..lineTo(p.dx, p.dy + r)
        ..lineTo(p.dx - r * .25, p.dy + r * .24)
        ..lineTo(p.dx - r, p.dy)
        ..lineTo(p.dx - r * .24, p.dy - r * .26)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xffffffff)
              .withValues(alpha: .2 + strength * .6),
      );
    }
  }

  @override
  bool shouldRepaint(_Glints oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.launch != launch;
}
