import 'package:flutter/services.dart';

/// Ordinary screens paint through the system bars; fullscreen video can
/// still temporarily own the mode on platform versions that allow it.
class AppSystemUi {
  AppSystemUi._();

  static bool surfaceOwned = false;

  static void restore() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  static SystemUiOverlayStyle style(Brightness background) {
    final lightBackground = background == Brightness.light;
    final iconBrightness = lightBackground ? Brightness.dark : Brightness.light;
    return SystemUiOverlayStyle(
      statusBarColor: const Color(0x00000000),
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: background,
      systemNavigationBarColor: const Color(0x00000000),
      systemNavigationBarIconBrightness: iconBrightness,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }
}
