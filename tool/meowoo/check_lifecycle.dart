import 'dart:async';

import 'package:miru_alpha/utils/store/settings_snapshot_guard.dart';
import 'package:miru_alpha/utils/watch/async_resource_session.dart';

int checks = 0;
void check(bool value, String name) {
  checks++;
  if (!value) throw StateError(name);
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

class Resource {
  Resource(this.name);
  final String name;
  int released = 0;
}

Future<void> main() async {
  snapshotChecks();
  await resourceChecks();
  stdoutMessage();
}

void stdoutMessage() {
  // ignore: avoid_print
  print(
    'PASS: $checks lifecycle/snapshot checks (synthetic resources; no native player/RPC)',
  );
}

void snapshotChecks() {
  final guard = SettingsSnapshotGuard();
  const defaults = {'theme': 'system', 'language': 'en', 'pack': ''};
  var local = {'theme': 'dark', 'language': 'zh', 'pack': 'ocean'};
  final epoch = guard.beginRead();
  check(guard.accepts(epoch), 'current snapshot accepted');
  var merged = guard.merge(
    remote: {'theme': 'light'},
    defaults: defaults,
    local: local,
  );
  check(merged['theme'] == 'light', 'untouched server preference can load');
  check(
    merged['language'] == 'zh' && merged['pack'] == 'ocean',
    'partial snapshot preserves last-known session values',
  );
  final cold = guard.merge(remote: {}, defaults: defaults, local: {});
  check(
    cold['language'] == 'en' && cold['theme'] == 'system',
    'defaults survive an empty initial snapshot',
  );
  guard.edited(['theme']);
  merged = guard.merge(
    remote: {'theme': 'light', 'language': 'ja'},
    defaults: defaults,
    local: local,
  );
  check(merged['theme'] == 'dark', 'late snapshot preserves local edit');
  check(merged['language'] == 'ja', 'untouched keys still read from server');
  guard.edited(['enabled']);
  local['enabled'] = 'false';
  merged = guard.merge(
    remote: {'enabled': 'true'},
    defaults: defaults,
    local: local,
  );
  check(
    merged['enabled'] == 'false',
    'pending opt-out not re-enabled by old server value',
  );
  guard.edited(['pack']);
  local['pack'] = '';
  merged = guard.merge(
    remote: {'pack': 'ocean'},
    defaults: defaults,
    local: local,
  );
  check(merged['pack'] == '', 'explicit empty selection preserved');
  local = {'pack': 'ocean', 'base': 'mist', 'accent': 'cyan', 'theme': 'dark'};
  merged = guard.merge(
    remote: {'pack': 'foreign', 'base': 'mauve', 'accent': 'pink'},
    defaults: defaults,
    local: local,
    deviceLocalKeys: {'pack', 'base', 'accent'},
  );
  check(
    merged['pack'] == 'ocean' &&
        merged['base'] == 'mist' &&
        merged['accent'] == 'cyan',
    'device-local pack and palette form a consistent snapshot',
  );
  check(
    local['base'] == 'mist' && !local.containsKey('language'),
    'merge leaves local input unchanged',
  );
  final newer = guard.beginRead();
  check(
    !guard.accepts(epoch) && guard.accepts(newer),
    'older response cannot overwrite newer read',
  );
  guard.reset();
  check(!guard.accepts(newer), 'reset invalidates in-flight response');
  merged = guard.merge(
    remote: {'theme': 'light'},
    defaults: defaults,
    local: local,
  );
  check(
    merged['theme'] == 'light',
    'fresh session permits server loading again',
  );
  merged['theme'] = 'changed-result';
  check(
    defaults['theme'] == 'system' && local['theme'] == 'dark',
    'result does not alias inputs',
  );
  guard.edited(['unknown-key']);
  merged = guard.merge(
    remote: {'theme': 'light'},
    defaults: defaults,
    local: local,
  );
  check(
    merged['theme'] == 'light',
    'missing local value does not erase unrelated defaults/server fields',
  );
}

Future<void> resourceChecks() async {
  AsyncResourceSession<Resource> session({
    Future<void> Function(Resource)? dispose,
    void Function(Object, StackTrace)? onError,
  }) => AsyncResourceSession<Resource>(
    dispose:
        dispose ??
        (r) async {
          r.released++;
        },
    onDisposeError: onError,
  );
  final s = session();
  final a = Resource('active');
  final b = Resource('staged');
  s.own(a);
  s.own(b);
  final old = s.begin();
  final next = s.begin();
  check(!s.accepts(old) && s.accepts(next), 'newest source request wins');
  await s.release(b);
  check(
    b.released == 1 && a.released == 0,
    'failed/stale candidate does not dispose active player',
  );
  final closing = s.close();
  check(s.closed && !s.accepts(next), 'close fences callbacks synchronously');
  check(identical(closing, s.close()), 'close idempotent');
  await closing;
  check(
    a.released == 1 && b.released == 1,
    'active and staged resources each released once',
  );
  await s.release(a);
  check(a.released == 1, 'late post-frame retirement cannot double-dispose');
  var refused = false;
  try {
    s.begin();
  } on StateError {
    refused = true;
  }
  check(refused, 'cannot start operations after route/session close');
  final late = Resource('late');
  s.own(late);
  await tick();
  check(
    late.released == 1,
    'late-arriving resource immediately retired after close',
  );
  final foreign = Resource('foreign');
  await s.release(foreign);
  check(foreign.released == 0, 'unowned player is not disposed');

  final gate = Completer<void>();
  final r = Resource('retiring');
  final waiting = session(
    dispose: (value) async {
      value.released++;
      await gate.future;
    },
  );
  waiting.own(r);
  final release = waiting.release(r);
  check(
    identical(release, waiting.release(r)),
    'duplicate retirement shares in-flight disposal',
  );
  var fullyClosed = false;
  final closeFuture = waiting.close().then((_) => fullyClosed = true);
  await tick();
  check(
    !fullyClosed && r.released == 1,
    'close waits for an already-retiring controller',
  );
  gate.complete();
  await closeFuture;
  check(
    fullyClosed && r.released == 1,
    'close completes after disposal drains',
  );

  var errors = 0;
  final fail = session(
    dispose: (value) async {
      value.released++;
      if (value.name == 'bad') throw StateError('cleanup failure');
    },
    onError: (_, _) {
      errors++;
      throw StateError('diagnostic failure');
    },
  );
  final bad = Resource('bad'), healthy = Resource('healthy');
  fail.own(bad);
  fail.own(healthy);
  await fail.close();
  check(
    errors == 1 && bad.released == 1 && healthy.released == 1,
    'cleanup/diagnostic errors do not strand other controllers',
  );

  final race = session();
  final slow = Resource('slow'), fast = Resource('fast');
  final slowReady = Completer<void>(), fastReady = Completer<void>();
  final published = <String>[];
  Future<void> prepare(Resource resource, Completer<void> ready) async {
    final token = race.begin();
    race.own(resource);
    await ready.future;
    if (race.accepts(token)) {
      published.add(resource.name);
    } else {
      await race.release(resource);
    }
  }

  final slowRequest = prepare(slow, slowReady);
  final fastRequest = prepare(fast, fastReady);
  fastReady.complete();
  await fastRequest;
  slowReady.complete();
  await slowRequest;
  check(
    published.length == 1 && published.single == 'fast',
    'old initialization completing last cannot publish',
  );
  check(
    slow.released == 1 && fast.released == 0,
    'stale initialized resource is reclaimed',
  );
  await race.close();
  check(fast.released == 1, 'selected controller cleaned on leave');

  final leaving = session();
  final initializing = Resource('initializing');
  final ready = Completer<void>();
  var played = false;
  leaving.own(initializing);
  final token = leaving.begin();
  final initialize = () async {
    await ready.future;
    if (leaving.accepts(token)) played = true;
  }();
  await leaving.close();
  ready.complete();
  await initialize;
  check(
    !played && initializing.released == 1,
    'late initialize after close cannot autoplay',
  );

  const duration = Duration(seconds: 100);
  check(
    clampPlaybackPosition(const Duration(seconds: 42), duration) ==
        const Duration(seconds: 42),
    'retain a valid resume position',
  );
  check(
    clampPlaybackPosition(const Duration(seconds: -1), duration) ==
        Duration.zero,
    'negative resume clamped',
  );
  check(
    clampPlaybackPosition(const Duration(seconds: 120), duration) == duration,
    'new shorter mirror clamps seek',
  );
  check(
    clampPlaybackPosition(duration, Duration.zero) == Duration.zero,
    'unknown duration safe seek',
  );
  check(
    clampPlaybackPosition(Duration.zero, duration) == Duration.zero,
    'new-source load can start at zero',
  );
}
