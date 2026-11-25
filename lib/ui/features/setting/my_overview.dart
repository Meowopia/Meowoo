import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:miru_alpha/ui/core/index.dart' show SettingScaffold;
import 'package:miru_alpha/ui/core/widget/miru_card.dart';
import 'package:miru_alpha/ui/core/widget/skin_pack_scope.dart';
import 'package:miru_alpha/ui/features/jellyfin/jellyfin_page.dart';
import 'package:miru_alpha/ui/features/setting/setting_general.dart';
import 'package:miru_alpha/ui/features/setting/setting_log.dart';
import 'package:miru_alpha/ui/features/setting/widget/skin_pack_gallery.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:miru_alpha/utils/theme/skin_pack.dart';

/// Personal hub over existing features. No account numbers or cloud state are
/// invented, and no provider is queried merely to populate the shortcut cards.
class MyOverview extends StatelessWidget {
  const MyOverview({super.key});

  void _open(BuildContext context, String title, Widget child) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          // Navigator overlays are outside MyOverview's local Material scope.
          // Reapply current Forui tokens on the new route as skins change.
          builder: (_) => SkinMaterialSurface(
            child: Material(
              type: MaterialType.transparency,
              child: SettingScaffold(title: title.i18n, child: child),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pack = SkinPackScope.of(context) ?? builtInSkinPacks.first;
    return SkinMaterialSurface(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SkinPackHeader(pack: pack, subtitle: 'my_page.local_user'.i18n),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final entry in [
                    (
                      'history',
                      'my_page.history',
                      Icons.history,
                      '/home/history',
                    ),
                    (
                      'favorites',
                      'my_page.favorites',
                      Icons.bookmark_outline,
                      '/home/favorite',
                    ),
                    (
                      'downloads',
                      'my_page.downloads',
                      Icons.download_outlined,
                      '/home/download',
                    ),
                  ])
                    Expanded(
                      child: TextButton(
                        key: ValueKey('my-${entry.$1}'),
                        onPressed: () => context.push(entry.$4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(entry.$3),
                            const SizedBox(height: 6),
                            Text(entry.$2.i18n, textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              MiruCard(
                title: Text('my_page.personalization'.i18n),
                body: Column(
                  children: [
                    ListTile(
                      key: const ValueKey('my-skins'),
                      leading: const Icon(Icons.palette_outlined),
                      title: Text('skin_packs.title'.i18n),
                      subtitle: Text('my_page.skins_help'.i18n),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        context,
                        'skin_packs.title',
                        const SingleChildScrollView(child: SkinPackGallery()),
                      ),
                    ),
                    ListTile(
                      key: const ValueKey('my-settings'),
                      leading: const Icon(Icons.settings_outlined),
                      title: Text('common.settings'.i18n),
                      subtitle: Text('my_page.settings_help'.i18n),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        context,
                        'common.settings',
                        const SettingGeneral(isMobileLayout: true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MiruCard(
                title: Text('my_page.media'.i18n),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const JellyfinEntry(),
                    ListTile(
                      key: const ValueKey('my-sources'),
                      leading: const Icon(Icons.extension_outlined),
                      title: Text('extension.name'.i18n),
                      subtitle: Text('my_page.sources_help'.i18n),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/extension'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MiruCard(
                title: Text('my_page.data_privacy'.i18n),
                body: Column(
                  children: [
                    ListTile(
                      key: const ValueKey('my-cloud-unavailable'),
                      leading: const Icon(Icons.cloud_outlined),
                      title: Text('my_page.cloud'.i18n),
                      subtitle: Text('my_page.cloud_pending'.i18n),
                      enabled: false,
                    ),
                    ListTile(
                      key: const ValueKey('my-privacy'),
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text('my_page.content_settings'.i18n),
                      subtitle: Text('my_page.content_help'.i18n),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        context,
                        'common.settings',
                        const SettingGeneral(isMobileLayout: true),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              MiruCard(
                title: Text('my_page.help'.i18n),
                body: Column(
                  children: [
                    ListTile(
                      key: const ValueKey('my-diagnostics'),
                      leading: const Icon(Icons.description_outlined),
                      title: Text('settings.logging.name'.i18n),
                      subtitle: Text('my_page.diagnostics_help'.i18n),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(
                        context,
                        'settings.logging.name',
                        const SettingLog(isMobileLayout: true),
                      ),
                    ),
                    ListTile(
                      key: const ValueKey('my-licenses'),
                      leading: const Icon(Icons.info_outline),
                      title: Text('common.licenses'.i18n),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/license'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
