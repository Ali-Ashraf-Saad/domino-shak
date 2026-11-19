import 'package:domino_shak/lan_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LAN relay registers peers and routes messages between them', () async {
    final host = LanService();
    final a = LanService();
    final b = LanService();
    final received = <String>[];

    try {
      final port = await host.startHost(0);
      expect(port, greaterThan(0));

      expect(await a.connect('127.0.0.1', port, 'peerA'), isTrue);
      expect(await b.connect('127.0.0.1', port, 'peerB'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      b.onMessage = (from, data) => received.add('$from:${data['t']}');
      expect(a.send('peerB', <String, dynamic>{'t': 'join'}), isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(received, contains('peerA:join'));
    } finally {
      await a.dispose();
      await b.dispose();
      await host.dispose();
    }
  });

  test('LAN relay reports an unknown peer without crashing', () async {
    final host = LanService();
    final a = LanService();
    try {
      final port = await host.startHost(0);
      expect(await a.connect('127.0.0.1', port, 'solo'), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // No target registered: the send is accepted locally but the relay
      // responds with an error envelope instead of closing the connection.
      expect(a.send('missing', <String, dynamic>{'t': 'join'}), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(a.isConnected, isTrue);
    } finally {
      await a.dispose();
      await host.dispose();
    }
  });
}
