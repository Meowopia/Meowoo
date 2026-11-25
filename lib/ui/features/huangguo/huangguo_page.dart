import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:miru_alpha/data/sources/huangguo.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:miru_alpha/utils/store/nsfw_session.dart';
import 'package:video_player/video_player.dart';

class HuangguoEntry extends StatelessWidget {
  const HuangguoEntry({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: nsfwSession.changes,
    builder: (context, _) {
      if (!nsfwSession.enabled) return const SizedBox.shrink();
      return OutlinedButton.icon(
        key: const ValueKey('open-huangguo'),
        onPressed: () {
          if (!nsfwSession.enabled) return;
          Navigator.of(context, rootNavigator: true).push<void>(
            MaterialPageRoute<void>(builder: (_) => const HuangguoPage()),
          );
        },
        icon: const Icon(Icons.video_library_outlined),
        label: Text('huangguo.name'.i18n),
      );
    },
  );
}

/// App-owned source stays separate from normal history, favourites, downloads
/// and Core extension logs. It holds no credentials or catalogue on disk.
class HuangguoPage extends StatefulWidget {
  const HuangguoPage({super.key, this.createSession = HuangguoSession.new});

  final HuangguoSession Function() createSession;

  @override
  State<HuangguoPage> createState() => _HuangguoPageState();
}

class _HuangguoPageState extends State<HuangguoPage> {
  HuangguoSession? _session;
  StreamSubscription<bool>? _privacy;
  final _list = <HuangguoTitle>[];
  final _seen = <int>{};
  HuangguoDetail? _detail;
  Uri? _media;
  Future<void> Function()? _retry;
  int? _page = 1;
  bool _busy = false;
  bool _failed = false;
  bool get _active => mounted && (_session?.active ?? false);

  @override
  void initState() {
    super.initState();
    if (!nsfwSession.enabled) return;
    _session = widget.createSession();
    _privacy = nsfwSession.changes.listen((enabled) {
      if (enabled || !mounted) return;
      _session?.close();
      setState(() {
        _session = null;
        _list.clear();
        _seen.clear();
        _detail = null;
        _media = null;
        _retry = null;
      });
    });
    unawaited(_loadMore());
  }

  @override
  void dispose() {
    unawaited(_privacy?.cancel());
    _session?.close();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_active || _busy) return;
    setState(() {
      _busy = true;
      _failed = false;
      _retry = () => _run(action);
    });
    try {
      await action();
    } catch (_) {
      if (_active) setState(() => _failed = true);
    } finally {
      if (_active) {
        setState(() {
          _busy = false;
          if (!_failed) _retry = null;
        });
      }
    }
  }

  Future<void> _loadMore() => _run(() async {
    final page = _page;
    if (page == null) return;
    final response = await _session!.browse(page: page);
    if (!_active) return;
    setState(() {
      _list.addAll(response.titles.where((entry) => _seen.add(entry.id)));
      _page = response.nextPage;
    });
  });

  Future<void> _open(HuangguoTitle title) => _run(() async {
    final result = await _session!.detail(title);
    if (_active) setState(() => _detail = result);
  });

  Future<void> _play(HuangguoEpisode episode) => _run(() async {
    final stream = await _session!.playback(episode);
    if (_active) setState(() => _media = stream);
  });

  void _backInsideSource() {
    if (_busy) return;
    setState(() {
      if (_media != null) {
        _media = null;
      } else {
        _detail = null;
      }
      _failed = false;
      _retry = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final stream = _media;
    final inside = _active && (detail != null || stream != null);
    return PopScope<void>(
      canPop: !inside,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && inside) _backInsideSource();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _active
                ? detail?.title ?? 'huangguo.name'.i18n
                : 'settings.labels.allow_nsfw.unavailable'.i18n,
          ),
          leading: inside ? BackButton(onPressed: _backInsideSource) : null,
        ),
        body: SafeArea(
          child: !_active
              ? Center(
                  child: Text('settings.labels.allow_nsfw.unavailable'.i18n),
                )
              : stream != null
              ? _HuangguoPlayer(uri: stream)
              : _buildCatalogue(detail),
        ),
      ),
    );
  }

  Widget _buildCatalogue(HuangguoDetail? detail) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (detail == null)
        for (final entry in _list)
          ListTile(
            title: Text(entry.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy ? null : () => _open(entry),
          )
      else
        for (final episode in detail.episodes)
          ListTile(
            title: Text(
              episode.title.isNotEmpty
                  ? episode.title
                  : '${'huangguo.episode'.i18n} ${episode.number}',
            ),
            trailing: const Icon(Icons.play_arrow),
            onTap: _busy ? null : () => _play(episode),
          ),
      if (_busy) const Center(child: CircularProgressIndicator()),
      if (_failed)
        Center(
          child: Column(
            children: [
              Text('huangguo.unavailable'.i18n),
              TextButton(onPressed: _retry, child: Text('huangguo.retry'.i18n)),
            ],
          ),
        )
      else if (!_busy && detail == null && _page != null)
        Center(
          child: OutlinedButton(
            onPressed: _loadMore,
            child: Text('huangguo.more'.i18n),
          ),
        )
      else if (!_busy &&
          ((detail == null && _list.isEmpty) ||
              (detail != null && detail.episodes.isEmpty)))
        Center(child: Text('huangguo.empty'.i18n)),
    ],
  );
}

class _HuangguoPlayer extends StatefulWidget {
  const _HuangguoPlayer({required this.uri});
  final Uri uri;

  @override
  State<_HuangguoPlayer> createState() => _HuangguoPlayerState();
}

class _HuangguoPlayerState extends State<_HuangguoPlayer>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  late final Future<bool> _ready;
  late final StreamSubscription<bool> _privacy;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(widget.uri);
    _privacy = nsfwSession.changes.listen((enabled) {
      if (!enabled) _close();
    });
    _ready = _initialize();
  }

  Future<bool> _initialize() async {
    if (!nsfwSession.enabled) return false;
    try {
      await _controller.initialize();
      // Playback is started by the user, not by a late initialization result.
      return mounted && !_closed && nsfwSession.enabled;
    } catch (_) {
      return false;
    }
  }

  Future<void> _quiet(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Do not emit native errors containing the signed URL.
    }
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    unawaited(_quiet(_controller.dispose));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        !_closed &&
        _controller.value.isInitialized) {
      unawaited(_quiet(_controller.pause));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_privacy.cancel());
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _ready,
    builder: (context, state) {
      if (state.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (state.data != true || _closed || !nsfwSession.enabled) {
        return Center(child: Text('huangguo.playback_failed'.i18n));
      }
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller,
        builder: (context, value, _) {
          if (value.hasError) {
            return Center(child: Text('huangguo.playback_failed'.i18n));
          }
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
              if (value.duration > Duration.zero)
                VideoProgressIndicator(_controller, allowScrubbing: true),
              IconButton(
                tooltip:
                    (value.isPlaying ? 'huangguo.pause' : 'huangguo.play').i18n,
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (_closed || !nsfwSession.enabled) return;
                  unawaited(
                    _quiet(
                      value.isPlaying ? _controller.pause : _controller.play,
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    },
  );
}
