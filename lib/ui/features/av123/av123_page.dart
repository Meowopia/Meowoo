import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:miru_alpha/data/sources/av123_site.dart';
import 'package:miru_alpha/utils/core/i18n.dart';
import 'package:miru_alpha/utils/store/nsfw_session.dart';
import 'package:webview_all/webview_all.dart';

class Av123Entry extends StatelessWidget {
  const Av123Entry({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: nsfwSession.changes,
    builder: (context, _) {
      if (!nsfwSession.enabled) return const SizedBox.shrink();
      return OutlinedButton.icon(
        key: const ValueKey('open-123av'),
        onPressed: () {
          if (!nsfwSession.enabled) return;
          Navigator.of(context, rootNavigator: true).push<void>(
            MaterialPageRoute<void>(builder: (_) => const _Av123Page()),
          );
        },
        icon: const Icon(Icons.language),
        label: const Text('123AV'),
      );
    },
  );
}

class _Av123Page extends StatefulWidget {
  const _Av123Page();

  @override
  State<_Av123Page> createState() => _Av123PageState();
}

class _Av123PageState extends State<_Av123Page> {
  late final Av123Visit _visit;
  late final StreamSubscription<bool> _privacy;
  WebViewSession? _session;
  WebViewController? _visible;
  String? _errorKey;
  bool _loading = true;
  bool _opening = false;
  bool _hasShownPage = false;

  bool get _active => mounted && _visit.active;
  bool _owns(WebViewSession session) => _active && identical(session, _session);

  @override
  void initState() {
    super.initState();
    _visit = Av123Visit(nsfwSession);
    _privacy = nsfwSession.changes.listen((enabled) {
      if (enabled || !mounted) return;
      _release();
      setState(() {});
    });
    if (_visit.active) unawaited(_open());
  }

  Future<void> _open() async {
    if (!_active || _opening) return;
    _opening = true;
    setState(() {
      _errorKey = null;
      _loading = true;
    });
    try {
      final caps = await WebViewSession.getCapabilities();
      if (!_active) return;
      if (!caps.canClose ||
          caps.incognitoSupport != WebViewIncognitoSupport.nativeStore ||
          !caps.supports(WebViewSessionMode.isolatedIncognito)) {
        _error('av123.no_private_browser');
        return;
      }
      final session = await WebViewSession.create(
        mode: WebViewSessionMode.isolatedIncognito,
        mediaPlaybackPolicy: WebViewMediaPlaybackPolicy.requireUserGesture,
        onPermissionRequest: (request) => unawaited(_quiet(request.deny)),
      );
      if (session == null) {
        _error('av123.unavailable');
        return;
      }
      if (!_active) {
        await _quiet(session.close);
        return;
      }
      _session = session;
      final controller = session.controller;
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) =>
              _owns(session) && _visit.allowNavigation(request.url)
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageStarted: (url) {
            if (!_owns(session)) return;
            if (!_visit.allowNavigation(url)) {
              _abortSite();
              return;
            }
            setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (!_owns(session)) return;
            if (!_visit.allowNavigation(url)) {
              _abortSite();
              return;
            }
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (_owns(session) && error.isForMainFrame == true) _abortSite();
          },
          onHttpAuthRequest: (request) => request.onCancel(),
          onSslAuthError: (error) => unawaited(_quiet(error.cancel)),
        ),
      );
      if (!_owns(session)) return;
      await controller.setPopupPolicy(WebViewPopupWindowPolicy.deny);
      if (!_owns(session)) return;
      await controller.setDownloadDelegate(
        WebViewDownloadDelegate(
          onDownloadRequest: (_) => const WebViewDownloadDecision.cancel(),
        ),
      );
      if (!_owns(session)) return;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      if (!_owns(session)) return;
      await controller.loadRequest(av123Home);
      if (!_owns(session)) return;
      _hasShownPage = true;
      setState(() => _visible = controller);
    } catch (_) {
      if (_active) _abortSite();
    } finally {
      _opening = false;
    }
  }

  void _abortSite() {
    _release();
    _error('av123.unavailable');
  }

  void _error(String key) {
    if (_active) {
      setState(() {
        _loading = false;
        _errorKey = key;
      });
    }
  }

  void _release() {
    final session = _session;
    _session = null;
    _visible = null;
    if (session == null) return;
    final controller = session.controller;
    unawaited(_quiet(controller.stopLoading));
    unawaited(_quiet(controller.pauseMedia));
    if (_hasShownPage) {
      // Remove the native view before closing the cookie/website-data store.
      _hasShownPage = false;
      final binding = WidgetsBinding.instance;
      binding.addPostFrameCallback((_) => unawaited(_quiet(session.close)));
      binding.ensureVisualUpdate();
    } else {
      unawaited(_quiet(session.close));
    }
  }

  Future<void> _backWithinSite() async {
    final session = _session;
    if (session == null || !_owns(session)) return;
    final controller = session.controller;
    try {
      if (await controller.canGoBack() && _owns(session)) {
        await controller.goBack();
      }
    } catch (_) {
      // A revoked session may close while querying its in-memory history.
    }
  }

  static Future<void> _quiet(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Browser callbacks may include private URLs. Do not copy them to logs.
    }
  }

  @override
  void dispose() {
    unawaited(_privacy.cancel());
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _active ? _visible : null;
    final message = _active
        ? _errorKey
        : 'settings.labels.allow_nsfw.unavailable';
    return Scaffold(
      appBar: AppBar(
        title: const Text('123AV · 123av.com'),
        actions: [
          if (controller != null)
            IconButton(
              tooltip: 'av123.site_back'.i18n,
              onPressed: _backWithinSite,
              icon: const Icon(Icons.arrow_back),
            ),
        ],
      ),
      body: SafeArea(
        child: message != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(message.i18n, textAlign: TextAlign.center),
                      if (_active && message == 'av123.unavailable')
                        TextButton(
                          onPressed: _open,
                          child: Text('av123.retry'.i18n),
                        ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  if (controller != null)
                    WebViewWidget(
                      key: ObjectKey(controller),
                      controller: controller,
                    ),
                  if (_loading)
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
      ),
    );
  }
}
