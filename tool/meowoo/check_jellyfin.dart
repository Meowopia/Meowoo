import 'dart:convert';
import 'dart:io';

import 'package:miru_alpha/ui/features/jellyfin/jellyfin_client.dart';

const user = '00000000000000000000000000000001';
const folder = '00000000000000000000000000000002';
const show = '00000000000000000000000000000003';
const episode = '00000000000000000000000000000004';
const movie = '00000000000000000000000000000005';
const token = 'local-fixture-token';

void require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

class FixtureTrust extends HttpOverrides {
  FixtureTrust(this.context);
  final SecurityContext context;
  @override
  HttpClient createHttpClient(SecurityContext? _) =>
      super.createHttpClient(context);
}

Map<String, Object> row(String id, String type) => {
  'Id': id,
  'Name': type,
  'Type': type,
};

Future<void> main(List<String> args) async {
  require(args.length == 2, 'Pass an ephemeral test certificate and key.');
  final trust = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificates(args[0]);
  final tls = SecurityContext()
    ..useCertificateChain(args[0])
    ..usePrivateKey(args[1]);
  final fixture = await HttpServer.bindSecure(
    InternetAddress.loopbackIPv4,
    0,
    tls,
  );
  final requests = <String>[];
  fixture.listen((request) async {
    final path = request.uri.path;
    final out = request.response;
    requests.add(path);
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    try {
      if (path == '/private/Users/AuthenticateByName') {
        require(request.method == 'POST', 'Expected POST login');
        require(
          authorization?.startsWith('MediaBrowser Client=') ?? false,
          'Missing Jellyfin authorization',
        );
        final login =
            jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        if (login['Username'] != 'meowoo-test' || login['Pw'] != 'fixture') {
          out.statusCode = 401;
          return;
        }
        out.write(
          jsonEncode({
            'User': {'Id': user},
            'AccessToken': token,
          }),
        );
        return;
      }
      require(
        authorization?.contains('Token="$token"') ?? false,
        'Token missing',
      );
      require(request.uri.queryParameters['api_key'] == null, 'Token in URL');
      if (path == '/private/Users/$user/Views') {
        out.write(
          jsonEncode({
            'Items': [row(folder, 'CollectionFolder')],
          }),
        );
      } else if (path == '/private/Items') {
        require(
          request.uri.queryParameters['parentId'] == folder,
          'Wrong library',
        );
        final offset = request.uri.queryParameters['startIndex'];
        out.write(
          jsonEncode({
            'Items': [
              offset == '0' ? row(show, 'Series') : row(movie, 'Movie'),
            ],
            'TotalRecordCount': 2,
          }),
        );
      } else if (path == '/private/Shows/$show/Episodes') {
        out.write(
          jsonEncode({
            'Items': [row(episode, 'Episode')],
          }),
        );
      } else if (path == '/private/Videos/$episode/stream') {
        require(
          request.uri.queryParameters['static'] == 'true',
          'Expected direct play',
        );
        require(
          request.headers.value(HttpHeaders.rangeHeader) == 'bytes=0-2',
          'Missing range',
        );
        out.statusCode = 206;
        out.headers
          ..contentType = ContentType('video', 'mp4')
          ..set(HttpHeaders.contentRangeHeader, 'bytes 0-2/6');
        out.contentLength = 3;
        out.add([1, 2, 3]);
      } else {
        out.statusCode = 404;
      }
    } finally {
      await out.close();
    }
  });
  try {
    final base = Uri.parse('https://127.0.0.1:${fixture.port}/private/');
    require(
      parseJellyfinServer('http://127.0.0.1') == null,
      'Allowed cleartext',
    );
    require(
      parseJellyfinServer('https://test:test@example.invalid') == null,
      'Allowed userinfo',
    );
    require(
      parseJellyfinServer('https://example.invalid/?x=y') == null,
      'Allowed query',
    );
    await HttpOverrides.runWithHttpOverrides(() async {
      try {
        final rejected = await JellyfinClient.connect(
          base,
          'meowoo-test',
          'bad',
        );
        rejected.close();
        throw StateError('Unexpected login success');
      } on JellyfinException catch (e) {
        require(e.unauthorized, 'Missing denied outcome');
      }
      final session = await JellyfinClient.connect(
        base,
        'meowoo-test',
        'fixture',
      );
      try {
        final libraries = await session.libraries();
        require(libraries.single.id == folder, 'Library list');
        final first = await session.browse(libraries.single);
        require(
          first.items.single.id == show && first.nextOffset == 1,
          'Pagination',
        );
        final next = await session.browse(
          libraries.single,
          offset: first.nextOffset!,
        );
        require(
          next.items.single.id == movie && next.nextOffset == null,
          'Final page',
        );
        final episodes = await session.browse(first.items.single);
        require(episodes.items.single.id == episode, 'Episode list');
        final playback = await session.play(episodes.items.single);
        final local = HttpClient();
        try {
          require(
            playback.uri.host == '127.0.0.1' &&
                !playback.uri.hasQuery &&
                !playback.uri.toString().contains(token),
            'Unsafe player URL',
          );
          final wrong = await (await local.getUrl(
            playback.uri.replace(path: '/wrong'),
          )).close();
          require(wrong.statusCode == 404, 'Unexpected relay resource');
          await wrong.drain<void>();
          final range = await local.getUrl(playback.uri);
          range.headers.set(HttpHeaders.rangeHeader, 'bytes=0-2');
          final response = await range.close();
          require(
            response.statusCode == 206 &&
                response.headers.value(HttpHeaders.contentRangeHeader) ==
                    'bytes 0-2/6',
            'Expected partial response',
          );
          require(
            (await response.expand((b) => b).toList()).join(',') == '1,2,3',
            'Media bytes differ',
          );
          require(
            requests.where((p) => p.contains('/Videos/')).length == 1,
            'Unexpected upstream relay request',
          );
        } finally {
          local.close(force: true);
          await playback.close();
        }
      } finally {
        session.close();
      }
    }, FixtureTrust(trust));
    stdout.writeln(
      'Passed Jellyfin HTTPS sign-in, library, episodes, and private range relay.',
    );
  } finally {
    await fixture.close(force: true);
  }
}
