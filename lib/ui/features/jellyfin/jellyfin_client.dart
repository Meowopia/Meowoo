// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Meowopia. See docs/licenses/meowoo-legacy-MIT.txt.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

enum JellyfinKind { library, series, movie, episode, video }

class JellyfinItem {
  const JellyfinItem({
    required this.id,
    required this.name,
    required this.kind,
    this.overview = '',
    this.hasPoster = false,
    this.season,
    this.episode,
    this.seriesName,
    this.runtime,
  });

  final String id;
  final String name;
  final JellyfinKind kind;
  final String overview;
  final bool hasPoster;
  final int? season;
  final int? episode;
  final String? seriesName;
  final Duration? runtime;

  static JellyfinItem? _parse(Object? data) {
    if (data is! Map<String, dynamic>) return null;
    final kind = switch (data['Type']) {
      'CollectionFolder' || 'UserView' => JellyfinKind.library,
      'Series' => JellyfinKind.series,
      'Movie' => JellyfinKind.movie,
      'Episode' => JellyfinKind.episode,
      'Video' => JellyfinKind.video,
      _ => null,
    };
    final name = data['Name'];
    final id = _guid(data['Id']);
    if (kind == null || id == null || name is! String || name.isEmpty) {
      return null;
    }
    final imageTags = data['ImageTags'];
    final ticks = data['RunTimeTicks'];
    return JellyfinItem(
      id: id,
      name: name,
      kind: kind,
      overview: data['Overview'] is String ? data['Overview'] as String : '',
      hasPoster: imageTags is Map && imageTags['Primary'] is String,
      season: data['ParentIndexNumber'] is int
          ? data['ParentIndexNumber'] as int
          : null,
      episode: data['IndexNumber'] is int ? data['IndexNumber'] as int : null,
      seriesName: data['SeriesName'] is String
          ? data['SeriesName'] as String
          : null,
      runtime: ticks is int && ticks > 0
          ? Duration(microseconds: ticks ~/ 10)
          : null,
    );
  }
}

class JellyfinPage {
  const JellyfinPage(this.items, this.nextOffset);
  final List<JellyfinItem> items;
  final int? nextOffset;
}

class JellyfinException implements Exception {
  const JellyfinException(this.status);
  final int status;
  bool get unauthorized => status == 401 || status == 403;
}

class JellyfinPlayback {
  const JellyfinPlayback(this.uri, this.close);
  final Uri uri;
  final Future<void> Function() close;
}

typedef JellyfinConnector = Future<JellyfinConnection> Function(
  Uri server,
  String username,
  String password,
);

abstract interface class JellyfinConnection {
  String get historyScope;
  Future<List<JellyfinItem>> libraries();
  Future<JellyfinPage> browse(JellyfinItem parent, {int offset = 0});
  Future<JellyfinItem> item(String id);
  Future<Uint8List> poster(JellyfinItem item);
  Future<JellyfinPlayback> play(JellyfinItem item);
  void close();
}

/// Accepts a reverse-proxy base path, but no credentials, query or fragment.
Uri? parseJellyfinServer(String input) {
  final uri = Uri.tryParse(input.trim());
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.authority.contains('@') ||
      uri.hasQuery ||
      uri.hasFragment ||
      RegExp(r'\s').hasMatch(input.trim())) {
    return null;
  }
  return uri.replace(
    pathSegments: [...uri.pathSegments.where((part) => part.isNotEmpty)],
  );
}

final _idPattern = RegExp(
  r'^(?:[a-f0-9]{32}|[a-f0-9]{8}-(?:[a-f0-9]{4}-){3}[a-f0-9]{12})$',
  caseSensitive: false,
);

String? _guid(Object? value) => value is String && _idPattern.hasMatch(value)
    ? value.toLowerCase().replaceAll('-', '')
    : null;

String _nonce() {
  final random = Random.secure();
  return base64Url.encode(List.generate(24, (_) => random.nextInt(256)));
}

final _deviceId = _nonce();
const _timeout = Duration(seconds: 15);

class JellyfinClient implements JellyfinConnection {
  JellyfinClient._(this._server, this._http, this._userId, this._token);

  final Uri _server;
  final HttpClient _http;
  final String _userId;
  final String _token;
  static const _pageSize = 40;

  @override
  String get historyScope => '$_server|$_userId';

  static Future<JellyfinConnection> connect(
    Uri server,
    String username,
    String password, {
    HttpClient Function()? clientFactory,
  }) async {
    final base = parseJellyfinServer(server.toString());
    if (base == null || username.trim().isEmpty) {
      throw const FormatException('Invalid Jellyfin connection');
    }
    final client = (clientFactory ?? HttpClient.new)()
      ..connectionTimeout = _timeout
      ..maxConnectionsPerHost = 6;
    try {
      final response = await _open(
        client,
        'POST',
        _endpoint(base, ['Users', 'AuthenticateByName']),
        data: {'Username': username.trim(), 'Pw': password},
      );
      final json = await _readJson(response);
      final user = json['User'];
      final id = user is Map ? _guid(user['Id']) : null;
      final token = json['AccessToken'];
      if (id == null ||
          token is! String ||
          !RegExp(r'^[A-Za-z0-9._~-]{1,256}$').hasMatch(token)) {
        throw const FormatException('Invalid Jellyfin login response');
      }
      return JellyfinClient._(base, client, id, token);
    } catch (_) {
      client.close(force: true);
      rethrow;
    }
  }

  static Uri _endpoint(
    Uri base,
    List<String> path, [
    Map<String, String>? query,
  ]) => base.replace(
    pathSegments: [...base.pathSegments.where((p) => p.isNotEmpty), ...path],
    queryParameters: query,
  );

  static Future<HttpClientResponse> _open(
    HttpClient client,
    String method,
    Uri url, {
    String? token,
    String? range,
    Map<String, String>? data,
  }) async {
    final request = await client.openUrl(method, url).timeout(_timeout);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'MediaBrowser Client="Meowoo", Device="Meowoo", '
      'DeviceId="$_deviceId", Version="0.3"'
      '${token == null ? '' : ', Token="$token"'}',
    );
    if (range != null) request.headers.set(HttpHeaders.rangeHeader, range);
    if (data != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(data));
    }
    return request.close().timeout(
      _timeout,
      onTimeout: () {
        request.abort();
        throw TimeoutException('Jellyfin response timed out');
      },
    );
  }

  static Future<Uint8List> _readBytes(
    HttpClientResponse response,
    int maximum,
  ) async {
    if (response.statusCode != 200 || response.contentLength > maximum) {
      await response.listen((_) {}).cancel();
      throw JellyfinException(response.statusCode);
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(_timeout)) {
      if (bytes.length + chunk.length > maximum) {
        throw const FormatException('Jellyfin reply too large');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static Future<Map<String, dynamic>> _readJson(
    HttpClientResponse response,
  ) async {
    final bytes = await _readBytes(response, 4 * 1024 * 1024);
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid Jellyfin response');
    }
    return json;
  }

  Future<HttpClientResponse> _get(
    List<String> path, [
    Map<String, String>? q,
  ]) => _open(_http, 'GET', _endpoint(_server, path, q), token: _token);

  static List<Object?> _rows(Map<String, dynamic> json) {
    final rows = json['Items'];
    if (rows is! List) throw const FormatException('Expected Jellyfin items');
    return rows;
  }

  @override
  Future<List<JellyfinItem>> libraries() async {
    final json = await _readJson(await _get(['Users', _userId, 'Views']));
    return _rows(json)
        .map(JellyfinItem._parse)
        .whereType<JellyfinItem>()
        .where((item) => item.kind == JellyfinKind.library)
        .toList();
  }

  @override
  Future<JellyfinPage> browse(JellyfinItem parent, {int offset = 0}) async {
    final series = parent.kind == JellyfinKind.series;
    final json = await _readJson(
      await _get(series ? ['Shows', parent.id, 'Episodes'] : ['Items'], {
        'userId': _userId,
        'startIndex': '$offset',
        'limit': '$_pageSize',
        'enableTotalRecordCount': 'true',
        'fields': series ? 'Overview' : 'Overview,Genres,Tags',
        if (series) 'isMissing': 'false',
        if (!series) ...{
          'parentId': parent.id,
          'recursive': 'true',
          'includeItemTypes': 'Series,Movie,Video',
          'sortBy': 'SortName',
        },
      }),
    );
    final rows = _rows(json);
    final total = json['TotalRecordCount'];
    final next = offset + rows.length;
    return JellyfinPage(
      rows
          .map(JellyfinItem._parse)
          .whereType<JellyfinItem>()
          .where((item) => item.kind != JellyfinKind.library)
          .toList(),
      rows.isNotEmpty &&
              (total is int ? next < total : rows.length >= _pageSize)
          ? next
          : null,
    );
  }

  @override
  Future<JellyfinItem> item(String id) async {
    if (_guid(id) == null) throw const FormatException('Invalid item ID');
    final item = JellyfinItem._parse(
      await _readJson(await _get(['Items', id], {'userId': _userId})),
    );
    if (item == null || item.id != _guid(id)) {
      throw const FormatException('Invalid Jellyfin item');
    }
    return item;
  }

  @override
  Future<Uint8List> poster(JellyfinItem item) async => _readBytes(
    await _get(['Items', item.id, 'Images', 'Primary'], {'maxWidth': '360'}),
    2 * 1024 * 1024,
  );

  @override
  Future<JellyfinPlayback> play(JellyfinItem item) async {
    if (_guid(item.id) == null ||
        item.kind == JellyfinKind.series ||
        item.kind == JellyfinKind.library) {
      throw const FormatException('Invalid video item');
    }
    final path = '/${_nonce()}/video';
    final upstream = _endpoint(
      _server,
      ['Videos', item.id, 'stream'],
      {'static': 'true'},
    );
    // The media engine sees only an ephemeral loopback URL. The relay forwards
    // a single fixed upstream resource and never follows redirects.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final transport = HttpClient()
      ..autoUncompress = false
      ..connectionTimeout = _timeout;
    server.listen((request) async {
      final out = request.response;
      try {
        if (request.uri.path != path ||
            request.uri.hasQuery ||
            !{'GET', 'HEAD'}.contains(request.method)) {
          out.statusCode = 404;
          return;
        }
        final response = await _open(
          transport,
          request.method,
          upstream,
          token: _token,
          range: request.headers.value(HttpHeaders.rangeHeader),
        );
        if (!{200, 206, 416}.contains(response.statusCode)) {
          await response.listen((_) {}).cancel();
          out.statusCode = response.statusCode >= 400
              ? response.statusCode
              : 502;
          return;
        }
        out.statusCode = response.statusCode;
        for (final header in [
          'content-type',
          'content-range',
          'accept-ranges',
          'content-encoding',
        ]) {
          final value = response.headers.value(header);
          if (value != null) out.headers.set(header, value);
        }
        if (response.contentLength >= 0) {
          out.contentLength = response.contentLength;
        }
        out.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        if (request.method == 'GET') {
          await out.addStream(response.timeout(_timeout));
        } else {
          await response.drain<void>();
        }
      } catch (_) {
        // A failed/cancelled transfer may have already sent response headers.
        try {
          out.statusCode = 502;
        } catch (_) {}
      } finally {
        try {
          await out.close();
        } catch (_) {}
      }
    });
    return JellyfinPlayback(
      Uri(scheme: 'http', host: '127.0.0.1', port: server.port, path: path),
      () async {
        transport.close(force: true);
        await server.close(force: true);
      },
    );
  }

  @override
  void close() => _http.close(force: true);
}
