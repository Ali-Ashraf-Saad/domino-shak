import 'package:domino_shak/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('room code validation', () {
    final bridge = NativeBridge();

    test('accepts generated and custom room codes', () {
      expect(bridge.isValidRoomCode('BM9ZP'), isTrue);
      expect(bridge.isValidRoomCode('ABCD'), isTrue);
      expect(bridge.isValidRoomCode('ABCD1234'), isTrue);
    });

    test('rejects unsafe or malformed codes', () {
      expect(bridge.isValidRoomCode(null), isFalse);
      expect(bridge.isValidRoomCode(''), isFalse);
      expect(bridge.isValidRoomCode('ABC'), isFalse);
      expect(bridge.isValidRoomCode('ABCDEFGHI'), isFalse);
      expect(bridge.isValidRoomCode('abcd'), isFalse);
      expect(bridge.isValidRoomCode('AB-CD'), isFalse);
      expect(bridge.isValidRoomCode('http://localhost:8080'), isFalse);
      expect(bridge.isValidRoomCode(12345), isFalse);
    });
  });

  group('bridge token', () {
    final bridge = NativeBridge();

    test('accepts only the per-launch token', () {
      expect(bridge.isTokenValid(bridge.token), isTrue);
      expect(bridge.isTokenValid(''), isFalse);
      expect(bridge.isTokenValid(null), isFalse);
      expect(bridge.isTokenValid(NativeBridge().token), isFalse);
    });

    test('tokens are long and unique per instance', () {
      expect(bridge.token.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(bridge.token), isTrue);
      expect(bridge.token, isNot(NativeBridge().token));
    });
  });

  group('mobile shim', () {
    final shim = buildMobileShim('test-token-123');

    test('is injected with the bridge token', () {
      expect(shim, contains("var TOKEN = 'test-token-123';"));
      expect(shim, isNot(contains('__BRIDGE_TOKEN__')));
    });

    test('exposes the Android integration hooks used by the shell', () {
      expect(shim, contains("bridge('shareRoom'"));
      expect(shim, contains("bridge('copyCode'"));
      expect(shim, contains("bridge('requestMic'"));
      expect(shim, contains('window.__dominoBack'));
      expect(shim, contains('window.__dominoLeave'));
      expect(shim, contains("return 'lobby'"));
      expect(shim, contains('ابعت كود الطاولة'));
    });

    test('does not contain a localhost invite URL', () {
      expect(shim, isNot(contains('localhost:8080')));
      expect(shim, isNot(contains('?room=')));
    });
  });
}
