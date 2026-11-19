import 'dart:async';

import 'package:flutter/services.dart';

/// Converts an invitation URL from liardominoes.gt.tc into a safe room code.
///
/// Returns null for any URL that is not the configured HTTPS host or does not
/// carry a valid 4-8 character uppercase alphanumeric room code. This prevents
/// an invitation from accidentally creating a new table.
String? parseInviteRoomCode(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return null;
  if (uri.scheme.toLowerCase() != 'https') return null;
  if (uri.host.toLowerCase() != 'liardominoes.gt.tc') return null;

  final rawCode = uri.queryParameters['room'];
  if (rawCode == null) return null;
  final code = rawCode.toUpperCase();
  if (!RegExp(r'^[A-Z0-9]{4,8}$').hasMatch(code)) return null;
  return code;
}

/// Receives App Link / deep-link URLs from Android without adding a package.
class DeepLinkCoordinator {
  DeepLinkCoordinator._();

  static final DeepLinkCoordinator instance = DeepLinkCoordinator._();

  static const MethodChannel _channel =
      MethodChannel('com.dominoshak.domino_shak/deeplink');
  static const EventChannel _events =
      EventChannel('com.dominoshak.domino_shak/deeplink_events');

  final StreamController<String> _rooms = StreamController<String>.broadcast();

  /// Valid room codes delivered after startup (warm starts and new intents).
  Stream<String> get rooms => _rooms.stream;

  bool _started = false;

  /// Starts listening and returns the valid room code from the cold-start
  /// intent, if any.
  Future<String?> start() async {
    if (_started) return null;
    _started = true;

    _events.receiveBroadcastStream().listen(
      (dynamic event) {
        final code = parseInviteRoomCode(event is String ? event : null);
        if (code != null) _rooms.add(code);
      },
      onError: (Object _) {
        // Deep links are optional; never break the game if the channel fails.
      },
    );

    try {
      final initial = await _channel.invokeMethod<String>('getInitialLink');
      return parseInviteRoomCode(initial);
    } catch (_) {
      return null;
    }
  }
}
