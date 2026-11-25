import 'dart:convert';

/// Data-only inspection. Parsing a rule must not fetch its website, evaluate
/// scripts, install Core code, or change the user's enabled source list.
class KazumiRuleReview {
  const KazumiRuleReview({
    required this.index,
    required this.name,
    required this.origin,
    required this.issues,
    required this.requirements,
  });

  final int index;
  final String name;
  final String? origin;
  final List<String> issues;
  final Set<String> requirements;
  bool get valid => issues.isEmpty;

  // Schema recognition is NOT a claim that a Core adapter exists.
  bool get executable => false;
}

const _selectors = [
  'searchList',
  'searchName',
  'searchResult',
  'chapterRoads',
  'chapterResult',
];

List<KazumiRuleReview> inspectKazumiRules(String input) {
  const maximumBytes = 256 * 1024;
  if (input.length > maximumBytes || utf8.encode(input).length > maximumBytes) {
    throw const FormatException('too_large');
  }
  var value = input.trim();
  if (value.isEmpty) throw const FormatException('empty');
  final shareScheme = RegExp(
    r'^kazumi:(?://)?',
    caseSensitive: false,
  ).firstMatch(value);
  if (shareScheme != null) {
    try {
      final payload = Uri.decodeComponent(value.substring(shareScheme.end))
          .replaceAll(RegExp(r'\s'), '');
      value = utf8.decode(base64.decode(base64.normalize(payload)));
    } on FormatException {
      throw const FormatException('invalid_share');
    }
  }
  Object? decoded;
  try {
    decoded = jsonDecode(value);
  } on FormatException {
    throw const FormatException('invalid_json');
  }
  final rows = decoded is List ? decoded : [decoded];
  if (rows.isEmpty || rows.length > 100) {
    throw const FormatException('too_many');
  }
  final names = <String>{};
  return List.unmodifiable([
    for (var i = 0; i < rows.length; i++) _inspect(rows[i], i + 1, names),
  ]);
}

KazumiRuleReview _inspect(Object? row, int index, Set<String> names) {
  final issues = <String>[];
  final requirements = <String>{};
  if (row is! Map<String, dynamic>) {
    return KazumiRuleReview(
      index: index,
      name: '',
      origin: null,
      issues: const ['invalid_entry'],
      requirements: const {},
    );
  }
  String field(String key, {int limit = 2048, bool required = false}) {
    final value = row[key];
    if (value == null && !required) return '';
    if (value is! String ||
        value.trim().isEmpty ||
        value.length > limit ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
      issues.add('invalid_$key');
      return '';
    }
    return value.trim();
  }

  final name = field('name', required: true, limit: 100);
  if (name.isNotEmpty && !names.add(name.toLowerCase())) {
    issues.add('duplicate_name');
  }
  final rawBase = field('baseURL', required: true);
  final base = _https(rawBase);
  if (base == null || base.hasQuery) issues.add('invalid_baseURL');
  final search = field('searchURL', required: true);
  final searchUri = _https(search.replaceAll('@keyword', 'meowoo'));
  if (searchUri == null) issues.add('invalid_searchURL');
  if (base != null && searchUri != null && base.origin != searchUri.origin) {
    requirements.add('cross_origin');
  }
  for (final prefix in ['search', 'chapter']) {
    final mode = row['${prefix}Mode'] ?? 'xpath';
    if (mode == 'xpath') {
      requirements.add('xpath');
      final fields = prefix == 'search'
          ? _selectors.take(3)
          : _selectors.skip(3);
      for (final key in fields) {
        final selector = field(key, required: true, limit: 1024);
        if (!selector.startsWith('//') && !selector.startsWith('.//')) {
          issues.add('invalid_$key');
        }
      }
    } else if (mode == 'api') {
      requirements.add('api');
      if (row['${prefix}ApiConfig'] is! Map<String, dynamic>) {
        issues.add('invalid_${prefix}ApiConfig');
      }
    } else {
      issues.add('invalid_${prefix}Mode');
    }
  }
  for (final key in [
    'usePost',
    'useWebview',
    'useNativePlayer',
    'useLegacyParser',
    'adBlocker',
    'muliSources',
  ]) {
    if (row[key] != null && row[key] is! bool) issues.add('invalid_$key');
  }
  if (row['usePost'] == true) requirements.add('post');
  if (row['useWebview'] != false) requirements.add('webview');
  if (row['useNativePlayer'] != false) requirements.add('media_resolution');
  if (row['useLegacyParser'] == true) requirements.add('legacy_parser');
  if (row['adBlocker'] == true) requirements.add('ad_blocker');
  final antiCrawler = row['antiCrawlerConfig'];
  if (antiCrawler != null && antiCrawler is! Map<String, dynamic>) {
    issues.add('invalid_antiCrawlerConfig');
  } else if (antiCrawler is Map && antiCrawler['enabled'] == true) {
    requirements.add('interactive_verification');
  }
  return KazumiRuleReview(
    index: index,
    name: name,
    origin: base?.origin,
    issues: List.unmodifiable(issues.toSet()),
    requirements: Set.unmodifiable(requirements),
  );
}

Uri? _https(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      RegExp(r'\s').hasMatch(value)) {
    return null;
  }
  return uri;
}
