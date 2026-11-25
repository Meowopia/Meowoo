import 'dart:convert';
import 'dart:io';

// This CLI must also work from a clean checkout before flutter pub get.
// ignore: avoid_relative_lib_imports
import '../../lib/utils/theme/skin_pack.dart';

/// Standalone Dart VM check; no Flutter engine, package:test or native build.
void main() {
  var checks = 0;
  void check(bool ok, String name) {
    if (!ok) throw StateError(name);
    checks++;
  }

  void rejects(Map<String, dynamic> json, String name) {
    try {
      SkinPack.fromJson(json);
    } on FormatException {
      checks++;
      return;
    }
    throw StateError('Accepted invalid manifest: $name');
  }

  check(
    builtInSkinPacks.map((p) => p.id).join(',') == 'meowoo,ocean,sakura',
    'catalog and default',
  );
  for (final p in builtInSkinPacks) {
    final wire = jsonEncode(p.toJson());
    final restored = SkinPack.fromJson(
      jsonDecode(wire) as Map<String, dynamic>,
    );
    check(
      jsonEncode(restored.toJson()) == wire,
      'canonical round trip: ${p.id}',
    );
    check(identical(skinPackById(restored.id), p), 'lookup: ${p.id}');
    final pink = p.id == 'sakura';
    check(
      p.baseColor == (pink ? 'mauve' : 'mist') &&
          p.primaryColor == (pink ? 'pink' : 'cyan'),
      'palette: ${p.id}',
    );
  }
  check(skinPackById('missing') == null, 'unknown ID');
  final seed = builtInSkinPacks.first.toJson();
  for (final key in seed.keys) {
    rejects({...seed}..remove(key), 'missing $key');
    rejects({...seed, key: null}, 'null $key');
    rejects({...seed, key: <String, dynamic>{}}, 'object $key');
  }
  rejects({...seed, 'script': 'ignored'}, 'extra field');
  rejects(
    {...seed}
      ..remove('id')
      ..['url'] = 'https://example.invalid',
    'replacement field',
  );
  for (final value in [0, 2, 1.0, '1']) {
    rejects({...seed, 'schemaVersion': value}, 'version $value');
  }
  for (final value in [-1, 24.001, double.infinity, double.nan, '5']) {
    rejects({...seed, 'cardRadius': value}, 'radius $value');
  }
  for (final value in [0, 3.5, 24]) {
    check(
      SkinPack.fromJson({...seed, 'cardRadius': value}).cardRadius == value,
      'accepted radius $value',
    );
  }
  for (final key in [
    'id',
    'baseColor',
    'primaryColor',
    'avatarFrameColor',
    'headerStartColor',
    'headerEndColor',
  ]) {
    for (final value in [
      '',
      'https://example.invalid/a',
      '../x',
      '<script/>',
      'javascript:alert(1)',
    ]) {
      rejects({...seed, key: value}, 'unsafe $key');
    }
  }
  for (final key in ['baseColor', 'primaryColor']) {
    rejects({...seed, key: 'not-a-palette'}, 'unrecognized palette $key');
  }
  for (final value in [
    '#FFF',
    '#112233',
    '0xFF112233',
    '#ff001122\n',
    '#GG000000',
    0xFF000000,
  ]) {
    rejects({...seed, 'avatarFrameColor': value}, 'malformed ARGB');
  }
  final translucent = SkinPack.fromJson({
    ...seed,
    'avatarFrameColor': '#0a01ab0f',
  });
  check(
    translucent.avatarFrameColor == 0x0A01AB0F &&
        translucent.toJson()['avatarFrameColor'] == '#0A01AB0F',
    'ARGB canonicalization',
  );
  stdout.writeln('PASS: $checks skin pack checks');
}
