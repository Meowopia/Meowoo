import 'dart:async';

import 'dart:io';

import 'package:miru_alpha/utils/watch/scoped_chapter_cache.dart';

int checks = 0;
void check(bool value, String name) {
  if (!value) throw StateError(name);
  checks++;
}

ChapterCacheKey key({
  String package = 'public.a',
  String detail = 'work',
  String watch = 'chapter-1',
  String? mirror,
}) => (package: package, detailUrl: detail, watchUrl: watch, mirrorUrl: mirror);

Future<void> main() async {
  final cache = ScopedChapterCache<String>(maxEntries: 2);
  var loads = 0;
  Future<String> load(String value) async {
    loads++;
    return value;
  }

  check(await cache.resolve(key(), () => load('A')) == 'A', 'first load');
  check(await cache.resolve(key(), () => load('wrong')) == 'A', 'cache hit');
  check(loads == 1, 'hit does not fetch');
  check(
    await cache.resolve(key(package: 'public.b'), () => load('B')) == 'B',
    'source isolation',
  );
  check(
    await cache.resolve(key(detail: 'other'), () => load('C')) == 'C',
    'work isolation',
  );
  check(cache.peek(key()) == null, 'LRU eviction');
  check(cache.peek(key(package: 'public.b')) == 'B', 'peek touches LRU');
  await cache.resolve(key(mirror: 'alt'), () => load('D'));
  check(cache.peek(key(detail: 'other')) == null, 'least recent evicted');
  check(cache.peek(key(mirror: 'alt')) == 'D', 'mirror isolation');
  cache.clear();
  check(cache.peek(key(mirror: 'alt')) == null, 'clear removes cached');

  final gate = Completer<String>();
  var calls = 0;
  Future<String> delayed() {
    calls++;
    return gate.future;
  }

  final first = cache.resolve(key(), delayed);
  final second = cache.resolve(key(), delayed);
  check(calls == 1 && identical(first, second), 'single flight');
  gate.complete('shared');
  check(
    await first == 'shared' && await second == 'shared',
    'both callers receive result',
  );
  cache.clear();
  final late = Completer<String>();
  final stale = cache.resolve(key(), () => late.future);
  cache.clear();
  final freshGate = Completer<String>();
  final fresh = cache.resolve(key(), () => freshGate.future);
  late.complete('old');
  check(await stale == 'old', 'clear does not cancel original caller');
  check(cache.peek(key()) == null, 'old result cannot refill');
  check(
    identical(cache.resolve(key(), () => load('wrong')), fresh),
    'old cleanup preserves new pending',
  );
  freshGate.complete('new');
  check(
    await fresh == 'new' && cache.peek(key()) == 'new',
    'new generation cached',
  );
  cache.clear();
  var failed = false;
  try {
    await cache.resolve(key(), () => Future.error(StateError('fixture')));
  } catch (_) {
    failed = true;
  }
  check(failed && cache.peek(key()) == null, 'failed loads not cached');
  check(
    await cache.resolve(key(), () => load('retry')) == 'retry',
    'retry after failure',
  );
  cache.clear();
  failed = false;
  try {
    await cache.resolve(key(), () => throw StateError('sync fixture'));
  } catch (_) {
    failed = true;
  }
  check(failed, 'sync loader errors become failed futures');
  check(
    await cache.resolve(key(), () => load('recovered')) == 'recovered',
    'retry after sync error',
  );
  final structured = ScopedChapterCache<String>();
  await structured.resolve(key(watch: 'a|b', mirror: 'c'), () => load('one'));
  check(
    await structured.resolve(
          key(watch: 'a', mirror: 'b|c'),
          () => load('two'),
        ) ==
        'two',
    'delimiter-safe identity',
  );
  check(
    await structured.resolve(key(mirror: ''), () => load('empty')) == 'empty',
    'empty mirror identity',
  );
  check(
    await structured.resolve(key(), () => load('null')) == 'null',
    'null mirror distinct',
  );
  failed = false;
  try {
    ScopedChapterCache<String>(maxEntries: 0);
  } catch (_) {
    failed = true;
  }
  check(failed, 'invalid capacity rejected');
  stdout.writeln(
    'PASS: $checks chapter cache checks (offline production helper)',
  );
}
