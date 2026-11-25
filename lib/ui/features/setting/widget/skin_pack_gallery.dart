import 'package:material_ui/material_ui.dart';
import 'package:forui/forui.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:miru_alpha/provider/application_controller_provider.dart';
import 'package:miru_alpha/ui/core/widget/skin_pack_scope.dart';
import 'package:miru_alpha/ui/core/widget/miru_card.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:miru_alpha/utils/theme/skin_pack.dart';

class SkinPackGallery extends ConsumerStatefulWidget {
  const SkinPackGallery({super.key});

  @override
  ConsumerState<SkinPackGallery> createState() => _SkinPackGalleryState();
}

class _SkinPackGalleryState extends ConsumerState<SkinPackGallery> {
  bool _saveFailed = false;

  @override
  Widget build(BuildContext context) {
    final pack = ref.watch(applicationControllerProvider).skinPack;
    return SkinMaterialSurface(
      child: Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pack != null) ...[
                SkinPackHeader(
                  pack: pack,
                  subtitle: 'skin_packs.name_${pack.id}'.i18n,
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'skin_packs.title'.i18n,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('skin_packs.description'.i18n),
              if (_saveFailed) const _PackSaveError(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final skin in builtInSkinPacks)
                    OutlinedButton(
                      key: ValueKey('preview-pack-${skin.id}'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => _PackPreview(initial: skin),
                      ),
                      child: Text('skin_packs.name_${skin.id}'.i18n),
                    ),
                  TextButton(
                    key: const ValueKey('restore-default-pack'),
                    onPressed: () {
                      final ok = ref
                          .read(applicationControllerProvider.notifier)
                          .applySkinPack('meowoo');
                      setState(() => _saveFailed = !ok);
                    },
                    child: Text('skin_packs.restore'.i18n),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Forui pages need not contain a Material Scaffold. Keep failures inline so
// showing an error cannot itself throw a missing-Scaffold assertion.
class _PackSaveError extends StatelessWidget {
  const _PackSaveError();

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'skin_packs.save_failed'.i18n,
        key: const ValueKey('skin-pack-save-error'),
        style: TextStyle(color: FTheme.of(context).colors.error),
      ),
    ),
  );
}

class _PackPreview extends ConsumerStatefulWidget {
  const _PackPreview({required this.initial});
  final SkinPack initial;

  @override
  ConsumerState<_PackPreview> createState() => _PackPreviewState();
}

class _PackPreviewState extends ConsumerState<_PackPreview> {
  bool _dark = false;
  bool _saveFailed = false;

  @override
  Widget build(BuildContext context) {
    final pack = widget.initial;
    final controller = ref.read(applicationControllerProvider.notifier);
    final tint = ref.watch(applicationControllerProvider).tintStrength;
    final previewTheme = controller.currentThemeData(
      _dark ? 'dark' : 'light',
      pack.baseColor,
      pack.primaryColor,
      tintStrength: tint,
    );
    return Dialog(
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'skin_packs.name_${pack.id}'.i18n,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text('skin_packs.preview_notice'.i18n),
                if (_saveFailed) const _PackSaveError(),
                SwitchListTile(
                  title: Text('skin_packs.dark_preview'.i18n),
                  value: _dark,
                  onChanged: (value) => setState(() => _dark = value),
                ),
                SkinPackScope(
                  pack: pack,
                  child: FTheme(
                    data: previewTheme,
                    child: SkinMaterialSurface(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: previewTheme.colors.background,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SkinPackHeader(
                                pack: pack,
                                subtitle: 'skin_packs.sample_profile'.i18n,
                              ),
                              const SizedBox(height: 12),
                              MiruCard(
                                title: Text('skin_packs.sample_card'.i18n),
                                body: Text('skin_packs.sample_body'.i18n),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('skin_packs.cancel'.i18n),
                    ),
                    FilledButton(
                      key: const ValueKey('apply-preview-pack'),
                      onPressed: () {
                        if (controller.applySkinPack(pack.id)) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() => _saveFailed = true);
                        }
                      },
                      child: Text('skin_packs.apply'.i18n),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
