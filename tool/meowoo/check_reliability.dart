import 'dart:async';

import 'package:miru_alpha/utils/store/history_list_rules.dart';
import 'package:miru_alpha/utils/store/ordered_settings_writes.dart';

int checks = 0;
void check(bool value, String name) {
  checks++;
  if (!value) throw StateError(name);
}

typedef Row = ({int id, int progress, HistoryFields fields});
Future<void> tick() => Future<void>.delayed(Duration.zero);

Future<void> main() async {
  historyChecks();
  await writeChecks();
  // ignore: avoid_print
  print(
    'PASS: $checks reliability checks (production history rules and ordered settings writer)',
  );
}

void historyChecks() {
  requireGlobalHistoryClear('all');
  check(true, 'explicit clear-all is allowed');
  for (final type in ['bangumi', 'manga', 'fikushon', '', 'unknown']) {
    var blocked = false;
    try {
      requireGlobalHistoryClear(type);
    } on UnsupportedError {
      blocked = true;
    }
    check(
      blocked,
      'non-global clear is blocked before a destructive RPC: $type',
    );
  }
  final now = DateTime.utc(2026, 11, 25, 12);
  Row row(
    String package,
    String url,
    String detail,
    String type,
    String title,
    int age, {
    int progress = 10,
  }) => (
    id: 0,
    progress: progress,
    fields: (
      package: package,
      url: url,
      detailUrl: detail,
      type: type,
      title: title,
      date: now.subtract(Duration(days: age)),
    ),
  );
  final video = row('v', 'ep1', 'work1', 'bangumi', 'Meowoo Video', 1);
  final older = row('v', 'ep2', 'work1', 'bangumi', 'Meowoo Old', 20);
  final novel = row('n', 'ep1', 'work2', 'fikushon', 'Meowoo Novel', 1);
  final manga = row('m', 'chapter', 'work3', 'manga', 'Another 漫画', 2);
  final rows = [video, older, novel, manga];
  final rules = HistoryListRules<Row>((r) => r.fields);
  List<Row> filter({
    Set<String> types = const {},
    String query = '',
    Duration duration = const Duration(days: 36500),
  }) => rules.filter(
    rows,
    types: types,
    keyword: query,
    duration: duration,
    now: now,
  );
  check(filter().length == 4, 'empty types represent all, not an empty result');
  check(filter(types: {'all'}).length == 4, 'explicit all represents all');
  check(
    filter(types: {'all', 'manga'}).length == 4,
    'all plus a type is unrestricted',
  );
  check(filter(types: {'bangumi'}).length == 2, 'video filter');
  check(filter(types: {'manga', 'fikushon'}).length == 2, 'multiple types');
  check(
    filter(query: '  MEOWOO  ').length == 3,
    'trim and case-insensitive query',
  );
  check(filter(query: '漫画').single == manga, 'non-Latin query');
  check(
    filter(
          types: {'bangumi'},
          query: 'meowoo',
          duration: const Duration(days: 7),
        ).single ==
        video,
    'combined type/query/date',
  );
  check(
    filter(
          types: {},
          query: 'meowoo',
          duration: const Duration(days: 7),
        ).length ==
        2,
    'clearing type retains query/date',
  );
  check(
    filter(
          types: {'bangumi'},
          query: '',
          duration: const Duration(days: 7),
        ).single ==
        video,
    'clearing query retains type/date',
  );
  check(
    filter(types: {'bangumi'}, query: 'meowoo').length == 2,
    'clearing date retains type/query',
  );
  check(
    filter(duration: const Duration(days: 1)).length == 2,
    'inclusive date cutoff',
  );
  check(filter(query: 'absent').isEmpty, 'no query match');
  final sameUrlOtherWork = row(
    'v',
    'ep1',
    'other-work',
    'bangumi',
    'Other Work',
    1,
  );
  check(
    rules.merge([video], [sameUrlOtherWork]).length == 2,
    'different detail URL is a distinct Core upsert key',
  );
  check(
    rules.merge([video], [video]).length == 1,
    'deduplicate identical Core key',
  );
  check(
    rules.merge([video], [novel]).length == 2,
    'same episode URL in another package is distinct',
  );
  final remaining = rules.remove(rows, ('v', 'ep1'));
  check(
    remaining.length == 3 && remaining.contains(novel),
    'deleting one ID-zero row must not remove all ID-zero rows',
  );
  check(
    rules.remove([video, sameUrlOtherWork, novel], ('v', 'ep1')).single ==
        novel,
    'UI deletion matches existing Core package/URL scope',
  );
  final loaded = rules.merge([novel], [video, older], deleted: {('v', 'ep1')});
  check(
    !loaded.contains(video) && loaded.contains(older),
    'late initial load cannot resurrect a deleted row',
  );
  final current = row(
    'v',
    'ep1',
    'work1',
    'bangumi',
    'Current',
    0,
    progress: 42,
  );
  check(
    rules.merge([current], [video]).single == current,
    'local checkpoint wins over stale initial snapshot',
  );
  check(
    rules.upsert([current], video).single.progress == 42,
    'late older save acknowledgement cannot regress progress',
  );
  check(
    rules.upsert([video], current).single.progress == 42,
    'new checkpoint replaces older progress',
  );
  final sorted = rules.merge([older], [video, novel]);
  check(sorted.last == older, 'history ordered newest first');
  check(
    rows.length == 4 && rows.first == video,
    'operations do not mutate input lists',
  );
}

Future<void> writeChecks() async {
  final writer = OrderedSettingsWrites();
  final first = Completer<void>();
  final second = Completer<void>();
  final sent = <String>[];
  final committed = <String>[];
  Future<void> send(String key, String value) {
    sent.add(value);
    return value == 'old' ? first.future : second.future;
  }

  void commit(String key, String value) => committed.add(value);
  final old = writer.write(
    key: 'theme',
    value: 'old',
    send: send,
    onCommitted: commit,
  );
  final latest = writer.write(
    key: 'theme',
    value: 'new',
    send: send,
    onCommitted: commit,
  );
  await tick();
  check(sent.length == 1 && sent.single == 'old', 'same-key writes serialize');
  first.complete();
  await old;
  await tick();
  check(
    committed.isEmpty,
    'old response must not overwrite latest local choice',
  );
  check(sent.join(',') == 'old,new', 'backend receives input order');
  second.complete();
  await latest;
  check(committed.single == 'new', 'only latest response publishes');

  final gate = Completer<void>();
  var otherKeyFinished = false;
  final blocked = writer.write(
    key: 'theme',
    value: 'blocked',
    send: (_, _) => gate.future,
    onCommitted: (_, _) {},
  );
  await writer.write(
    key: 'language',
    value: 'zh',
    send: (_, _) async {},
    onCommitted: (_, _) => otherKeyFinished = true,
  );
  check(
    otherKeyFinished && !gate.isCompleted,
    'unrelated settings do not block each other',
  );
  gate.complete();
  await blocked;

  var recovered = false;
  final failed = writer.write(
    key: 'theme',
    value: 'bad',
    send: (_, _) async {
      throw StateError('expected failure');
    },
    onCommitted: (_, _) {
      throw StateError('failed write committed');
    },
  );
  final observedError = failed.then(
    (_) => false,
    onError: (Object _, StackTrace _) => true,
  );
  final afterFailure = writer.write(
    key: 'theme',
    value: 'good',
    send: (_, _) async {},
    onCommitted: (_, _) => recovered = true,
  );
  check(await observedError, 'caller observes RPC failure');
  await afterFailure;
  check(recovered, 'failed request does not poison per-key queue');

  final g1 = Completer<void>();
  final g2 = Completer<void>();
  final values = <String>[];
  final a = writer.write(
    key: 'speed',
    value: '1',
    send: (_, _) => g1.future,
    onCommitted: (_, v) => values.add(v),
  );
  final b = writer.write(
    key: 'speed',
    value: '2',
    send: (_, _) => g2.future,
    onCommitted: (_, v) => values.add(v),
  );
  final c = writer.write(
    key: 'speed',
    value: '3',
    send: (_, _) async {},
    onCommitted: (_, v) => values.add(v),
  );
  g1.complete();
  await a;
  g2.complete();
  await b;
  await c;
  check(
    values.length == 1 && values.single == '3',
    'rapid three-step choices publish only the final value',
  );
}
