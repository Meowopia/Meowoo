import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miru_alpha/ui/core/widget/skin_pack_motion.dart';

void main() {
  Widget host(
    SkinMotionSurface surface, {
    bool reduced = false,
    VoidCallback? onTap,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
          SkinPackMotion(packId: 'amoei', surface: surface),
        ],
      ),
    ),
  );

  double scale(WidgetTester tester) => tester
      .widget<Transform>(
        find.descendant(
          of: find.byType(SkinPackMotion),
          matching: find.byType(Transform),
        ),
      )
      .transform
      .storage
      .first;

  testWidgets('profile loops without intercepting toolbar taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(SkinMotionSurface.profile, onTap: () => taps++),
    );
    final start = scale(tester);
    await tester.pump(const Duration(milliseconds: 4500));
    expect(scale(tester), greaterThan(start));
    await tester.tapAt(const Offset(300, 28));
    expect(taps, 1);
    await tester.pump(const Duration(milliseconds: 4500));
    expect(scale(tester), closeTo(start, 0.00001));
  });

  testWidgets('launch settles once and reduced motion stays still', (
    tester,
  ) async {
    await tester.pumpWidget(host(SkinMotionSurface.launch));
    expect(scale(tester), greaterThan(1));
    await tester.pump(const Duration(seconds: 1));
    expect(scale(tester), 1);
    await tester.pump(const Duration(milliseconds: 450));
    expect(scale(tester), 1);
    for (final surface in SkinMotionSurface.values) {
      await tester.pumpWidget(host(surface, reduced: true));
      final start = scale(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(scale(tester), start);
    }
  });
}
