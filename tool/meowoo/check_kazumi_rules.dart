import 'dart:convert';
import 'dart:io';

import 'package:miru_alpha/data/sources/kazumi_rule_import.dart';

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

final sample = <String, Object>{
  'name': 'Local fixture',
  'baseURL': 'https://example.invalid',
  'searchURL': 'https://example.invalid/search?q=@keyword',
  'searchList': '//article',
  'searchName': '//a',
  'searchResult': '//a',
  'chapterRoads': '//ul',
  'chapterResult': '//a',
  'useWebview': false,
};

void expectFailure(String value, String code) {
  try {
    inspectKazumiRules(value);
    throw StateError('Expected $code');
  } on FormatException catch (error) {
    require(error.message == code, 'Unexpected error: ${error.message}');
  }
}

void main() {
  var checks = 0;
  final first = inspectKazumiRules(jsonEncode(sample)).single;
  require(
    first.valid && !first.executable && first.requirements.contains('xpath'),
    'Valid fixture',
  );
  checks++;
  require(first.origin == 'https://example.invalid', 'Origin');
  checks++;
  final shared =
      'kazumi://${base64Url.encode(utf8.encode(jsonEncode(sample)))}';
  require(inspectKazumiRules(shared).single.valid, 'Share link');
  checks++;
  final standard = base64.encode(utf8.encode(jsonEncode(sample)));
  for (final link in [
    'KAZUMI:$standard',
    'kazumi://${Uri.encodeComponent(standard)}',
    'kazumi://${standard.substring(0, 20)}\n${standard.substring(20)}',
  ]) {
    require(inspectKazumiRules(link).single.valid, 'Wrapped share link');
    checks++;
  }
  final duplicates = inspectKazumiRules(
    jsonEncode([
      sample,
      {...sample, 'name': ' local FIXTURE '},
    ]),
  );
  require(duplicates[1].issues.contains('duplicate_name'), 'Duplicates');
  checks++;
  final mixed = inspectKazumiRules(jsonEncode([null, sample, 123]));
  require(
    !mixed.first.valid && mixed[1].valid && !mixed.last.valid,
    'Partial batch',
  );
  checks++;
  for (final base in [
    'http://example.invalid',
    'file:///tmp/test',
    'https://user:secret@example.invalid',
    'https://example.invalid/#secret',
    'https://example.invalid/?token=secret',
  ]) {
    require(
      !inspectKazumiRules(jsonEncode({...sample, 'baseURL': base}))
          .single
          .valid,
      'Invalid base accepted',
    );
    checks++;
  }
  final capabilities = inspectKazumiRules(
    jsonEncode({
      ...sample,
      'usePost': true,
      'useWebview': true,
      'useLegacyParser': true,
      'antiCrawlerConfig': {'enabled': true},
      'searchURL': 'https://other.example.invalid/?q=@keyword',
    }),
  ).single;
  require(
    capabilities.requirements.containsAll([
      'post',
      'webview',
      'legacy_parser',
      'interactive_verification',
      'cross_origin',
    ]),
    'Capability detection',
  );
  checks++;
  require(!capabilities.executable, 'Unimplemented runtime exposed');
  checks++;
  final api = inspectKazumiRules(
    jsonEncode({
      ...sample,
      'searchMode': 'api',
      'chapterMode': 'api',
      'searchApiConfig': <String, Object>{},
      'chapterApiConfig': <String, Object>{},
    }),
  ).single;
  require(
    api.valid && api.requirements.contains('api') && !api.executable,
    'API inspection',
  );
  checks++;
  require(
    !inspectKazumiRules(jsonEncode({...sample, 'usePost': 'true'}))
        .single
        .valid,
    'String accepted as boolean',
  );
  checks++;
  require(
    !inspectKazumiRules(jsonEncode({...sample, 'searchList': 'eval(code)'}))
        .single
        .valid,
    'Malformed selector',
  );
  checks++;
  expectFailure('', 'empty');
  checks++;
  expectFailure('not json', 'invalid_json');
  checks++;
  expectFailure('kazumi://not-base64!', 'invalid_share');
  checks++;
  expectFailure(jsonEncode([]), 'too_many');
  checks++;
  expectFailure(jsonEncode(List.filled(101, sample)), 'too_many');
  checks++;
  expectFailure('x' * (256 * 1024 + 1), 'too_large');
  checks++;
  expectFailure('猫' * (100 * 1024), 'too_large');
  checks++;
  stdout.writeln('Passed $checks offline Kazumi import inspection checks.');
}
