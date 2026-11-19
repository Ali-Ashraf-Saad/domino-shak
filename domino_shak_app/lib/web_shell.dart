import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';

import 'bridge.dart';
import 'deep_link.dart';
import 'lan_service.dart';

const Color _woodDark = Color(0xFF36210F);
const Color _brass = Color(0xFFD9A93C);

class WebShell extends StatefulWidget {
  const WebShell({super.key, this.initialRoom});

  final String? initialRoom;

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> with WidgetsBindingObserver {
  final NativeBridge _bridge = NativeBridge();
  final LanService _lan = LanService();

  InAppWebViewController? _controller;
  StreamSubscription<String>? _linkSubscription;
  String? _pendingRoom;
  bool _loading = true;
  bool _hasLoadError = false;
  bool _backBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pendingRoom = widget.initialRoom;
    _linkSubscription = DeepLinkCoordinator.instance.rooms.listen(_onInviteRoom);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    unawaited(_lan.dispose());
    _controller = null;
    super.dispose();
  }

  void _onInviteRoom(String code) {
    final controller = _controller;
    if (controller == null) {
      _pendingRoom = code;
      return;
    }
    unawaited(_applyInvite(controller, code));
  }

  Future<void> _applyInvite(
    InAppWebViewController controller,
    String code,
  ) async {
    await controller.loadUrl(
      urlRequest: URLRequest(
        url: WebUri('$kGameOrigin/index.html?room=$code&auto=1'),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Nudge the page's own visibilitychange handler so it re-checks the
      // connection and re-requests the screen wake lock after backgrounding.
      _controller?.evaluateJavascript(
        source: "document.dispatchEvent(new Event('visibilitychange'));"
            "window.dispatchEvent(new Event('focus'));",
      );
    }
  }

  Future<void> _registerBridgeHandlers(InAppWebViewController controller) async {
    controller.addJavaScriptHandler(
      handlerName: 'shareRoom',
      callback: (args) {
        if (args.isEmpty || !_bridge.isTokenValid(args[0])) return false;
        return _bridge.shareRoom(args.length > 1 ? args[1] : null);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'copyCode',
      callback: (args) {
        if (args.isEmpty || !_bridge.isTokenValid(args[0])) return false;
        return _bridge.copyRoomCode(args.length > 1 ? args[1] : null);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'requestMic',
      callback: (args) {
        // This handler is only meaningful for an explicit microphone gesture.
        if (args.isEmpty || !_bridge.isTokenValid(args[0])) return false;
        return _bridge.requestMicrophone();
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'toast',
      callback: (args) {
        if (args.isEmpty || !_bridge.isTokenValid(args[0])) return false;
        if (args.length > 1 && args[1] is String) {
          _bridge.showToast(args[1] as String);
        }
        return true;
      },
    );

    // ---- Offline LAN signalling (local sockets only) ----
    _lan.onMessage = (from, data) {
      final detail = jsonEncode({'from': from, 'data': data});
      controller.evaluateJavascript(
        source: "window.dispatchEvent(new CustomEvent('dsLanMessage',{detail:$detail}));",
      );
    };
    _lan.onPeerLeft = (from) {
      final detail = jsonEncode({'from': from});
      controller.evaluateJavascript(
        source: "window.dispatchEvent(new CustomEvent('dsLanPeerLeft',{detail:$detail}));",
      );
    };
    _lan.onError = (message) {
      debugPrint('LAN: $message');
    };

    bool validToken(List<dynamic> args) =>
        args.isNotEmpty && _bridge.isTokenValid(args[0]);
    final idPattern = RegExp(r'^[A-Za-z0-9_-]{1,40}$');
    final hostPattern = RegExp(r'^[A-Za-z0-9.]{3,60}$');

    controller.addJavaScriptHandler(
      handlerName: 'lanHost',
      callback: (args) async {
        if (!validToken(args)) return 0;
        final port = args.length > 1 && args[1] is int
            ? args[1] as int
            : LanService.defaultPort;
        if (port < 1 || port > 65535) return 0;
        try {
          return await _lan.startHost(port);
        } catch (_) {
          return 0;
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'lanConnect',
      callback: (args) async {
        if (!validToken(args) || args.length < 4) return false;
        final host = args[1];
        final port = args[2];
        final id = args[3];
        if (host is! String || !hostPattern.hasMatch(host)) return false;
        if (port is! int || port < 1 || port > 65535) return false;
        if (id is! String || !idPattern.hasMatch(id)) return false;
        return _lan.connect(host, port, id);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'lanSend',
      callback: (args) {
        if (!validToken(args) || args.length < 3) return false;
        final to = args[1];
        final raw = args[2];
        if (to is! String || !idPattern.hasMatch(to)) return false;
        if (raw is! String) return false;
        try {
          final decoded = jsonDecode(raw);
          if (decoded is! Map<String, dynamic>) return false;
          return _lan.send(to, decoded);
        } catch (_) {
          return false;
        }
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'lanClose',
      callback: (args) {
        if (!validToken(args)) return false;
        return _lan.closeClient().then((_) => true);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'lanStopHost',
      callback: (args) {
        if (!validToken(args)) return false;
        return _lan.stopHost().then((_) => true);
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'lanGetIp',
      callback: (args) async {
        if (!validToken(args)) return '';
        return await _lan.localIp() ?? '';
      },
    );
  }

  Future<NavigationActionPolicy?> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.CANCEL;

    if (uri.scheme == 'http' &&
        uri.host == 'localhost' &&
        uri.port == 8080) {
      return NavigationActionPolicy.ALLOW;
    }

    // Never let the WebView navigate to file://, content://, javascript:,
    // data: or any other scheme. Known external schemes are handed to Android.
    if (uri.scheme == 'http' ||
        uri.scheme == 'https' ||
        uri.scheme == 'whatsapp' ||
        uri.scheme == 'mailto' ||
        uri.scheme == 'tel') {
      await _bridge.openExternal(uri);
    }
    return NavigationActionPolicy.CANCEL;
  }

  Future<void> _handleAndroidBack() async {
    if (_backBusy) return;
    _backBusy = true;
    try {
      final raw = await _controller?.evaluateJavascript(
        source: 'window.__dominoBack ? window.__dominoBack() : "none"',
      );
      final action = raw?.toString().replaceAll('"', '') ?? 'none';

      if (action == 'ask' ||
          action == 'overlay' ||
          action == 'chat' ||
          action == 'lobby') {
        return;
      }

      if (action == 'home') {
        await SystemNavigator.pop();
        return;
      }

      if (action == 'table') {
        if (!mounted) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('خروج من الطاولة؟'),
            content: const Text(
              'أنت في طاولة دلوقتي. لو خرجت، الاتصال هيتقطع وهترجع للرئيسية.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('استمرار'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('خروج'),
              ),
            ],
          ),
        );
        if (leave != true) return;

        // Let the game send its own leave/host-left signal first, then land on
        // the home screen. A second back press from home exits the app.
        await _controller?.evaluateJavascript(
          source: 'window.__dominoLeave && window.__dominoLeave()',
        );
        await Future<void>.delayed(const Duration(milliseconds: 900));
        return;
      }

      // Page did not provide an answer (still loading, or unexpected state).
      if (!mounted) return;
      final exit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('خروج من دومينو شك؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('خروج'),
            ),
          ],
        ),
      );
      if (exit == true) await SystemNavigator.pop();
    } finally {
      _backBusy = false;
    }
  }

  Future<JsAlertResponse?> _showJsAlert(
    InAppWebViewController controller,
    JsAlertRequest request,
  ) async {
    final dialogContext = appNavigatorKey.currentContext;
    if (dialogContext == null) return null;
    await showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('دومينو شك'),
        content: Text(request.message ?? ''),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
    return JsAlertResponse(
      handledByClient: true,
      message: request.message ?? '',
      confirmButtonTitle: 'موافق',
    );
  }

  Future<JsConfirmResponse?> _showJsConfirm(
    InAppWebViewController controller,
    JsConfirmRequest request,
  ) async {
    final dialogContext = appNavigatorKey.currentContext;
    if (dialogContext == null) return null;
    final result = await showDialog<bool>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('دومينو شك'),
        content: Text(request.message ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
    return JsConfirmResponse(
      handledByClient: true,
      message: request.message ?? '',
      action: result == true
          ? JsConfirmResponseAction.CONFIRM
          : JsConfirmResponseAction.CANCEL,
      confirmButtonTitle: 'موافق',
      cancelButtonTitle: 'إلغاء',
    );
  }

  Future<JsPromptResponse?> _showJsPrompt(
    InAppWebViewController controller,
    JsPromptRequest request,
  ) async {
    final dialogContext = appNavigatorKey.currentContext;
    if (dialogContext == null) return null;
    final textController = TextEditingController(text: request.defaultValue ?? '');
    final value = await showDialog<String>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('دومينو شك'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: InputDecoration(labelText: request.message ?? ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(textController.text),
            child: const Text('موافق'),
          ),
        ],
      ),
    );
    textController.dispose();

    if (value == null) {
      return JsPromptResponse(
        handledByClient: true,
        message: request.message ?? '',
        action: JsPromptResponseAction.CANCEL,
        confirmButtonTitle: 'موافق',
        cancelButtonTitle: 'إلغاء',
      );
    }
    return JsPromptResponse(
      handledByClient: true,
      message: request.message ?? '',
      action: JsPromptResponseAction.CONFIRM,
      value: value,
      defaultValue: request.defaultValue ?? '',
      confirmButtonTitle: 'موافق',
      cancelButtonTitle: 'إلغاء',
    );
  }

  Future<PermissionResponse?> _handlePermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    final PermissionResponse denied = PermissionResponse(
      resources: [],
      action: PermissionResponseAction.DENY,
    );

    final origin = request.origin;
    final trustedOrigin = origin.scheme == 'http' &&
        origin.host == 'localhost' &&
        origin.port == 8080;
    final wantsMicrophone =
        request.resources.contains(PermissionResourceType.MICROPHONE);
    final wantsAnythingElse =
        request.resources.any((r) => r != PermissionResourceType.MICROPHONE);

    if (!trustedOrigin || !wantsMicrophone || wantsAnythingElse) {
      return denied;
    }

    // The Android runtime permission is requested by the mic button bridge
    // handler. If it is not granted yet, do not let the WebView prompt.
    final granted = await Permission.microphone.isGranted;
    if (!granted) return denied;

    return PermissionResponse(
      resources: [PermissionResourceType.MICROPHONE],
      action: PermissionResponseAction.GRANT,
    );
  }

  void _retry() {
    setState(() {
      _hasLoadError = false;
      _loading = true;
    });
    _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri('$kGameOrigin/index.html')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleAndroidBack();
      },
      child: Scaffold(
        backgroundColor: _woodDark,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(
                    _pendingRoom == null
                        ? '$kGameOrigin/index.html'
                        : '$kGameOrigin/index.html?room=$_pendingRoom&auto=1',
                  ),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  javaScriptCanOpenWindowsAutomatically: false,
                  supportMultipleWindows: false,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  cacheEnabled: true,
                  allowFileAccess: false,
                  allowContentAccess: false,
                  allowFileAccessFromFileURLs: false,
                  allowUniversalAccessFromFileURLs: false,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                  thirdPartyCookiesEnabled: false,
                  geolocationEnabled: false,
                  safeBrowsingEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  allowBackgroundAudioPlaying: false,
                  supportZoom: false,
                  builtInZoomControls: false,
                  displayZoomControls: false,
                  useWideViewPort: true,
                  loadWithOverviewMode: false,
                  useShouldOverrideUrlLoading: true,
                  useHybridComposition: true,
                  transparentBackground: false,
                  verticalScrollBarEnabled: false,
                  horizontalScrollBarEnabled: false,
                  overScrollMode: OverScrollMode.NEVER,
                  disableDefaultErrorPage: true,
                  isInspectable: kDebugMode,
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: buildMobileShim(_bridge.token),
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                    forMainFrameOnly: true,
                  ),
                ]),
                onWebViewCreated: (controller) async {
                  _controller = controller;
                  await _registerBridgeHandlers(controller);
                },
                onLoadStop: (controller, url) {
                  if (!mounted) return;
                  if (_loading || _hasLoadError) {
                    setState(() {
                      _loading = false;
                      _hasLoadError = false;
                    });
                  }
                },
                onReceivedError: (controller, request, error) {
                  if (!mounted) return;
                  if (request.isForMainFrame == true) {
                    setState(() {
                      _loading = false;
                      _hasLoadError = true;
                    });
                  }
                },
                onReceivedHttpError: (controller, request, response) {
                  if (!mounted) return;
                  if (request.isForMainFrame == true) {
                    setState(() {
                      _loading = false;
                      _hasLoadError = true;
                    });
                  }
                },
                shouldOverrideUrlLoading: _handleNavigation,
                onPermissionRequest: _handlePermissionRequest,
                onJsAlert: _showJsAlert,
                onJsConfirm: _showJsConfirm,
                onJsPrompt: _showJsPrompt,
                onConsoleMessage: (controller, message) {
                  if (kDebugMode) {
                    debugPrint('[web] ${message.message}');
                  }
                },
              ),
              if (_loading) _buildLoading(),
              if (_hasLoadError) _buildError(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return ColoredBox(
      color: _woodDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 42,
              height: 42,
              child: CircularProgressIndicator(
                color: _brass,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'دومينو شك',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _brass,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return ColoredBox(
      color: _woodDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _brass, size: 52),
              const SizedBox(height: 16),
              const Text(
                'مش قادر أفتح اللعبة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اقفل التطبيق وافتحه تاني. لو المشكلة فضلت، جرّب تحديث التطبيق.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _retry,
                style: FilledButton.styleFrom(backgroundColor: _brass),
                child: const Text('حاول تاني'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
