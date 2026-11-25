import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:miru_alpha/utils/http/request.dart';
import 'package:miru_alpha/utils/watch/playback_manifest.dart';

int checks = 0;
void check(bool value, String name) {
  checks++;
  if (!value) throw StateError(name);
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
const origin = 'https://media.example/library/master.m3u8';
const master =
    '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=600000,RESOLUTION=640x360\nlow/index.m3u8\n#EXT-X-STREAM-INF:BANDWIDTH=1800000,RESOLUTION=1280x720\nhigh/index.m3u8\n';

class Fixture {
  Fixture({
    String text = master,
    List<List<int>>? chunks,
    String? mime = 'application/vnd.apple.mpegurl',
    int status = 200,
    bool idle = false,
    bool error = false,
  }) {
    late StreamController<Uint8List> controller;
    controller = StreamController<Uint8List>(
      onListen: () {
        if (idle) return;
        scheduleMicrotask(() {
          if (cancelled > 0) return;
          if (error) {
            controller.addError(StateError('fixture stream failure'));
          } else {
            for (final part in chunks ?? [utf8.encode(text)]) {
              controller.add(Uint8List.fromList(part));
            }
          }
          unawaited(controller.close());
        });
      },
      onCancel: () {
        cancelled++;
      },
    );
    final headers = <String, List<String>>{
      if (mime != null) 'content-type': [mime],
    };
    response = Response<ResponseBody>(
      data: ResponseBody(controller.stream, status, headers: headers),
      headers: Headers.fromMap(headers),
      statusCode: status,
      // Intentionally a proxy URL: relative variants must NOT use this base.
      requestOptions: RequestOptions(
        path: 'http://127.0.0.1:13337/proxy/encoded',
      ),
    );
  }
  late Response<ResponseBody> response;
  int cancelled = 0;
  CancelToken? token;
  Future<Response<ResponseBody>> fetch(CancelToken value) async {
    token = value;
    return response;
  }
}

Future<void> main() async {
  final f = Fixture();
  var result = await resolvePlaybackManifest(url: origin, fetch: f.fetch);
  check(
    result.playbackUrl == 'https://media.example/library/low/index.m3u8',
    'relative video URL uses source origin, not Core proxy',
  );
  check(
    result.qualityMap['1280x720'] ==
        'https://media.example/library/high/index.m3u8',
    'correct variant/quality pairing',
  );
  check(result.qualityMap.length == 2, 'both video variants retained');
  check(
    f.cancelled == 1 && f.token!.isCancelled,
    'completed response body and request reclaimed',
  );

  Future<void> fallback(
    Fixture fixture,
    String label, {
    String url = origin,
    int maxBytes = 1024 * 1024,
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final r = await resolvePlaybackManifest(
      url: url,
      fetch: fixture.fetch,
      maxBytes: maxBytes,
      timeout: timeout,
    );
    check(r.playbackUrl == url && r.qualityMap.length == 1, label);
    check(
      fixture.cancelled == 1 && fixture.token!.isCancelled,
      '$label body closed',
    );
  }

  await fallback(
    Fixture(mime: 'video/mp4', idle: true),
    'MP4 not read as a manifest',
    url: 'https://media.example/movie.mp4',
  );
  await fallback(
    Fixture(mime: 'video/mp2t', idle: true),
    'MPEG-TS binary not read as playlist',
  );
  await fallback(Fixture(text: ''), 'empty playlist fallback');
  await fallback(
    Fixture(text: '<html>error</html>'),
    'HTML error body fallback',
  );
  await fallback(
    Fixture(
      chunks: [
        [0xff, 0xfe, 0xfd],
      ],
    ),
    'invalid UTF-8 fallback',
  );
  await fallback(
    Fixture(status: 403, idle: true),
    'failed HTTP status fallback',
  );
  await fallback(Fixture(error: true), 'stream error fallback');
  await fallback(
    Fixture(chunks: [List.filled(16, 65), List.filled(16, 66)]),
    'oversized body capped',
    maxBytes: 24,
  );
  await fallback(
    Fixture(idle: true),
    'idle stream deadline',
    timeout: const Duration(milliseconds: 25),
  );
  await fallback(
    Fixture(
      text: '#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\npart.ts\n#EXT-X-ENDLIST\n',
    ),
    'media playlist stays unchanged',
  );

  for (final mime in [
    'application/octet-stream',
    'text/plain',
    null,
    'APPLICATION/X-MPEGURL; charset=utf-8',
  ]) {
    final fixture = Fixture(mime: mime);
    final r = await resolvePlaybackManifest(url: origin, fetch: fixture.fetch);
    check(r.qualityMap.length == 2, 'HLS suffix/mime accepted: $mime');
  }
  final withCjk = master.replaceFirst('#EXTM3U\n', '#EXTM3U\n# 中文分段测试\n');
  final bytes = utf8.encode(withCjk);
  final multibyte = Fixture(chunks: bytes.map((b) => [b]).toList());
  result = await resolvePlaybackManifest(url: origin, fetch: multibyte.fetch);
  check(
    result.qualityMap.length == 2,
    'UTF-8 code points split across byte chunks decode correctly',
  );
  result = await resolvePlaybackManifest(
    url: origin,
    fetch: Fixture(text: '\uFEFF$master').fetch,
  );
  check(result.qualityMap.length == 2, 'UTF-8 BOM handled');

  const externalAudio =
      '#EXTM3U\n#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="中文",DEFAULT=YES,URI="audio/zh.m3u8"\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720,AUDIO="audio"\nvideo/index.m3u8\n';
  await fallback(
    Fixture(text: externalAudio),
    'master with separate audio stays intact (avoid silent video)',
  );
  const externalSub =
      '#EXTM3U\n#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="中文",DEFAULT=NO,URI="subs/zh.m3u8"\n#EXT-X-STREAM-INF:BANDWIDTH=1000000,RESOLUTION=1280x720,SUBTITLES="subs"\nvideo/index.m3u8\n';
  await fallback(
    Fixture(text: externalSub),
    'master with external subtitles stays intact',
  );
  final duplicates = master.replaceAll('640x360', '1280x720');
  result = await resolvePlaybackManifest(
    url: origin,
    fetch: Fixture(text: duplicates).fetch,
  );
  check(
    result.qualityMap.length == 2 &&
        result.qualityMap.values.toSet().length == 2,
    'duplicate resolutions do not erase variants',
  );
  result = await resolvePlaybackManifest(
    url: origin,
    fetch: Fixture(
      text: master
          .replaceAll(',RESOLUTION=640x360', '')
          .replaceAll(',RESOLUTION=1280x720', ''),
    ).fetch,
  );
  check(
    result.qualityMap.keys.every(
      (k) => !k.contains('null') && !k.contains('-1'),
    ),
    'unknown resolution has a usable label',
  );

  final headerGate = Completer<Response<ResponseBody>>();
  CancelToken? lateToken;
  result = await resolvePlaybackManifest(
    url: origin,
    fetch: (token) {
      lateToken = token;
      return headerGate.future;
    },
    timeout: const Duration(milliseconds: 25),
  );
  check(
    result.playbackUrl == origin && lateToken!.isCancelled,
    'header deadline cancels pending probe',
  );
  final late = Fixture();
  headerGate.complete(late.response);
  await tick();
  await tick();
  check(late.cancelled == 1, 'late response after timeout reclaimed');
  result = await resolvePlaybackManifest(
    url: origin,
    fetch: (_) async => throw StateError('network unavailable'),
  );
  check(
    result.playbackUrl == origin,
    'network failure does not block original stream',
  );
  final errorBody = Fixture(status: 403, idle: true);
  result = await resolvePlaybackManifest(
    url: origin,
    fetch: (_) async => throw DioException.badResponse(
      statusCode: 403,
      requestOptions: errorBody.response.requestOptions,
      response: errorBody.response,
    ),
  );
  check(
    result.playbackUrl == origin && errorBody.cancelled == 1,
    'error response body reclaimed',
  );
  var called = false;
  result = await resolvePlaybackManifest(
    url: 'file:///not-a-network-manifest',
    fetch: (_) async {
      called = true;
      return Fixture().response;
    },
  );
  check(
    !called && result.playbackUrl.startsWith('file:'),
    'non-network input not probed',
  );
  var rejected = false;
  try {
    await resolvePlaybackManifest(
      url: origin,
      fetch: Fixture().fetch,
      maxBytes: 0,
    );
  } on ArgumentError {
    rejected = true;
  }
  check(rejected, 'invalid probe budget rejected');

  await proxyIntegration();
  stdout.writeln(
    'PASS: $checks playback-manifest checks (fixtures + local HTTP proxy-shaped integration; no real provider/Core/native playback)',
  );
}

Future<void> proxyIntegration() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  var headerSeen = false;
  final serving = server.listen((request) async {
    final source = request.uri.pathSegments.last;
    if (source.endsWith('/data.json')) {
      request.response.headers.contentType = ContentType.json;
      request.response.write('{"ok":true}');
    } else {
      headerSeen = request.headers.value('x-fixture') == 'preserved';
      request.response.headers.set(
        'content-type',
        'application/vnd.apple.mpegurl',
      );
      request.response.write(master);
    }
    await request.response.close();
  });
  try {
    MiruRequest.ensureInitalized(host: 'http://127.0.0.1:${server.port}');
    final raw = await MiruRequest.get('https://media.example/data.json');
    check(
      raw is Map && raw['ok'] == true,
      'existing get() body-only JSON contract unchanged',
    );
    final bodyOnly = await MiruRequest.get(
      origin,
      options: Options(responseType: ResponseType.stream),
    );
    check(
      bodyOnly is ResponseBody,
      'legacy get(stream) returns a body, not a full HTTP Response',
    );
    await (bodyOnly as ResponseBody).stream
        .listen((_) {}, onError: (Object _, StackTrace _) {})
        .cancel();
    final typed = await MiruRequest.getStreamResponse(
      origin,
      headers: {'X-Fixture': 'preserved'},
    );
    check(
      typed.statusCode == 200 &&
          typed.headers.value('content-type')!.contains('mpegurl'),
      'typed wrapper exposes response status/headers',
    );
    final content = await typed.data!.stream.fold<List<int>>(
      [],
      (bytes, chunk) => bytes..addAll(chunk),
    );
    check(
      utf8.decode(content).startsWith('#EXTM3U'),
      'typed wrapper exposes ResponseBody stream',
    );
    final actual = await resolvePlaybackManifest(
      url: origin,
      fetch: (cancel) => MiruRequest.getStreamResponse(
        origin,
        headers: {'X-Fixture': 'preserved'},
        cancelToken: cancel,
      ),
    );
    check(
      actual.playbackUrl == 'https://media.example/library/low/index.m3u8',
      'real Dio response + proxy path resolves against origin',
    );
    check(headerSeen, 'source request headers retained');
  } finally {
    await serving.cancel();
    await server.close(force: true);
  }
}
