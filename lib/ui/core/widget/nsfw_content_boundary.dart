import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:miru_alpha/model/extension_meta_data.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:miru_alpha/utils/store/nsfw_session.dart';

/// Restricted pages have no mounted player, reader, or detail widgets
/// while access is off. This leaves the app's route structure unchanged.
class NsfwContentBoundary extends StatelessWidget {
  const NsfwContentBoundary({
    super.key,
    required this.meta,
    required this.child,
  });

  final ExtensionMeta meta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (meta.nsfw) nsfwSession.markRestricted(meta.packageName);
    if (!nsfwSession.isRestricted(meta.packageName)) return child;
    return StreamBuilder<bool>(
      stream: nsfwSession.changes,
      builder: (context, _) {
        if (nsfwSession.enabled) {
          return NsfwMediaScope(key: ValueKey(nsfwSession.epoch), child: child);
        }
        return FScaffold(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('settings.labels.allow_nsfw.unavailable'.i18n),
                const SizedBox(height: 12),
                FButton(
                  onPress: () => Navigator.of(context).maybePop(),
                  child: Text('common.back'.i18n),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Images under this scope are session data, not normal disk cache entries.
class NsfwMediaScope extends InheritedWidget {
  const NsfwMediaScope({super.key, required super.child});

  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NsfwMediaScope>() != null;

  @override
  bool updateShouldNotify(NsfwMediaScope oldWidget) => false;
}
