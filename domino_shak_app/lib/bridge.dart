import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Trusted origin served by InAppLocalhostServer.
const String kGameOrigin = 'http://localhost:8080';

/// Public fallback host. Never share the local WebView origin.
const String kPublicGameOrigin = 'https://liardominoes.gt.tc';

/// Stable invitation URL for a room code.
String inviteUrlFor(String roomCode) => '$kPublicGameOrigin/?room=$roomCode';

/// Global navigator key so native dialogs can be shown from WebView callbacks.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Small, explicit bridge between the bundled web app and Android.
///
/// Only three capabilities are exposed to JavaScript:
/// - shareRoom(code)
/// - copyCode(code)
/// - requestMic()
/// plus a native toast helper.
///
/// Every call must include a per-launch random token. The WebView only ever
/// loads trusted local content, and navigation away from that content is
/// blocked, so this token is defence in depth rather than the only barrier.
class NativeBridge {
  NativeBridge() : token = _newToken();

  static const MethodChannel _native =
      MethodChannel('com.dominoshak.domino_shak/native');

  static const int _maxCodeLength = 8;
  static final RegExp _codePattern = RegExp(r'^[A-Z0-9]{4,8}$');

  /// Random token injected into the page at document start.
  final String token;

  Future<bool>? _pendingMicRequest;

  static String _newToken() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  bool isTokenValid(Object? value) => value is String && value == token;

  bool isValidRoomCode(Object? value) {
    if (value is! String) return false;
    if (value.length > _maxCodeLength) return false;
    return _codePattern.hasMatch(value);
  }

  Future<void> showToast(String message) async {
    final text = message.trim();
    if (text.isEmpty || text.length > 200) return;
    try {
      await _native.invokeMethod<void>('toast', text);
    } catch (_) {
      // A toast is a convenience; never let it break gameplay.
    }
  }

  Future<bool> copyRoomCode(Object? code) async {
    if (!isValidRoomCode(code)) return false;
    final roomCode = code as String;
    await Clipboard.setData(ClipboardData(text: inviteUrlFor(roomCode)));
    await showToast('تم نسخ لينك الطاولة');
    return true;
  }

  Future<bool> shareRoom(Object? code) async {
    if (!isValidRoomCode(code)) return false;
    final roomCode = code as String;
    final link = inviteUrlFor(roomCode);
    final text = 'تعالى نلعب دومينو شك! 🁢\n'
        '$link\n\n'
        'لو عندك التطبيق هيفتح الطاولة مباشرة. لو لأ، اللينك هيفتح نسخة '
        'المتصفح. كود الطاولة: $roomCode';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          subject: 'دومينو شك — طاولة $roomCode',
          title: 'دعوة للعب دومينو شك',
        ),
      );
      return true;
    } catch (_) {
      await showToast('مش قادر أفتح قائمة المشاركة');
      return false;
    }
  }

  /// Opens links outside the app. Only http(s), mailto, tel and whatsapp
  /// schemes are accepted.
  Future<bool> openExternal(Uri uri) async {
    const allowed = {'http', 'https', 'mailto', 'tel', 'whatsapp'};
    if (!allowed.contains(uri.scheme)) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await showToast('مش لاقي تطبيق يفتح اللينك ده');
      return false;
    }
  }

  /// Requests microphone access only after an explicit user action.
  ///
  /// Shows a short Arabic explanation before the Android permission dialog.
  /// Concurrent requests share one future so the dialog cannot stack.
  Future<bool> requestMicrophone() {
    return _pendingMicRequest ??= _requestMicrophoneInternal().whenComplete(() {
      _pendingMicRequest = null;
    });
  }

  Future<bool> _requestMicrophoneInternal() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final context = appNavigatorKey.currentContext;
    if (context == null || !context.mounted) return false;

    if (status.isPermanentlyDenied || status.isRestricted) {
      await _showSettingsDialog(context);
      return false;
    }

    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تسجيل رسالة صوتية'),
        content: const Text(
          'عشان تبعت رسالة صوتية في الدردشة، التطبيق محتاج إذن الميكروفون. '
          'التسجيل بيبدأ بس لما تدوس زر الميكروفون، وبيتبعت للاعبين في '
          'الطاولة بس. تقدر تلغي وتسجّل بعدين.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('مش دلوقتي'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('سماح'),
          ),
        ],
      ),
    );
    if (proceed != true) return false;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if ((status.isPermanentlyDenied || status.isRestricted) &&
        appNavigatorKey.currentContext != null) {
      final current = appNavigatorKey.currentContext;
      if (current != null && current.mounted) {
        await _showSettingsDialog(current);
      }
    }
    return false;
  }

  Future<void> _showSettingsDialog(BuildContext context) async {
    final open = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('الميكروفون مقفول'),
        content: const Text(
          'إذن الميكروفون مرفوض. لتسجيل رسائل صوتية، افتح إعدادات '
          'التطبيق وفعّل «الميكروفون». باقي اللعبة شغالة عادي من غيره.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('تمام'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('افتح الإعدادات'),
          ),
        ],
      ),
    );
    if (open == true) {
      await openAppSettings();
    }
  }
}

/// Injected at document start in the main frame only.
///
/// It does not change game logic. It adds a thin Android integration layer:
/// native sharing/copying, microphone gating, and Android back handling.
/// It also fixes the two lobby button labels so they describe what the
/// buttons now do on Android.
String buildMobileShim(String token) {
  return _shimTemplate.replaceFirst('__BRIDGE_TOKEN__', token);
}

const String _shimTemplate = r'''
(function () {
  'use strict';
  var TOKEN = '__BRIDGE_TOKEN__';

  function bridge(name, args) {
    try {
      if (!window.flutter_inappwebview ||
          !window.flutter_inappwebview.callHandler) {
        return Promise.resolve(null);
      }
      var all = [TOKEN].concat(args || []);
      return window.flutter_inappwebview.callHandler.apply(
          window.flutter_inappwebview, [name].concat(all));
    } catch (e) {
      return Promise.resolve(null);
    }
  }

  function roomCode() {
    var el = document.querySelector('#lobCode');
    var text = el ? String(el.textContent || '').trim() : '';
    return /^[A-Z0-9]{4,8}$/.test(text) ? text : '';
  }

  function isVisible(el) {
    return !!el && !el.hidden && el.getClientRects().length > 0;
  }

  document.addEventListener('DOMContentLoaded', function () {
    var copy = document.querySelector('#copyBtn');
    if (copy) copy.textContent = 'انسخ اللينك';
    var share = document.querySelector('#waBtn');
    if (share) share.textContent = 'مشاركة';

    // Native sharing copies/opens the public invitation URL. Keep the lobby
    // hint aligned when the game re-renders it.
    var hint = document.querySelector('#lobHint');
    if (hint) {
      var fixHint = function () {
        // LAN rooms show local connection details instead of a public link.
        if (window.__dsLanMode === true) return;
        var text = hint.textContent || '';
        if (text.indexOf('ابعت اللينك') === -1) {
          hint.textContent =
              'ابعت اللينك لصحابك — اللعبة هتبدأ أول ما الطاولة تكمل.';
        }
      };
      new MutationObserver(fixHint).observe(hint, {
        childList: true,
        characterData: true,
        subtree: true
      });
      fixHint();
    }
  });

  // Capture phase: stop the web handlers before they run.
  document.addEventListener('click', function (event) {
    var target = event.target;
    if (!target || !target.closest) return;

    var copyBtn = target.closest('#copyBtn');
    if (copyBtn) {
      var code = roomCode();
      if (!code) return;
      event.preventDefault();
      event.stopPropagation();
      if (event.stopImmediatePropagation) event.stopImmediatePropagation();
      bridge('copyCode', [code]);
      return;
    }

    var shareBtn = target.closest('#waBtn');
    if (shareBtn) {
      var shareCode = roomCode();
      if (!shareCode) return;
      event.preventDefault();
      event.stopPropagation();
      if (event.stopImmediatePropagation) event.stopImmediatePropagation();
      bridge('shareRoom', [shareCode]);
      return;
    }

    var micBtn = target.closest('#micBtn');
    if (micBtn && window.__dsMicReady !== true) {
      event.preventDefault();
      event.stopPropagation();
      if (event.stopImmediatePropagation) event.stopImmediatePropagation();
      bridge('requestMic', []).then(function (granted) {
        if (granted === true) {
          window.__dsMicReady = true;
          var button = document.querySelector('#micBtn');
          if (button) button.click();
        } else {
          bridge('toast', ['لازم تسمح بالميكروفون عشان تبعت رسالة صوتية']);
        }
      });
    }
  }, true);

  // Android back button: close the topmost web surface first.
  window.__dominoBack = function () {
    var ask = document.querySelector('#ask');
    if (ask && !ask.hidden) {
      var no = document.querySelector('#askNo');
      if (no) { no.click(); return 'ask'; }
    }

    var overlay = document.querySelector('#overlay');
    if (overlay && overlay.classList.contains('on')) {
      var close = document.querySelector('#ovClose');
      if (close) { close.click(); return 'overlay'; }
      overlay.classList.remove('on');
      overlay.innerHTML = '';
      return 'overlay';
    }

    var chat = document.querySelector('#chat');
    if (chat && !chat.hidden) {
      var chatX = document.querySelector('#chatX');
      if (chatX) { chatX.click(); return 'chat'; }
    }

    var lobby = document.querySelector('#lobby');
    if (lobby && lobby.classList.contains('on')) {
      var lobBack = document.querySelector('#lobBack');
      if (lobBack) { lobBack.click(); return 'lobby'; }
    }

    var screen = document.querySelector('.screen.on');
    if (!screen) return 'none';
    return screen.id === 'home' ? 'home' : 'table';
  };

  // Graceful leave: use the game's own settings -> leave -> confirm flow so
  // the host/client sends the proper leave signal before the app closes.
  window.__dominoLeave = function () {
    var settings = document.querySelector('#setBtn');
    if (!settings) {
      location.href = location.href.split(/[?#]/)[0];
      return true;
    }
    settings.click();
    var attempts = 0;
    var step = function () {
      var leave = document.querySelector('#leaveBtn');
      if (leave) {
        leave.click();
        var yes = document.querySelector('#askYes');
        if (yes) { yes.click(); return; }
      }
      attempts += 1;
      if (attempts < 6) {
        setTimeout(step, 60);
      } else {
        location.href = location.href.split(/[?#]/)[0];
      }
    };
    setTimeout(step, 60);
    return true;
  };

  // Offline LAN transport. Available only inside the Android WebView; the
  // hosted browser build leaves window.dsLan undefined and disables LAN mode.
  window.dsLan = {
    available: true,
    host: function (port) { return bridge('lanHost', [port]); },
    connect: function (ip, port, id) { return bridge('lanConnect', [ip, port, id]); },
    send: function (to, dataJson) { return bridge('lanSend', [to, dataJson]); },
    close: function () { return bridge('lanClose', []); },
    stopHost: function () { return bridge('lanStopHost', []); },
    ip: function () { return bridge('lanGetIp', []); }
  };
})();
''';
