import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:video_player/video_player.dart';

import 'jellyfin_client.dart';

/// Lives on the existing Extensions page without changing the app shell.
class JellyfinEntry extends StatelessWidget {
  const JellyfinEntry({super.key});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: const ValueKey('open-jellyfin-library'),
    onPressed: () => Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(builder: (_) => const JellyfinLibraryPage()),
    ),
    icon: const Icon(Icons.video_library_outlined),
    label: const Text('Jellyfin'),
  );
}

class JellyfinLibraryPage extends StatefulWidget {
  const JellyfinLibraryPage({super.key, this.connect = JellyfinClient.connect});

  final JellyfinConnector connect;

  @override
  State<JellyfinLibraryPage> createState() => _JellyfinPageState();
}

class _JellyfinPageState extends State<JellyfinLibraryPage> {
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  JellyfinConnection? _connection;
  List<JellyfinItem> _items = const [];
  List<JellyfinItem> _parents = const [];
  int? _nextOffset;
  bool _busy = false;
  String? _errorKey;

  @override
  void dispose() {
    _connection?.close();
    _server.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _execute(Future<void> Function() task) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      await task();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorKey = error is JellyfinException && error.unauthorized
            ? 'jellyfin.denied'
            : 'jellyfin.failed';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _login() async {
    if (_busy) return;
    final server = parseJellyfinServer(_server.text);
    final username = _username.text.trim();
    if (server == null || username.isEmpty) {
      setState(() => _errorKey = 'jellyfin.invalid');
      return;
    }
    final password = _password.text;
    _password.clear();
    FocusManager.instance.primaryFocus?.unfocus();
    await _execute(() async {
      final session = await widget.connect(server, username, password);
      var keepSession = false;
      try {
        final libraries = await session.libraries();
        if (!mounted) return;
        setState(() {
          _connection = session;
          _items = libraries;
        });
        keepSession = true;
      } finally {
        if (!keepSession) session.close();
      }
    });
  }

  void _disconnect() {
    if (_busy) return;
    _connection?.close();
    _username.clear();
    _server.clear();
    setState(() {
      _connection = null;
      _parents = const [];
      _items = const [];
      _nextOffset = null;
      _errorKey = null;
    });
  }

  Future<void> _browse(List<JellyfinItem> path, {int? offset}) =>
      _execute(() async {
        final session = _connection;
        if (session == null) return;
        final page = path.isEmpty
            ? JellyfinPage(await session.libraries(), null)
            : await session.browse(path.last, offset: offset ?? 0);
        if (!mounted) return;
        setState(() {
          _parents = path;
          _items = offset == null
              ? page.items
              : {
                  ...{for (final item in _items) item.id: item},
                  ...{for (final item in page.items) item.id: item},
                }.values.toList();
          _nextOffset = page.nextOffset;
        });
      });

  Future<void> _open(JellyfinItem item) async {
    if (item.kind == JellyfinKind.library || item.kind == JellyfinKind.series) {
      await _browse([..._parents, item]);
      return;
    }
    await _execute(() async {
      final session = _connection;
      if (session == null) return;
      final stream = await session.play(item);
      try {
        if (!mounted) return;
        final route = MaterialPageRoute<void>(
          builder: (_) => _JellyfinPlayer(title: item.name, uri: stream.uri),
        );
        await Navigator.of(context).push(route);
        await route.completed;
      } finally {
        await stream.close();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        _parents.isEmpty ? 'Jellyfin' : _parents.last.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        if (_connection != null)
          TextButton(
            onPressed: _busy ? null : _disconnect,
            child: Text('jellyfin.disconnect'.i18n),
          ),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_errorKey case final key?)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: Semantics(liveRegion: true, child: Text(key.i18n)),
                ),
              if (_connection == null) ...[
                Text('jellyfin.help'.i18n),
                const SizedBox(height: 16),
                TextField(
                  controller: _server,
                  enabled: !_busy,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'jellyfin.server'.i18n,
                    hintText: 'https://media.example.com',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _username,
                  enabled: !_busy,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'jellyfin.username'.i18n,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => unawaited(_login()),
                  decoration: InputDecoration(
                    labelText: 'jellyfin.password'.i18n,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _login,
                  child: Text('jellyfin.connect'.i18n),
                ),
              ] else ...[
                if (_parents.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () =>
                              _browse(_parents.sublist(0, _parents.length - 1)),
                    icon: const Icon(Icons.arrow_back),
                    label: Text('jellyfin.up'.i18n),
                  ),
                if (_items.isEmpty && !_busy) Text('jellyfin.empty'.i18n),
                for (final item in _items)
                  ListTile(
                    key: ValueKey(item.id),
                    leading: Icon(
                      item.kind == JellyfinKind.library ||
                              item.kind == JellyfinKind.series
                          ? Icons.folder_outlined
                          : Icons.play_circle_outline,
                    ),
                    title: Text(item.name),
                    subtitle: item.overview.isEmpty
                        ? null
                        : Text(
                            item.overview,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                    enabled: !_busy,
                    onTap: () => _open(item),
                  ),
                if (_nextOffset case final offset?)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _browse(_parents, offset: offset),
                    child: Text('jellyfin.load_more'.i18n),
                  ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

/// Same video_player/FVP engine used by the app. It receives only a per-view
/// loopback URL; Jellyfin credentials never enter the media engine or URLs.
class _JellyfinPlayer extends StatefulWidget {
  const _JellyfinPlayer({required this.title, required this.uri});

  final String title;
  final Uri uri;

  @override
  State<_JellyfinPlayer> createState() => _JellyfinPlayerState();
}

class _JellyfinPlayerState extends State<_JellyfinPlayer>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.networkUrl(widget.uri);
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    if (mounted &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed)) {
      await _controller.play();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _controller.value.isInitialized) {
      unawaited(_controller.pause());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: SafeArea(
      child: FutureBuilder<void>(
        future: _ready,
        builder: (context, state) {
          if (state.hasError) {
            return Center(child: Text('jellyfin.playback_failed'.i18n));
          }
          if (state.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (value.hasError) {
                return Center(child: Text('jellyfin.playback_failed'.i18n));
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
                        (value.isPlaying ? 'jellyfin.pause' : 'jellyfin.play')
                            .i18n,
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () => unawaited(
                      value.isPlaying
                          ? _controller.pause()
                          : _controller.play(),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}
