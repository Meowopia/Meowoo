import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:miru_alpha/utils/store/nsfw_session.dart';

const restricted = 'test.restricted';

void main() {
  late NsfwSession session;
  setUp(() {
    session = NsfwSession()..markRestricted(restricted);
  });

  test(
    'an enabled restricted operation redacts provider failure details',
    () async {
      session.setEnabled(true);
      await expectLater(
        session.run(restricted, () async => throw StateError('private URL')),
        throwsA(isA<NsfwContentLoadFailed>()),
      );
    },
  );

  test('default off blocks requests before any side effect', () async {
    var calls = 0;
    await expectLater(
      session.run(restricted, () async => ++calls),
      throwsA(isA<NsfwUnavailable>()),
    );
    expect(calls, 0);
  });

  test(
    'normal sources work while off; opt-in only affects restricted sources',
    () async {
      expect(await session.run('test.normal', () async => 1), 1);
      session.setEnabled(true);
      expect(await session.run(restricted, () async => 2), 2);
    },
  );

  test(
    'opt-out requests cancellation and drops a late success after re-enable',
    () async {
      session.setEnabled(true);
      final result = Completer<int>();
      var cancels = 0;
      final pending = session.run(
        restricted,
        () => result.future,
        cancel: () async {
          cancels++;
        },
      );
      final error = expectLater(pending, throwsA(isA<NsfwUnavailable>()));

      session.setEnabled(false);
      expect(cancels, 1);
      session.setEnabled(true);
      result.complete(7);
      await error;
      expect(await session.run(restricted, () async => 9), 9);
    },
  );

  test('a late error does not leak provider details after opt-out', () async {
    session.setEnabled(true);
    final result = Completer<void>();
    final pending = session.run(restricted, () => result.future);
    final error = expectLater(pending, throwsA(isA<NsfwUnavailable>()));
    session.setEnabled(false);
    result.completeError(StateError('private result'));
    await error;
  });
}
