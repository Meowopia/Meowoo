import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:miru_alpha/data/sources/huangguo.dart';
import 'package:miru_alpha/utils/store/nsfw_session.dart';

Object response(Map<String, Object?> data) => {'status': 1, 'data': data};
Object feed() => response({
  'items': [
    {'id': 42, 'title': 'Fixture series'},
    {'id': 42, 'title': 'Duplicate'},
    {'id': 0, 'title': 'Invalid'},
  ],
  'pagination': {'pages': 2},
});
Object detail() => response({
  'id': 42,
  'title': 'Fixture series',
  'episodes': [
    {'ep_num': 3, 'title': 'Episode 3', 'status': 1},
    {'ep_num': 2, 'title': 'Unavailable', 'status': 0},
    {'ep_num': 1, 'title': 'Episode 1', 'status': 1},
  ],
});

class FixtureTransport implements HuangguoTransport {
  FixtureTransport(this.reply);
  final FutureOr<Object?> Function(String path) reply;
  final calls = <Map<String, String>>[];
  int closes = 0;

  @override
  Future<Object?> read(Map<String, String> request) async {
    calls.add(request);
    return reply(request['path']!);
  }

  @override
  void close() => closes++;
}

void main() {
  late NsfwSession gate;
  setUp(() => gate = NsfwSession());

  HuangguoSession open(FixtureTransport transport) {
    gate.setEnabled(true);
    final session = HuangguoSession(
      privacy: gate,
      createTransport: () => transport,
    );
    addTearDown(session.close);
    return session;
  }

  test('does not even construct a transport while NSFW is off', () {
    var created = 0;
    expect(
      () => HuangguoSession(
        privacy: gate,
        createTransport: () {
          created++;
          return FixtureTransport((_) => feed());
        },
      ),
      throwsA(isA<HuangguoUnavailable>()),
    );
    expect(created, 0);
  });

  test(
    'browse is lazy, paginated and limited to the short-drama catalogue',
    () async {
      final transport = FixtureTransport((_) => feed());
      final session = open(transport);
      expect(transport.calls, isEmpty);
      final first = await session.browse();
      expect(first.titles.map((row) => row.id), [42]);
      expect(first.nextPage, 2);
      expect((await session.browse(page: first.nextPage!)).nextPage, isNull);
      expect(transport.calls.first, {
        'method': 'GET',
        'path': '/api/videos/category/ai-duanju?page=1&size=20',
        'body': '',
        'content_type': '',
      });
      await expectLater(
        session.browse(page: 0),
        throwsA(isA<HuangguoUnavailable>()),
      );
      expect(transport.calls, hasLength(2));
    },
  );

  test('details only expose available episodes in order', () async {
    final transport = FixtureTransport(
      (path) => path == '/api/videos/42' ? detail() : feed(),
    );
    final session = open(transport);
    final series = (await session.browse()).titles.single;
    expect((await session.detail(series)).episodes.map((ep) => ep.number), [
      1,
      3,
    ]);
  });

  test('resolves only signed HTTPS manifests from approved hosts and honors denials', () async {
    Object play = response({
      'id': 42,
      'ep': 1,
      'streams': {
        'main': 'https://yd-lphu-hls.tjyyjk.cn/sample.m3u8?auth_key=fixture',
      },
    });
    final transport = FixtureTransport((path) {
      if (path.contains('/playback')) return play;
      return path == '/api/videos/42' ? detail() : feed();
    });
    final session = open(transport);
    final episode = (await session.detail(
      (await session.browse()).titles.single,
    )).episodes.first;
    expect((await session.playback(episode)).path, '/sample.m3u8');
    expect(transport.calls.last, {
      'method': 'POST',
      'path': '/api/videos/42/episodes/1/playback',
      'body': '',
      'content_type': '',
    });
    for (final invalid in [
      {'status': 0},
      response({'id': 41, 'ep': 1, 'streams': <String, String>{}}),
      response({'id': 42, 'ep': 2, 'streams': <String, String>{}}),
      response({'id': 42, 'ep': 1, 'streams': <String, String>{}}),
      for (final url in [
        'https://example.test/a.m3u8',
        'http://yd-lphu-hls.tjyyjk.cn/a.mp4',
        'https://yd-lphu-hls.tjyyjk.cn:8443/a.mp4',
        'https://user@yd-lphu-hls.tjyyjk.cn/a.mp4',
        'https://yd-lphu-hls.tjyyjk.cn/a.mp4#fragment',
        'https://yd-lphu-hls.tjyyjk.cn/video/42',
      ])
        response({
          'id': 42,
          'ep': 1,
          'streams': {'main': url},
        }),
    ]) {
      play = invalid;
      await expectLater(
        session.playback(episode),
        throwsA(isA<HuangguoUnavailable>()),
      );
    }
  });

  test(
    'opt-out closes transport and rejects late results even after opt-in',
    () async {
      final pending = Completer<Object?>();
      final transport = FixtureTransport((_) => pending.future);
      final session = open(transport);
      final result = expectLater(
        session.browse(),
        throwsA(isA<HuangguoUnavailable>()),
      );
      gate.setEnabled(false);
      expect(transport.closes, 1);
      expect(session.active, isFalse);
      gate.setEnabled(true);
      pending.complete(feed());
      await result;
      await expectLater(session.browse(), throwsA(isA<HuangguoUnavailable>()));
      expect(transport.calls, hasLength(1));
      session.close();
      expect(transport.closes, 1);
    },
  );

  test(
    'leaving the page closes the private transport even with NSFW on',
    () async {
      final transport = FixtureTransport((_) => feed());
      final session = open(transport)..close();
      await expectLater(session.browse(), throwsA(isA<HuangguoUnavailable>()));
      expect(transport.calls, isEmpty);
      expect(transport.closes, 1);
    },
  );
}
