import 'package:miru_alpha/utils/http/request.dart';
import 'package:miru_alpha/utils/watch/playback_manifest.dart';

export 'package:miru_alpha/utils/watch/playback_manifest.dart'
    show PlaybackSource;

/// Probe the manifest once; preserve the origin for relative URLs, close the
/// probe body, and leave complex/failed streams to the native player unchanged.
Future<PlaybackSource> resolvePlayback(
  String url,
  Map<String, dynamic> headers,
) => resolvePlaybackManifest(
  url: url,
  fetch: (cancelToken) => MiruRequest.getStreamResponse(
    url,
    headers: headers,
    cancelToken: cancelToken,
  ),
);

Future<Map<String, String>> getQuality(
  String url,
  Map<String, dynamic> headers,
) async => (await resolvePlayback(url, headers)).qualityMap;
