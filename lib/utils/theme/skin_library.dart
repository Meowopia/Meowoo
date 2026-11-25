import 'package:miru_alpha/utils/theme/amoei_palette.dart';

/// Curated, built-in skins for the Miru appearance system.
///
/// A skin selects a base and accent through the normal application theme
/// pipeline, using either a Forui or a Meowoo base palette.
class MiruSkin {
  const MiruSkin({
    required this.id,
    required this.baseColor,
    required this.primaryColor,
  });

  final String id;
  final String baseColor;
  final String primaryColor;
}

const amoeiSkin = MiruSkin(
  id: 'amoei',
  baseColor: amoeiBaseColorName,
  primaryColor: 'none',
);

const List<MiruSkin> miruSkinLibrary = [
  amoeiSkin,
  MiruSkin(id: 'classic', baseColor: 'zinc', primaryColor: 'blue'),
  MiruSkin(id: 'midnight', baseColor: 'neutral', primaryColor: 'violet'),
  MiruSkin(id: 'ocean', baseColor: 'mist', primaryColor: 'cyan'),
  MiruSkin(id: 'forest', baseColor: 'olive', primaryColor: 'emerald'),
  MiruSkin(id: 'sakura', baseColor: 'mauve', primaryColor: 'pink'),
  MiruSkin(id: 'sunset', baseColor: 'stone', primaryColor: 'orange'),
  MiruSkin(id: 'lavender', baseColor: 'taupe', primaryColor: 'purple'),
  MiruSkin(id: 'citrus', baseColor: 'neutral', primaryColor: 'lime'),
];

MiruSkin? miruSkinById(String id) {
  for (final skin in miruSkinLibrary) {
    if (skin.id == id) return skin;
  }
  return null;
}

String? currentMiruSkinId(String baseColor, String primaryColor) {
  for (final skin in miruSkinLibrary) {
    if (skin.baseColor == baseColor && skin.primaryColor == primaryColor) {
      return skin.id;
    }
  }
  return null;
}
