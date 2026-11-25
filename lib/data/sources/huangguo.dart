import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:miru_alpha/utils/store/nsfw_session.dart';
import 'package:pointycastle/export.dart';

final class HuangguoUnavailable implements Exception {
  const HuangguoUnavailable();
}

final class HuangguoTitle {
  const HuangguoTitle._(this.id, this.title);
  final int id;
  final String title;
}

final class HuangguoEpisode {
  const HuangguoEpisode._(this.seriesId, this.number, this.title);
  final int seriesId;
  final int number;
  final String title;
}

typedef HuangguoPage = ({List<HuangguoTitle> titles, int? nextPage});
typedef HuangguoDetail = ({String title, List<HuangguoEpisode> episodes});

abstract interface class HuangguoTransport {
  Future<Object?> read(Map<String, String> request);
  void close();
}

/// Anonymous, read-only short drama session. Created only after local opt-in.
/// It owns no credentials, persistent history or cache. It is never a sync source.
final class HuangguoSession {
  factory HuangguoSession({
    NsfwSession? privacy,
    HuangguoTransport Function()? createTransport,
  }) {
    final access = privacy ?? nsfwSession;
    if (!access.enabled) throw const HuangguoUnavailable();
    return HuangguoSession._(
      access,
      createTransport == null ? _HuangguoHttp() : createTransport(),
    );
  }

  HuangguoSession._(this._privacy, this._transport) : _epoch = _privacy.epoch {
    _subscription = _privacy.changes.listen((enabled) {
      if (!enabled) close();
    });
  }

  final NsfwSession _privacy;
  final int _epoch;
  final HuangguoTransport _transport;
  late final StreamSubscription<bool> _subscription;
  bool _closed = false;

  bool get active => !_closed && _privacy.enabled && _privacy.epoch == _epoch;

  Future<Map<String, dynamic>> _read(
    String path, {
    String method = 'GET',
  }) async {
    if (!active) throw const HuangguoUnavailable();
    final Object? result;
    try {
      result = await _transport.read({
        'method': method,
        'path': path,
        'body': '',
        'content_type': '',
      });
    } catch (_) {
      throw const HuangguoUnavailable();
    }
    if (!active || result is! Map<String, dynamic> || result['status'] != 1) {
      throw const HuangguoUnavailable();
    }
    final data = result['data'];
    if (data is! Map<String, dynamic>) throw const HuangguoUnavailable();
    return data;
  }

  Future<HuangguoPage> browse({int page = 1}) async {
    if (page < 1 || page > 10000) throw const HuangguoUnavailable();
    final data = await _read(
      '/api/videos/category/ai-duanju?page=$page&size=20',
    );
    final items = data['items'];
    final pagination = data['pagination'];
    if (items is! List || items.length > 100 || pagination is! Map) {
      throw const HuangguoUnavailable();
    }
    final titles = <HuangguoTitle>[];
    final seen = <int>{};
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['id'];
      final title = _text(item['title']);
      if (id is int && id > 0 && title != null && seen.add(id)) {
        titles.add(HuangguoTitle._(id, title));
      }
    }
    final pages = pagination['pages'];
    return (
      titles: List<HuangguoTitle>.unmodifiable(titles),
      nextPage:
          pages is int && page < pages && page < 10000 && titles.isNotEmpty
          ? page + 1
          : null,
    );
  }

  Future<HuangguoDetail> detail(HuangguoTitle entry) async {
    final data = await _read('/api/videos/${entry.id}');
    final items = data['episodes'];
    if (data['id'] != entry.id || items is! List || items.length > 1000) {
      throw const HuangguoUnavailable();
    }
    final episodes = <HuangguoEpisode>[];
    final seen = <int>{};
    for (final item in items) {
      if (item is! Map || item['status'] != 1) continue;
      final number = item['ep_num'];
      if (number is int && number > 0 && seen.add(number)) {
        episodes.add(
          HuangguoEpisode._(entry.id, number, _text(item['title']) ?? ''),
        );
      }
    }
    episodes.sort((a, b) => a.number.compareTo(b.number));
    return (
      title: _text(data['title']) ?? entry.title,
      episodes: List<HuangguoEpisode>.unmodifiable(episodes),
    );
  }

  Future<Uri> playback(HuangguoEpisode episode) async {
    final data = await _read(
      '/api/videos/${episode.seriesId}/episodes/${episode.number}/playback',
      method: 'POST',
    );
    // The manifest API reports the series id as a string while detail uses an
    // integer, so compare its text form and keep the episode check strict.
    final id = data['id'];
    if ((id != null && id.toString() != '${episode.seriesId}') ||
        (data.containsKey('ep') && data['ep'] != episode.number)) {
      throw const HuangguoUnavailable();
    }
    final streams = data['streams'];
    if (streams is! Map) throw const HuangguoUnavailable();
    final raw = _stream(streams);
    final uri = raw is String && raw.length <= 4096 ? Uri.tryParse(raw) : null;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.port != 443 ||
        uri.hasFragment ||
        !_mediaHosts.contains(uri.host) ||
        !RegExp(r'\.(m3u8|mp4)$', caseSensitive: false).hasMatch(uri.path)) {
      throw const HuangguoUnavailable();
    }
    return uri;
  }

  static String? _stream(Map<dynamic, dynamic> streams) {
    for (final key in const ['main', 'hevc', 'preview']) {
      final value = streams[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _text(Object? value) =>
      value is String && value.trim().isNotEmpty && value.length <= 512
      ? value.trim()
      : null;

  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_subscription.cancel());
    _transport.close();
  }
}

/// Exact media hosts observed for signed streams. Unknown hosts are rejected
/// rather than trusted, so a redirected API cannot point playback elsewhere.
const _mediaHosts = <String>{
  'huangguoai.com',
  'yd-lphu-hls.tjyyjk.cn',
  'yd-lphu-hls.hzjvlo.cn',
};

final _curve = ECCurve_prime256v1();
const _protocol = 'dx150-edge-v1';
const _maxSequence = 16384;
const _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36';

final class _HuangguoHttp implements HuangguoTransport {
  static const _maxBytes = 1024 * 1024;

  /// The current official address rotates; the permanent domain is kept as a
  /// fallback for networks where the rotating address is unreachable.
  static const _bases = ['ea3.aqkmowihz.cc', 'huangguoai.com'];
  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8);
  final Map<String, _EdgeSession> _sessions = {};
  int _base = 0;

  @override
  Future<Object?> read(Map<String, String> request) async {
    final method = request['method'] ?? 'GET';
    final path = request['path'] ?? '';
    if (!_safePath(path) || !const {'GET', 'POST'}.contains(method)) {
      throw const HuangguoUnavailable();
    }
    for (var attempt = 0; attempt < _bases.length; attempt++) {
      final host = _bases[_base];
      try {
        return await _readFrom(
          host,
          method,
          path,
          request['body'] ?? '',
          request['content_type'] ?? '',
        );
      } catch (_) {
        _base = (_base + 1) % _bases.length;
      }
    }
    // Never expose a provider error body or temporary playback token in logs/UI.
    throw const HuangguoUnavailable();
  }

  Future<Object?> _readFrom(
    String host,
    String method,
    String path,
    String body,
    String contentType,
  ) {
    if (path.startsWith('/api/videos/category/')) {
      return _request('GET', host, path, null);
    }
    final scope = path.contains('/playback') ? 'playback' : 'dynamic';
    return _encrypted(host, scope, method, path, body, contentType);
  }

  static bool _safePath(String path) =>
      path.startsWith('/api/videos/') &&
      !path.contains('..') &&
      !path.contains('\\') &&
      !path.contains('://') &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(path);

  static Uri _uri(String host, String path) {
    final uri = Uri.parse('https://$host$path');
    if (uri.scheme != 'https' || uri.host != host || uri.userInfo.isNotEmpty) {
      throw const HuangguoUnavailable();
    }
    return uri;
  }

  Future<Object?> _request(
    String method,
    String host,
    String path,
    Object? body,
  ) async {
    HttpClientRequest? active;
    try {
      return await (() async {
        final request = active = await _http.openUrl(method, _uri(host, path));
        request.followRedirects = false;
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        request.headers.set(HttpHeaders.refererHeader, 'https://$host/');
        request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
        if (body != null) {
          request.headers.contentType = ContentType.json;
          request.write(jsonEncode(body));
        }
        final response = await request.close();
        if (response.statusCode != 200 || response.contentLength > _maxBytes) {
          await response.listen((_) {}).cancel();
          throw const HuangguoUnavailable();
        }
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in response) {
          if (bytes.length + chunk.length > _maxBytes) {
            throw const HuangguoUnavailable();
          }
          bytes.add(chunk);
        }
        return jsonDecode(utf8.decode(bytes.takeBytes()));
      })().timeout(const Duration(seconds: 15));
    } catch (_) {
      active?.abort();
      throw const HuangguoUnavailable();
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String host,
    String path,
    Map<String, Object?> body,
  ) async {
    final result = await _request('POST', host, path, body);
    if (result is! Map<String, dynamic>) throw const HuangguoUnavailable();
    return result;
  }

  Future<Map<String, dynamic>> _encrypted(
    String host,
    String scope,
    String method,
    String path,
    String body,
    String contentType,
  ) async {
    final session = await _session(host, scope);
    final seq = ++session.sequence;
    if (seq > _maxSequence) throw const HuangguoUnavailable();
    final timestamp = _now() + session.clockOffset;
    final nonce = Uint8List(12);
    ByteData.sublistView(nonce).setUint32(8, seq, Endian.big);
    final packet = {
      'request': {
        'method': method,
        'path': path,
        'body': body,
        'content_type': contentType,
      },
    };
    final encrypted = _gcm(
      encrypt: true,
      key: session.requestKey,
      nonce: nonce,
      aad: utf8.encode('${session.info}\nreq\n$seq\n$timestamp'),
      input: Uint8List.fromList(utf8.encode(jsonEncode(packet))),
    );
    final response = await _postJson(host, '/api/$scope/request', {
      'v': 1,
      'type': 'call',
      'kid': session.kid,
      'sid': session.sid,
      'seq': seq,
      'ts': timestamp,
      'ciphertext': _encode64Url(encrypted),
    });
    if (response['v'] != 1 ||
        response['type'] != 'result' ||
        response['kid'] != session.kid ||
        response['sid'] != session.sid ||
        response['seq'] != seq ||
        response['ts'] != timestamp) {
      throw const HuangguoUnavailable();
    }
    final ciphertext = response['ciphertext'];
    if (ciphertext is! String) throw const HuangguoUnavailable();
    final decrypted = _gcm(
      encrypt: false,
      key: session.responseKey,
      nonce: nonce,
      aad: utf8.encode('${session.info}\nres\n$seq\n$timestamp'),
      input: _decode64Url(ciphertext),
    );
    final inner = jsonDecode(utf8.decode(decrypted));
    if (inner is! Map) throw const HuangguoUnavailable();
    final status = inner['status'];
    final encodedBody = inner['body'];
    if (status is! int ||
        status < 200 ||
        status > 599 ||
        encodedBody is! String) {
      throw const HuangguoUnavailable();
    }
    final bodyBytes = _decodeBase64(encodedBody);
    final decoded = jsonDecode(utf8.decode(bodyBytes));
    if (decoded is! Map<String, dynamic>) throw const HuangguoUnavailable();
    return decoded;
  }

  Future<_EdgeSession> _session(String host, String scope) async {
    final key = '$host|$scope';
    final now = _now();
    final existing = _sessions[key];
    if (existing != null &&
        existing.expiresAt > now + 5 &&
        existing.sequence < _maxSequence) {
      return existing;
    }
    final opened = await _openSession(host, scope);
    _sessions[key] = opened;
    return opened;
  }

  Future<_EdgeSession> _openSession(String host, String scope) async {
    final pair = _keyPair();
    final publicKey = pair.publicKey as ECPublicKey;
    final privateKey = pair.privateKey as ECPrivateKey;
    final rawPublic = publicKey.Q!.getEncoded(false);
    final hello = await _postJson(host, '/api/$scope/request', {
      'v': 1,
      'type': 'hello',
      'client_pub': _encode64Url(rawPublic),
    });
    final kid = hello['kid'];
    final sid = hello['sid'];
    final site = hello['site'];
    final serverTime = hello['server_time'];
    final expiresAt = hello['expires_at'];
    final serverPublic = hello['server_pub'];
    final salt = hello['salt'];
    if (hello['v'] != 1 ||
        hello['type'] != 'hello' ||
        kid is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(kid) ||
        sid is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(sid) ||
        site is! String ||
        !RegExp(r'^[A-Za-z0-9.:\[\]-]{1,256}$').hasMatch(site) ||
        serverTime is! int ||
        expiresAt is! int ||
        expiresAt <= serverTime ||
        expiresAt - serverTime > 600 ||
        serverPublic is! String ||
        salt is! String) {
      throw const HuangguoUnavailable();
    }
    final serverRaw = _decode64Url(serverPublic);
    if (serverRaw.length != 65 || serverRaw[0] != 4) {
      throw const HuangguoUnavailable();
    }
    final point = _curve.curve.decodePoint(serverRaw);
    final saltBytes = _decode64Url(salt);
    if (point == null || point.isInfinity || saltBytes.length != 32) {
      throw const HuangguoUnavailable();
    }
    final serverKey = ECPublicKey(point, _curve);
    final agreement = ECDHBasicAgreement()..init(privateKey);
    final shared = _int32(agreement.calculateAgreement(serverKey));
    final info = '$_protocol\n$scope\n$site\n$kid\n$sid';
    final now = _now();
    return _EdgeSession._(
      kid: kid,
      sid: sid,
      info: info,
      requestKey: _hkdf(shared, saltBytes, '$info\nreq'),
      responseKey: _hkdf(shared, saltBytes, '$info\nres'),
      clockOffset: serverTime - now,
      expiresAt: now + (expiresAt - serverTime) - 30,
    );
  }

  @override
  void close() {
    _sessions.clear();
    _http.close(force: true);
  }
}

final class _EdgeSession {
  _EdgeSession._({
    required this.kid,
    required this.sid,
    required this.info,
    required this.requestKey,
    required this.responseKey,
    required this.clockOffset,
    required this.expiresAt,
  });

  final String kid;
  final String sid;
  final String info;
  final Uint8List requestKey;
  final Uint8List responseKey;
  final int clockOffset;
  final int expiresAt;
  int sequence = 0;
}

AsymmetricKeyPair<PublicKey, PrivateKey> _keyPair() {
  final seed = Uint8List(32);
  final source = Random.secure();
  for (var i = 0; i < seed.length; i++) {
    seed[i] = source.nextInt(256);
  }
  final random = FortunaRandom()..seed(KeyParameter(seed));
  final generator = ECKeyGenerator()
    ..init(ParametersWithRandom(ECKeyGeneratorParameters(_curve), random));
  return generator.generateKeyPair();
}

Uint8List _hkdf(Uint8List ikm, Uint8List salt, String info) {
  final derivator = HKDFKeyDerivator(SHA256Digest())
    ..init(HkdfParameters(ikm, 32, salt, utf8.encode(info)));
  return derivator.process(Uint8List(0));
}

Uint8List _gcm({
  required bool encrypt,
  required Uint8List key,
  required Uint8List nonce,
  required Uint8List aad,
  required Uint8List input,
}) {
  final cipher = GCMBlockCipher(AESEngine())
    ..init(encrypt, AEADParameters(KeyParameter(key), 128, nonce, aad));
  return cipher.process(input);
}

Uint8List _int32(BigInt value) {
  final out = Uint8List(32);
  var current = value;
  for (var i = 31; i >= 0; i--) {
    out[i] = (current & BigInt.from(0xff)).toInt();
    current = current >> 8;
  }
  return out;
}

int _now() => DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

String _encode64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List _decode64Url(String text) {
  if (!RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(text)) {
    throw const HuangguoUnavailable();
  }
  var value = text.replaceAll('-', '+').replaceAll('_', '/');
  while (value.length % 4 != 0) {
    value += '=';
  }
  return base64Decode(value);
}

Uint8List _decodeBase64(String text) {
  var value = text;
  while (value.length % 4 != 0) {
    value += '=';
  }
  return base64Decode(value);
}
