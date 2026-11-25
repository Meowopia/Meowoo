import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:miru_alpha/miru_core/network.dart';
import 'package:miru_alpha/miru_core/grpc_client.dart';
import 'package:miru_alpha/miru_core/proto/proto.dart' as proto;
import 'package:miru_alpha/model/index.dart';
import 'package:miru_alpha/provider/cast/dlna_cast_bridge.dart';
import 'package:miru_alpha/provider/cast/dlna_cast_provider.dart';
import 'package:miru_alpha/provider/network_provider.dart';
import 'package:miru_alpha/utils/watch/subtitle.dart';
import 'package:miru_alpha/utils/watch/async_resource_session.dart';
import 'package:miru_alpha/utils/core/log.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:miru_alpha/ui/core/core/toast.dart';
import 'package:miru_alpha/utils/http/request.dart';
import 'package:miru_alpha/miru_core/proto/generate/proto/extension_model.pb.dart'
    as pb_extension;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';
// The FVPControllerExtensions: setExternalSubtitle routes the subtitle into
// mdk's native (libass) renderer instead of the Dart software overlay.
import 'package:fvp/fvp.dart';

import 'package:material_ui/material_ui.dart';
part 'video_player_provider.g.dart';

class VideoPlayerTickState {
  Duration duration;
  List<DurationRange> bufferedRange;
  final Duration position;
  final bool isPlaying;
  final double speed;
  final int selectedSubtitleIndex;
  final bool isShowSideBar;
  final List<ExtensionBangumiWatchSubtitle> subtitlesRaw;
  final List<Subtitle> subtitles;
  final bool isShowSubtitle;
  final String currentSubtitle;
  final bool showControls;
  final bool showSettings;

  /// The pane the settings surface opens on — the landscape meta chips
  /// deep-link here (mirror / resolution / subtitle / speed); 0 keeps the
  /// first tab. The docked panel keys its tabs on this value so a change
  /// re-selects the pane while the panel is already mounted.
  final int settingsTab;
  final bool locked;
  final Map<String, String> qualityMap;
  final double ratio;
  final pb_extension.ExtensionWatch? v2watch;

  /// The video engine's request failure (fvp): the stream server answered
  /// non-200 (403 expired link, 404 gone, timeouts) or the demuxer failed.
  ///surfaced verbatim on the viewport's video-request error card; `null`
  /// while playback is healthy. Retry re-requests the same URL, Switch
  /// Mirror re-requests another mirror's URL.
  final String? playerError;

  /// Bumped on every controller swap (quality / mirror switch): the video
  /// surface watches it so the `VideoPlayer` widget rebinds to the fresh
  /// controller even when the new stream's aspect ratio is unchanged.
  final int playbackEpoch;
  VideoPlayerTickState({
    this.position = Duration.zero,
    this.isPlaying = false,
    this.duration = Duration.zero,
    this.speed = 1.0,
    this.bufferedRange = const [],
    this.selectedSubtitleIndex = 0,
    this.isShowSideBar = false,
    this.subtitlesRaw = const [],
    this.subtitles = const [],
    this.isShowSubtitle = false,
    this.qualityMap = const {},
    this.ratio = 0.0,
    this.currentSubtitle = '',
    this.showControls = false,
    this.showSettings = false,
    this.settingsTab = 0,
    this.locked = false,
    this.v2watch,
    this.playerError,
    this.playbackEpoch = 0,
  });

  VideoPlayerTickState copyWith({
    VideoPlayerController? controller,
    Duration? position,
    bool? isPlaying,
    Duration? duration,
    double? speed,
    List<DurationRange>? buffered,
    int? selectedSubtitleIndex,
    bool? isOpenSideBar,
    bool? isShowSideBar,
    List<ExtensionBangumiWatchSubtitle>? subtitlesRaw,
    List<Subtitle>? subtitles,
    bool? isShowSubtitle,
    bool? showControls,
    bool? showSettings,
    int? settingsTab,
    bool? locked,
    int? selectedGroupIndex,
    int? selectedEpisodeIndex,
    String? name,
    String? currentSubtitle,
    double? ratio,
    Map<String, String>? qualityMap,
    String? playerError,
    bool clearPlayerError = false,
    int? playbackEpoch,
    pb_extension.ExtensionWatch? v2watch,
  }) {
    return VideoPlayerTickState(
      position: position ?? this.position,
      isPlaying: isPlaying ?? this.isPlaying,
      duration: duration ?? this.duration,
      speed: speed ?? this.speed,
      bufferedRange: buffered ?? bufferedRange,
      selectedSubtitleIndex:
          selectedSubtitleIndex ?? this.selectedSubtitleIndex,
      isShowSideBar: isShowSideBar ?? this.isShowSideBar,
      subtitlesRaw: subtitlesRaw ?? this.subtitlesRaw,
      subtitles: subtitles ?? this.subtitles,
      isShowSubtitle: isShowSubtitle ?? this.isShowSubtitle,
      currentSubtitle: currentSubtitle ?? this.currentSubtitle,
      ratio: ratio ?? this.ratio,
      qualityMap: qualityMap ?? this.qualityMap,
      showControls: showControls ?? this.showControls,
      showSettings: showSettings ?? this.showSettings,
      settingsTab: settingsTab ?? this.settingsTab,
      locked: locked ?? this.locked,
      // The error is CLEARABLE: clearPlayerError resets it (retry/switch
      // re-request the stream and a healthy tick must clear the card).
      playerError: clearPlayerError ? null : (playerError ?? this.playerError),
      playbackEpoch: playbackEpoch ?? this.playbackEpoch,
      v2watch: v2watch ?? this.v2watch,
    );
  }
}

const videoExtensions = [
  "mp4",
  "webm",
  "ogg",
  "flv",
  "mov",
  "ts",
  "3gp",
  "avi",
  "wmv",
  "mkv",
  "mpg",
  "mpeg",
  "m4v",
  "mvp",
  "flac",
  "mp3",
  "wav",
  "m4a",
];

@riverpod
class VideoPlayerNotifier extends _$VideoPlayerNotifier
    implements DlnaPlayerSurface {
  late VideoPlayerController vidController;
  late Size defaultSize;
  late AsyncResourceSession<VideoPlayerController> _session = _newSession();
  int _subtitleEpoch = 0;
  int? _subtitleSelection;
  VideoPlayerController get videoPlayerController => vidController;

  /// The watch result's HTTP headers (Referer/User-Agent/…): the DLNA cast
  /// hands them to the ffmpeg engine so the source fetch passes the same
  /// gates the local player passes.
  Map<String, String> _streamHeaders = const {};

  /// The family's torrent / local-file source: quality switches are
  /// meaningless for them (no HLS manifest to resolve).
  ExtensionBangumiWatchTorrent? _familyTorrent;
  String? _familyLocalPath;

  /// Headers for the currently loaded stream, empty when none.
  Map<String, String> get streamHeaders => _streamHeaders;

  @override
  VideoPlayerTickState build(
    String? mediaUrl, {
    Map<String, String>? headers,
    Size? initialRatio,
    ExtensionBangumiWatchTorrent? torrent,
    String? localPath,
    Map<String, String> qualityMap = const {},
  }) {
    defaultSize = initialRatio ?? const Size(0, 0);
    _streamHeaders = Map<String, String>.unmodifiable(headers ?? const {});
    _familyTorrent = torrent;
    _familyLocalPath = localPath;
    // Register the simplified player surface: the cast session forwards app
    // actions and echoes renderer transport state back onto this notifier.
    final cast = ref.read(dlnaCastProvider.notifier);
    cast.attachPlayer(this);
    final session = _newSession();
    _session = session;
    _subtitleEpoch++;
    _subtitleSelection = null;
    String streamUrl = mediaUrl ?? '';
    vidController = _getController(
      streamUrl,
      headers ?? const {},
      torrent,
      localPath,
    );
    final initial = vidController;
    session.own(initial);
    // Register immediately, not inside a later initialization microtask.
    ref.onDispose(() {
      _subtitleEpoch++;
      cast.detachPlayer(this);
      final infoHash = torrent?.infoHash;
      if (infoHash != null && infoHash.isNotEmpty) {
        unawaited(_deleteTorrentQuietly(infoHash));
      }
    });
    final initialState = VideoPlayerTickState(
      showControls: false,
      ratio: vidController.value.aspectRatio,
      qualityMap: qualityMap,
    );

    Future.microtask(
      () => _init(
        session,
        initial,
        mediaUrl,
        headers ?? const {},
        qualityMap,
        inspectQualities:
            torrent == null && mediaUrl != null && localPath == null,
      ),
    );
    return initialState;
  }

  /// Injects the session data the shell resolved — the watch protobuf and the
  /// subtitle list — after the element exists. Family arguments are hashed
  /// into provider identity, so protobufs must never ride the family key;
  /// they belong to the open page, not to a keyed element.
  void setSession({
    List<ExtensionBangumiWatchSubtitle>? subtitlesRaw,
    pb_extension.ExtensionWatch? v2watch,
  }) {
    if (!ref.mounted) return;
    final nextSubtitles =
        subtitlesRaw ?? const <ExtensionBangumiWatchSubtitle>[];
    if (listEquals(state.subtitlesRaw, nextSubtitles) &&
        state.v2watch == v2watch) {
      return;
    }
    if (!listEquals(state.subtitlesRaw, nextSubtitles)) {
      closeSubtitle();
    }
    state = state.copyWith(subtitlesRaw: nextSubtitles, v2watch: v2watch);
  }

  VideoPlayerController _getController(
    String url,
    Map<String, String> headers,
    ExtensionBangumiWatchTorrent? torrent,
    String? localPath,
  ) {
    if (localPath != null) {
      return VideoPlayerController.file(File(localPath));
    }
    if (torrent != null) {
      for (var file in torrent.files) {
        final ext = file.split('.').last;
        if (videoExtensions.contains(ext)) {
          url =
              '${CoreNetwork.baseUrl}/torrent/data/${torrent.infoHash}/${Uri.encodeComponent(file)}';
          break;
        }
      }
    }
    return VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: headers,
    );
  }

  Timer? _hideTimer;
  int prevTime = 0;

  /// A scrub (seekbar drag / swipe seek) is in flight: the chrome auto-hide
  /// holds off so the bar cannot fade out mid-drag.
  bool _scrubbing = false;

  /// Seek target awaiting engine arrival (see [_updatePosition]): mdp/mdk
  /// keeps reporting the pre-seek position through the whole HLS rebuffer,
  /// so echoing it back snapped the thumb and time label backwards after
  /// release. Display holds the target until the engine lands.
  Duration? _seekTarget;
  DateTime _seekAt = DateTime.fromMillisecondsSinceEpoch(0);

  /// Engine position within this band of [_seekTarget] counts as landed.
  static const _seekArrivalBand = Duration(milliseconds: 900);

  /// Watchdog: never hold the displayed target longer than this.
  static const _seekHoldCap = Duration(seconds: 6);

  void setShowControls(bool v) {
    if (!_live(_session)) return;
    _hideTimer?.cancel();
    state = state.copyWith(showControls: v);
    if (v) {
      // Auto-hide only while playing: a paused surface keeps its controls —
      // the play/pause affordance stays visible (the reference mock does the
      // same). Pausing cancels this via the tap path re-showing controls.
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (!_live(_session)) return;
        if (state.isPlaying && !_scrubbing) {
          state = state.copyWith(showControls: false);
        }
      });
    }
  }

  /// Scrub session marker (seekbar drag start/end). While active the
  /// auto-hide is suspended; on end the 3s timer re-arms like a fresh
  /// control reveal.
  void setScrubbing(bool v) {
    if (!_live(_session)) return;
    if (_scrubbing == v) return;
    _scrubbing = v;
    _hideTimer?.cancel();
    if (!v && state.showControls && state.isPlaying) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (!_live(_session)) return;
        if (state.isPlaying && !_scrubbing) {
          state = state.copyWith(showControls: false);
        }
      });
    }
  }

  /// Screen lock (landscape mobile): a locked surface hides all chrome and
  /// swallows playback gestures until the unlock pill is tapped.
  void setLocked(bool v) {
    if (!_live(_session)) return;
    _hideTimer?.cancel();
    state = state.copyWith(locked: v, showControls: !v);
    if (!v) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (!_live(_session)) return;
        if (!_scrubbing) state = state.copyWith(showControls: false);
      });
    }
  }

  AsyncResourceSession<VideoPlayerController> _newSession() {
    final session = AsyncResourceSession<VideoPlayerController>(
      dispose: (controller) async {
        controller.removeListener(_updatePosition);
        await controller.dispose();
      },
      onDisposeError: (error, _) =>
          logger.warning('Player cleanup failed (${error.runtimeType})'),
    );
    ref.onDispose(() {
      _hideTimer?.cancel();
      unawaited(session.close());
    });
    return session;
  }

  bool _live(AsyncResourceSession<VideoPlayerController> session) =>
      ref.mounted && identical(session, _session) && !session.closed;

  bool _active(
    AsyncResourceSession<VideoPlayerController> session,
    VideoPlayerController controller,
  ) => _live(session) && identical(vidController, controller);

  bool _current(
    AsyncResourceSession<VideoPlayerController> session,
    int epoch,
  ) => _live(session) && session.accepts(epoch);

  Future<void> _deleteTorrentQuietly(String infoHash) async {
    try {
      await MiruGrpcClient.downloadClient.deleteTorrent(
        proto.DeleteTorrentRequest()..infoHash = infoHash,
      );
    } catch (error) {
      logger.warning('Torrent cleanup failed (${error.runtimeType})');
    }
  }

  Future<void> _init(
    AsyncResourceSession<VideoPlayerController> session,
    VideoPlayerController controller,
    String? url,
    Map<String, String> headers,
    Map<String, String> familyQualityMap, {
    required bool inspectQualities,
  }) async {
    if (!_active(session, controller)) return;
    try {
      await controller.initialize();
      if (!_active(session, controller)) return;
      controller.addListener(_updatePosition);
      await controller.play();
      if (!_active(session, controller)) return;
      state = state.copyWith(
        isPlaying: controller.value.isPlaying,
        duration: controller.value.duration,
        buffered: controller.value.buffered,
      );
    } catch (error) {
      if (_active(session, controller)) {
        state = state.copyWith(
          isPlaying: false,
          playerError: 'watch.player_initialize_failed'.i18n,
        );
        logger.warning('Player initialization failed (${error.runtimeType})');
      }
      return;
    }
    if (!inspectQualities || !_active(session, controller)) return;
    if (familyQualityMap.isNotEmpty) {
      state = state.copyWith(qualityMap: familyQualityMap);
      return;
    }
    try {
      final quality = await getQuality(url!, headers);
      if (_active(session, controller)) {
        state = state.copyWith(qualityMap: quality);
      }
    } catch (error) {
      // Quality discovery is optional; a playing video must remain playable.
      logger.fine('Quality discovery failed (${error.runtimeType})');
    }
  }

  List<double> get speedList => const [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    2.0,
    3.0,
  ];

  /// Clears the video-request error card (a fresh re-request is starting).
  void clearPlayerError() {
    state = state.copyWith(clearPlayerError: true);
  }

  /// Quality / mirror / retry switch. The target URL is resolved first (a
  /// mirror can hand back a multi-variant master — collapse it to one
  /// variant like the initial load; a known variant url skips the fetch),
  /// the fresh controller is built BESIDE the running one and swapped in
  /// only after it is ready; the old controller is disposed post-frame so
  /// the surface never renders a dead controller.
  Future<void> changeVideoQuality(String url) => _changeVideoQuality(url);

  Future<void> _changeVideoQuality(
    String url, {
    bool preservePosition = true,
  }) async {
    final session = _session;
    if (!_live(session) || _familyTorrent != null || _familyLocalPath != null) {
      return;
    }
    final epoch = session.begin();
    try {
      final knownVariant = state.qualityMap.containsValue(url);
      final headers = Map<String, String>.of(_streamHeaders);
      final src = knownVariant
          ? (qualityMap: state.qualityMap, playbackUrl: url)
          : await resolvePlayback(url, headers);
      if (!_current(session, epoch)) return;
      await _installController(
        session: session,
        epoch: epoch,
        fresh: VideoPlayerController.networkUrl(
          Uri.parse(src.playbackUrl),
          httpHeaders: headers,
        ),
        headers: headers,
        qualityMap: src.qualityMap,
        preservePosition: preservePosition,
      );
    } catch (error) {
      _switchFailed(session, epoch, error);
    }
  }

  void _switchFailed(
    AsyncResourceSession<VideoPlayerController> session,
    int epoch,
    Object error,
  ) {
    if (!_current(session, epoch)) return;
    logger.warning('Playback source switch failed (${error.runtimeType})');
    showSimpleToast('watch.player_switch_failed'.i18n);
  }

  Future<void> _installController({
    required AsyncResourceSession<VideoPlayerController> session,
    required int epoch,
    required VideoPlayerController fresh,
    required Map<String, String> headers,
    required Map<String, String> qualityMap,
    bool preservePosition = true,
    ExtensionBangumiWatch? mirrorResult,
  }) async {
    session.own(fresh);
    var installed = false;
    try {
      await fresh.initialize();
      if (!_current(session, epoch)) return;
      final old = vidController;
      final target = clampPlaybackPosition(
        preservePosition ? (_seekTarget ?? old.value.position) : Duration.zero,
        fresh.value.duration,
      );
      await fresh.setPlaybackSpeed(state.speed);
      if (!_current(session, epoch)) return;
      await fresh.seekTo(target);
      if (!_current(session, epoch)) return;
      final wasPlaying = old.value.isInitialized ? old.value.isPlaying : true;
      _seekTarget = null;
      _subtitleEpoch++;
      old.removeListener(_updatePosition);
      vidController = fresh;
      _streamHeaders = Map<String, String>.unmodifiable(headers);
      fresh.addListener(_updatePosition);
      installed = true;
      state = state.copyWith(
        playbackEpoch: state.playbackEpoch + 1,
        isPlaying: wasPlaying,
        position: target,
        speed: fresh.value.playbackSpeed,
        duration: fresh.value.duration,
        buffered: fresh.value.buffered,
        ratio: fresh.value.aspectRatio,
        qualityMap: qualityMap,
        clearPlayerError: true,
      );
      // Keep old as a valid render surface until the widget rebinds. Session
      // close also owns it, so leaving before this frame cannot leak it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(session.release(old));
      });
      unawaited(old.pause().catchError((Object _) {}));
      if (mirrorResult != null) {
        _familyTorrent = mirrorResult.hasTorrent()
            ? mirrorResult.torrent
            : null;
        _familyLocalPath = null;
        initSubtitle(mirrorResult.subtitles);
      } else if (_subtitleSelection case final index?) {
        unawaited(setSubSelectedIndex(index));
      }
      // Issue playback in this same turn; a later user/background pause must
      // not be undone by an await before the play command is sent.
      if (wasPlaying) await fresh.play();
    } finally {
      if (!installed) await session.release(fresh);
    }
  }

  /// Controller listener: pushes the player's value into Riverpod state.
  ///
  /// mdk fires many notifications per second (one per frame tick), and every
  /// push here rebuilds every watcher of this provider — pushing all of them
  /// is the transport's lag. Only meaningful deltas are pushed instead:
  /// 250ms position granularity (the scrubber still drags locally at full
  /// rate via its own useState), plus any discrete flag change.
  void _updatePosition() {
    if (!_live(_session)) return;
    final v = vidController.value;
    // Seek in flight: hold the displayed target (the user's release point)
    // until the engine actually lands — echoing the engine's stale
    // pre-seek position snapped the thumb backwards mid-rebuffer. Only
    // non-position fields move during the hold; errors still surface.
    if (_seekTarget != null) {
      final arrived = (v.position - _seekTarget!).abs() <= _seekArrivalBand;
      if (!arrived && DateTime.now().difference(_seekAt) < _seekHoldCap) {
        final errorNow = v.hasError ? v.errorDescription : null;
        if (v.isPlaying == state.isPlaying &&
            v.duration == state.duration &&
            v.aspectRatio == state.ratio &&
            errorNow == state.playerError &&
            _sameBuffered(v.buffered, state.bufferedRange)) {
          return;
        }
        state = state.copyWith(
          isPlaying: v.isPlaying,
          duration: v.duration,
          buffered: v.buffered,
          ratio: v.aspectRatio,
          playerError: errorNow,
          clearPlayerError: !v.hasError,
        );
        return;
      }
      _seekTarget = null;
    }
    final positionMoved =
        (v.position - state.position).abs() >=
        const Duration(milliseconds: 250);
    final playStateChanged = v.isPlaying != state.isPlaying;
    final errorNow = v.hasError ? v.errorDescription : null;
    final errorChanged = errorNow != state.playerError;
    if (!positionMoved &&
        !playStateChanged &&
        !errorChanged &&
        v.duration == state.duration &&
        v.aspectRatio == state.ratio &&
        _sameBuffered(v.buffered, state.bufferedRange)) {
      return;
    }
    state = state.copyWith(
      position: v.position,
      isPlaying: v.isPlaying,
      duration: v.duration,
      buffered: v.buffered,
      currentSubtitle: getCurrentSubtitle(),
      ratio: v.aspectRatio,
      // The video engine's request failure (the stream server answering
      // 403/404/5xx, expired signed links, demuxer failures) — video_player
      // reports it on the controller value; surface it verbatim for the
      // video-request error card. A healthy value clears it.
      playerError: errorNow,
      clearPlayerError: !v.hasError,
    );
  }

  /// Whether the two buffered ranges carry identical start/end points.
  bool _sameBuffered(List<DurationRange> a, List<DurationRange> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].start != b[i].start || a[i].end != b[i].end) return false;
    }
    return true;
  }

  void changeSubtitle(int index) {
    state = state.copyWith(selectedSubtitleIndex: index);
  }

  @override
  void play() {
    vidController.play();
    state = state.copyWith(isPlaying: true);
    // Cast session live: the local play is the master action — mirror it.
    DlnaCastBridge.instance.pipePlay();
  }

  void playOrPause() {
    if (state.isPlaying) {
      pause();
      return;
    }
    play();
  }

  @override
  void pause() {
    vidController.pause();
    state = state.copyWith(isPlaying: false);
    DlnaCastBridge.instance.pipePause();
  }

  void seek(Duration position) {
    state = state.copyWith(position: position);
    _seekTarget = position;
    _seekAt = DateTime.now();
    vidController.seekTo(position);
    DlnaCastBridge.instance.pipeSeek(position);
  }

  void seekBy(int seconds) {
    seek(state.position + Duration(seconds: seconds));
  }

  // --- DlnaPlayerSurface (the simplified player the cast session drives) ---

  @override
  Duration get position => state.position;

  @override
  Duration? get duration => state.duration;

  @override
  bool get playing => state.isPlaying;

  @override
  void seekTo(Duration position) => seek(position);

  @override
  Future<void> load(String source) async {
    // Episode/source switch — same machinery as a quality switch: a fresh
    // controller on the new source; the cast session re-pushes it.
    await _changeVideoQuality(source, preservePosition: false);
  }

  @override
  void syncTransport({required bool playing, required Duration position}) {
    if (!_live(_session)) return;
    // RENDERER→app echo: apply without re-forwarding (no pipe* calls here).
    state = state.copyWith(isPlaying: playing, position: position);
    if (playing) {
      vidController.play();
    } else {
      vidController.pause();
    }
    vidController.seekTo(position);
  }

  void setSpeed(double speed) {
    vidController.setPlaybackSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  void setSubtitles(List<Subtitle> subtitles, int index) {
    state = state.copyWith(subtitles: subtitles, selectedSubtitleIndex: index);
  }

  String getCurrentSubtitle() {
    final subtitle = state.subtitles.firstWhere(
      (subtitle) =>
          state.position >= subtitle.start && state.position <= subtitle.end,
      orElse: () =>
          Subtitle(start: Duration.zero, end: Duration.zero, text: ''),
    );
    return subtitle.text;
  }

  Future<void> setSubSelectedIndex(int index) async {
    if (!_live(_session) || index < 0 || index >= state.subtitlesRaw.length) {
      return;
    }
    final session = _session;
    final controller = vidController;
    final epoch = ++_subtitleEpoch;
    _subtitleSelection = index;
    final subUrl = state.subtitlesRaw[index].url;
    try {
      controller.setExternalSubtitle(MiruRequest.proxyUrl(subUrl).toString());
      state = state.copyWith(
        selectedSubtitleIndex: index,
        isShowSubtitle: false,
        subtitles: const [],
      );
      return;
    } catch (_) {
      // Non-FVP platforms use the software overlay.
    }
    try {
      final value = await SubtitleUtil.parseVttSubtitles(
        subUrl,
        headers: _streamHeaders,
      );
      if (!_active(session, controller) || _subtitleEpoch != epoch) return;
      state = state.copyWith(
        subtitles: value,
        selectedSubtitleIndex: index,
        isShowSubtitle: true,
      );
    } catch (error) {
      if (_active(session, controller) && _subtitleEpoch == epoch) {
        logger.warning('Subtitle loading failed (${error.runtimeType})');
        showSimpleToast('watch.player_subtitle_failed'.i18n);
      }
    }
  }

  void closeSubtitle() {
    _subtitleEpoch++;
    _subtitleSelection = null;
    if (!_live(_session)) return;
    // Stop the native (libass) render too: mdk keeps drawing the active
    // external subtitle track until it is disabled. No-op when the fvp
    // platform is not the engine (the Dart overlay needs no teardown).
    try {
      vidController.setSubtitleTracks(const []);
    } catch (_) {}
    state = state.copyWith(
      isShowSubtitle: false,
      subtitles: const [],
      currentSubtitle: '',
    );
  }

  void initSubtitle(List<ExtensionBangumiWatchSubtitle>? subtitles) {
    closeSubtitle();
    state = state.copyWith(
      subtitlesRaw: subtitles,
      isShowSubtitle: false,
      selectedSubtitleIndex: 0,
      subtitles: const [],
    );
  }

  void putVideoDefaultRatio(Size size) {
    defaultSize = size;
  }

  int get length => state.subtitles.length;
  List<Subtitle> get subtitles => state.subtitles;
  int get selectedIndex => state.selectedSubtitleIndex;

  void toggleSettings() {
    state = state.copyWith(showSettings: !state.showSettings);
  }

  /// Opens the settings surface on a specific pane — the landscape meta
  /// chips deep-link (mirror / resolution / subtitle / speed) instead of
  /// dumping the user on the first tab.
  void openSettings(int tab) {
    state = state.copyWith(settingsTab: tab, showSettings: true);
  }

  Future<void> switchMirror(
    String packageName,
    pb_extension.ExtensionMirror mirror,
  ) async {
    final session = _session;
    if (!_live(session)) return;
    final epoch = session.begin();
    try {
      final watch = await MiruCoreEndpoint.mirror(packageName, mirror.url);
      if (!_current(session, epoch)) return;
      if (watch is! pb_extension.ExtensionBangumiWatch) {
        throw StateError('Mirror did not return a video source');
      }
      final src = await resolvePlayback(watch.url, watch.headers);
      if (!_current(session, epoch)) return;
      await _installController(
        session: session,
        epoch: epoch,
        fresh: _getController(
          src.playbackUrl,
          watch.headers,
          watch.hasTorrent() ? watch.torrent : null,
          null,
        ),
        headers: watch.headers,
        qualityMap: src.qualityMap,
        mirrorResult: watch,
      );
    } catch (error) {
      _switchFailed(session, epoch, error);
    }
  }
}
