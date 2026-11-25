import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_hls_parser/flutter_hls_parser.dart';

typedef PlaybackSource = ({Map<String, String> qualityMap, String playbackUrl});
typedef ManifestFetch = Future<Response<ResponseBody>> Function(
  CancelToken token,
);

/// Optional, bounded quality discovery. The actual player remains responsible
/// for stream playback. Never consume a media file as if it were a playlist.
Future<PlaybackSource> resolvePlaybackManifest({
  required String url,
  required ManifestFetch fetch,
  Duration timeout = const Duration(seconds: 4),
  int maxBytes = 1024 * 1024,
}) async {
  if (timeout <= Duration.zero || maxBytes <= 0) {
    throw ArgumentError('Manifest timeout and byte limit must be positive.');
  }
  final fallback = (qualityMap: <String, String>{'': url}, playbackUrl: url);
  final origin = Uri.tryParse(url);
  if (origin == null || !_http(origin)) return fallback;
  final cancel = CancelToken();
  final clock = Stopwatch()..start();
  Duration remaining() {
    final budget = timeout - clock.elapsed;
    if (budget <= Duration.zero) {
      throw TimeoutException('Manifest probe timeout');
    }
    return budget;
  }

  StreamIterator<Uint8List>? iterator;
  ResponseBody? unreadBody;
  try {
    final pending = fetch(cancel);
    // A test/custom adapter may ignore cancellation. Reclaim a response that
    // arrives after the deadline rather than leaking its untouched body.
    unawaited(
      pending.then<void>((late) {
        if (cancel.isCancelled) unawaited(_discard(late.data));
      }, onError: (Object _, StackTrace _) {}),
    );
    final response = await pending.timeout(remaining());
    final body = response.data;
    if (body == null) return fallback;
    unreadBody = body;
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) return fallback;
    final mime = (response.headers.value('content-type') ?? '')
        .toLowerCase()
        .split(';')
        .first
        .trim();
    final hlsMime = mime.contains('mpegurl') || mime.contains('m3u8');
    final genericMime =
        mime.isEmpty ||
        mime == 'application/octet-stream' ||
        mime == 'text/plain';
    if (!hlsMime &&
        !(genericMime && origin.path.toLowerCase().endsWith('.m3u8'))) {
      return fallback;
    }
    iterator = StreamIterator(body.stream);
    unreadBody = null;
    final bytes = BytesBuilder(copy: false);
    while (await iterator.moveNext().timeout(remaining())) {
      final chunk = iterator.current;
      if (bytes.length + chunk.length > maxBytes) return fallback;
      bytes.add(chunk);
    }
    var text = utf8.decode(bytes.takeBytes());
    if (text.startsWith('\uFEFF')) text = text.substring(1);
    if (!text.startsWith('#EXTM3U')) return fallback;
    // The HTTP response URI is the local Core proxy, not the HLS origin.
    // Resolving relative variants against that URI creates unusable URLs.
    final playlist = await HlsPlaylistParser.create()
        .parseString(origin, text)
        .timeout(remaining());
    if (playlist is! HlsMasterPlaylist) return fallback;
    // Collapsing a master with separate audio/subtitle renditions loses those
    // tracks. Leave such masters intact for the native player to interpret.
    if ([
          ...playlist.audios,
          ...playlist.videos,
          ...playlist.subtitles,
        ].any((rendition) => rendition.url != null) ||
        playlist.sessionKeyDrmInitData.isNotEmpty) {
      return fallback;
    }
    final qualities = <String, String>{};
    final seen = <String>{};
    for (final variant in playlist.variants) {
      final target = origin.resolveUri(variant.url);
      if (!_http(target) || !seen.add(target.toString())) continue;
      final format = variant.format;
      final width = format.width ?? 0, height = format.height ?? 0;
      final bitrate = format.bitrate ?? 0;
      final base = width > 0 && height > 0
          ? '${width}x$height'
          : bitrate > 0
          ? '${(bitrate / 1000).round()} kbps'
          : '#${qualities.length + 1}';
      var label = base;
      var suffix = 2;
      if (qualities.containsKey(label) && bitrate > 0) {
        label = '$base · ${(bitrate / 1000).round()} kbps';
      }
      final distinctBase = label;
      while (qualities.containsKey(label)) {
        label = '$distinctBase (${suffix++})';
      }
      qualities[label] = target.toString();
    }
    if (qualities.isEmpty) return fallback;
    return (qualityMap: qualities, playbackUrl: qualities.values.first);
  } catch (error) {
    if (error is DioException && error.response?.data is ResponseBody) {
      await _discard(error.response!.data as ResponseBody);
    }
    // Discovery failure must not prevent the engine from opening the original
    // stream, nor emit raw signed media URLs into diagnostic logs.
    return fallback;
  } finally {
    cancel.cancel('Optional manifest probe completed');
    if (unreadBody != null) await _discard(unreadBody);
    try {
      await iterator?.cancel().timeout(const Duration(milliseconds: 500));
    } catch (_) {}
  }
}

bool _http(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;

Future<void> _discard(ResponseBody? body) async {
  if (body == null) return;
  try {
    // StreamIterator is lazy: cancelling it before moveNext never attaches to
    // the network body. Subscribe then cancel to actually close an unread body.
    final subscription = body.stream.listen(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    await subscription.cancel().timeout(const Duration(milliseconds: 500));
  } catch (_) {}
}
