import 'miru_colors.dart' show baseColorsData, primaryColorsData;

/// A v1 skin manifest contains only scalar design tokens, never assets, URLs,
/// paths or executable hooks. IDs (not palette pairs) identify skin packs.
final class SkinPack {
  const SkinPack._({
    required this.id,
    required this.baseColor,
    required this.primaryColor,
    required this.cardRadius,
    required this.avatarFrameColor,
    required this.headerStartColor,
    required this.headerEndColor,
  });

  final String id;
  final String baseColor;
  final String primaryColor;
  final double cardRadius;
  final int avatarFrameColor;
  final int headerStartColor;
  final int headerEndColor;

  static const _keys = {
    'schemaVersion',
    'id',
    'baseColor',
    'primaryColor',
    'cardRadius',
    'avatarFrameColor',
    'headerStartColor',
    'headerEndColor',
  };
  static final _idPattern = RegExp(r'[a-z][a-z0-9_-]{0,63}');
  static final _colorPattern = RegExp(r'#[0-9a-fA-F]{8}');

  static bool _matches(RegExp pattern, String value) =>
      pattern.matchAsPrefix(value)?.end == value.length;

  /// All keys are required. The only wire color form is "#AARRGGBB".
  /// Malformed or unknown fields throw [FormatException], never a fallback.
  factory SkinPack.fromJson(Map<String, dynamic> json) {
    if (json.length != _keys.length || !json.keys.every(_keys.contains)) {
      throw const FormatException('Invalid skin manifest fields');
    }
    final version = json['schemaVersion'];
    if (version is! int || version != 1) {
      throw const FormatException('Expected integer schemaVersion 1');
    }
    final id = json['id'];
    if (id is! String || !_matches(_idPattern, id)) {
      throw const FormatException('Invalid skin ID');
    }
    final base = json['baseColor'];
    // Amoei is the app-owned selectable base outside the generated Forui map.
    if (base is! String ||
        !(baseColorsData.containsKey(base) || base == 'amoei')) {
      throw const FormatException('Invalid baseColor');
    }
    final primary = json['primaryColor'];
    if (primary is! String ||
        !(primaryColorsData.containsKey(primary) || primary == 'none')) {
      throw const FormatException('Invalid primaryColor');
    }
    final radius = json['cardRadius'];
    if (radius is! num || !radius.isFinite || radius < 0 || radius > 24) {
      throw const FormatException('cardRadius must be a number from 0 to 24');
    }
    int color(String key) {
      final value = json[key];
      if (value is! String || !_matches(_colorPattern, value)) {
        throw FormatException('Expected #AARRGGBB for $key');
      }
      return int.parse(value.substring(1), radix: 16);
    }

    return SkinPack._(
      id: id,
      baseColor: base,
      primaryColor: primary,
      cardRadius: radius.toDouble(),
      avatarFrameColor: color('avatarFrameColor'),
      headerStartColor: color('headerStartColor'),
      headerEndColor: color('headerEndColor'),
    );
  }

  static String _hex(int argb) =>
      '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'baseColor': baseColor,
    'primaryColor': primaryColor,
    'cardRadius': cardRadius,
    'avatarFrameColor': _hex(avatarFrameColor),
    'headerStartColor': _hex(headerStartColor),
    'headerEndColor': _hex(headerEndColor),
  };
}

/// The first pack is the Meowoo default. Ocean shares its Forui palette
/// intentionally; frame, gradient, and card treatment distinguish them.
const builtInSkinPacks = <SkinPack>[
  SkinPack._(
    id: 'meowoo',
    baseColor: 'mist',
    primaryColor: 'cyan',
    cardRadius: 14,
    avatarFrameColor: 0xFF16887E,
    headerStartColor: 0xFFE1F5FF,
    headerEndColor: 0xFFF4FFF9,
  ),
  SkinPack._(
    id: 'ocean',
    baseColor: 'mist',
    primaryColor: 'cyan',
    cardRadius: 18,
    avatarFrameColor: 0xFF23729D,
    headerStartColor: 0xFFC3E4F6,
    headerEndColor: 0xFFDCF8F2,
  ),
  SkinPack._(
    id: 'sakura',
    baseColor: 'mauve',
    primaryColor: 'pink',
    cardRadius: 22,
    avatarFrameColor: 0xFFAE497A,
    headerStartColor: 0xFFFADCE9,
    headerEndColor: 0xFFFFF5EE,
  ),
];

SkinPack? skinPackById(String id) {
  for (final pack in builtInSkinPacks) {
    if (pack.id == id) return pack;
  }
  return null;
}
