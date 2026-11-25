import 'package:material_ui/material_ui.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:miru_alpha/ui/features/setting/setting_network.dart';
import 'package:miru_alpha/ui/features/setting/setting_general.dart';
import 'package:miru_alpha/ui/features/setting/widget/settings_update_alert.dart';
import 'package:miru_alpha/ui/features/main_page/desktop_sidebar.dart'
    show SafeFSidebar;
import 'package:miru_alpha/ui/features/setting/my_overview.dart';

import 'setting_extension.dart';
import 'setting_log.dart';

import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:miru_alpha/ui/core/index.dart';
import 'package:miru_alpha/provider/dev_tool_provider.dart';
import 'package:miru_alpha/model/setting_items.dart';

class SettingsPage extends HookWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final select = useState(SideBarName.general);
    return MiruScaffold.mobile(
      sliverHeaders: [
        SimpleSliverHeaderDelegate(
          maxExtent: 56,
          child: SnapSheetHeader(title: 'common.settings'.i18n),
        ),
      ],
      body: SettingPage(selected: select.value),
    );
  }
}

/// The desktop settings sections that render real content — shared by the
/// settings dialog nav and the deep-link page sidebar. Sections still rendering
/// empty stubs (player, reader, about, tracking, download) stay out until they
/// have something to show.
const settingsSections = <(SideBarName, String, IconData)>[
  (SideBarName.general, 'common.general', FLucideIcons.menu),
  (SideBarName.extension, 'settings.extension.name', FLucideIcons.blocks),
  (SideBarName.network, 'settings.miru_core.name', FLucideIcons.serverCog),
  (SideBarName.advanced, 'settings.logging.name', FLucideIcons.scrollText),
  (SideBarName.developer, 'common.developer', FLucideIcons.code),
];

/// One settings section's content pane (desktop dialog + deep-link page).
class SettingsSectionBody extends ConsumerWidget {
  const SettingsSectionBody({super.key, required this.name});

  final SideBarName name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (name) {
      case SideBarName.general:
        return SettingScaffold(
          title: 'common.general'.i18n,
          child: SettingGeneral(),
        );
      case SideBarName.extension:
        return SettingScaffold(
          title: 'settings.extension.name'.i18n,
          child: SettingExtension(),
        );
      case SideBarName.player:
        // return SettingPlayer();
        return const Center();
      case SideBarName.network:
        return SettingNetwork();
      case SideBarName.reader:
        // return SettingReader();
        return const Center();
      case SideBarName.advanced:
        return SettingScaffold(
          title: 'settings.logging.name'.i18n,
          child: SettingLog(),
        );
      case SideBarName.about:
        return const Center();
      case SideBarName.tracking:
        return const Center();
      case SideBarName.download:
        // return SettingDownload();
        return const Center();
      case SideBarName.developer:
        return SettingScaffold(
          title: 'common.developer'.i18n,
          child: Column(
            children: [
              OutterCard(
                title: 'common.developer'.i18n,
                child: SettingPressTile(
                  isMobileLayout: false,
                  title: 'common.developer'.i18n,
                  subtitle: 'Open DevTools for JS extensions',
                  prefix: Icon(FLucideIcons.terminal),
                  onPress: () => ref.read(devToolProvider.notifier).toggle(),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class SettingPage extends ConsumerStatefulWidget {
  const SettingPage({super.key, required this.selected});
  final SideBarName selected;
  @override
  createState() => _SettingItemsState();
}

class _SettingItemsState extends ConsumerState<SettingPage> {
  @override
  Widget build(BuildContext context) => MiruScaffold.mobile(
    sliverHeaders: [
      SimpleSliverHeaderDelegate(
        maxExtent: 56,
        child: SnapSheetHeader(title: 'common.me'.i18n),
      ),
    ],
    desktopBody: _DesktopSettingsBody(selected: widget.selected),
    slivers: const [
      SliverToBoxAdapter(child: SettingsUpdateAlert()),
      SliverToBoxAdapter(child: MyOverview()),
    ],
  );
}

/// Desktop settings shell for the deep-link routes: the header gear opens the
/// settings DIALOG (primary UX); this page remains the `/settings/<name>`
/// fallback with its own section sidebar + content pane.
class _DesktopSettingsBody extends StatelessWidget {
  const _DesktopSettingsBody({required this.selected});

  final SideBarName selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Row(
      crossAxisAlignment: .stretch,
      children: [
        SafeFSidebar(
          width: 200,
          header: Padding(
            padding: .symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'common.settings'.i18n,
                  style: context.theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                FDivider(
                  style: FDividerStyleDelta.delta(
                    padding: EdgeInsetsGeometryDelta.value(.only(bottom: 5)),
                  ),
                ),
              ],
            ),
          ),
          children: [
            FSidebarGroup(
              label: const SizedBox.shrink(),
              children: [
                for (final (name, labelKey, icon) in settingsSections)
                  FSidebarItem(
                    selected: selected == name,
                    icon: Icon(icon),
                    label: Text(labelKey.i18n),
                    onPress: () => context.go('/settings/${name.name}'),
                  ),
              ],
            ),
          ],
        ),
        Container(width: 1, color: colors.border),
        Expanded(child: SettingsSectionBody(name: selected)),
      ],
    );
  }
}
