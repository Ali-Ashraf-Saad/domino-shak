import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Minimal LAN-only signalling relay.
///
/// It has no dependency on PeerJS Cloud, public STUN servers, the hosted
/// website, or any internet connection. The room creator's Android app runs
/// [startHost] on a Wi-Fi hotspot; joiners connect with [connect] using the
/// host's local IP. Messages are newline-delimited JSON envelopes.
class LanService {
  static const int defaultPort = 8974;

  ServerSocket? _server;
  Socket? _client;
  String _myId = '';
  final Map<String, Socket> _peers = <String, Socket>{};

  /// Called with a peer id and the decoded game message sent by that peer.
  void Function(String from, Map<String, dynamic> data)? onMessage;

  /// Called when a registered peer disappears.
  void Function(String from)? onPeerLeft;

  /// Called for transport errors (logged only, never shown as secrets).
  void Function(String message)? onError;

  bool get isHosting => _server != null;
  bool get isConnected => _client != null;

  /// Starts the local relay. Returns the port actually bound.
  Future<int> startHost([int port = defaultPort]) async {
    await stopHost();
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server!.listen(_onIncoming, onError: (Object error) {
      onError?.call('LAN server error: $error');
    });
    return _server!.port;
  }

  Future<void> stopHost() async {
    final server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close();
      } catch (_) {}
    }
    _peers.clear();
  }

  /// Connects this device to a relay at [host] and registers [id].
  Future<bool> connect(String host, int port, String id) async {
    await closeClient();
    _myId = id;
    try {
      _client = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
    } catch (error) {
      onError?.call('LAN connect failed: $error');
      return false;
    }
    final socket = _client!;
    final reader = _LineReader();
    socket.listen(
      (List<int> bytes) {
        for (final line in reader.push(bytes)) {
          _handleClientLine(line);
        }
      },
      onError: (Object error) {
        onError?.call('LAN socket error: $error');
      },
      onDone: () {
        if (identical(_client, socket)) _client = null;
      },
    );
    _write(socket, <String, dynamic>{'kind': 'register', 'from': id});
    return true;
  }

  Future<void> closeClient() async {
    final socket = _client;
    _client = null;
    if (socket != null) {
      try {
        socket.destroy();
      } catch (_) {}
    }
    _myId = '';
  }

  Future<void> dispose() async {
    await closeClient();
    await stopHost();
  }

  /// Relays a game message to [to]. The relay stamps the sender id itself.
  bool send(String to, Map<String, dynamic> data) {
    final socket = _client;
    if (socket == null) return false;
    _write(socket, <String, dynamic>{
      'kind': 'relay',
      'from': _myId,
      'to': to,
      'data': data,
    });
    return true;
  }

  /// First non-loopback IPv4 address, preferring common hotspot ranges.
  Future<String?> localIp() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    final addresses = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final ip = address.address;
        if (ip == '127.0.0.1' || ip == '0.0.0.0') continue;
        addresses.add(ip);
      }
    }
    if (addresses.isEmpty) return null;
    for (final ip in addresses) {
      if (ip.startsWith('192.168.43.')) return ip;
    }
    for (final ip in addresses) {
      if (ip.startsWith('192.168.') || ip.startsWith('10.')) return ip;
    }
    return addresses.first;
  }

  void _onIncoming(Socket socket) {
    final reader = _LineReader();
    String? registeredId;
    socket.listen(
      (List<int> bytes) {
        for (final line in reader.push(bytes)) {
          final envelope = _decode(line);
          if (envelope == null) continue;
          final kind = envelope['kind'];
          final from = envelope['from'];
          if (kind == 'register' && from is String && from.isNotEmpty) {
            registeredId = from;
            _peers[from] = socket;
            _write(socket, <String, dynamic>{'kind': 'registered', 'from': from});
          } else if (kind == 'relay' && from is String && from.isNotEmpty) {
            final to = envelope['to'];
            final data = envelope['data'];
            if (to is! String || data is! Map<String, dynamic>) continue;
            final target = _peers[to];
            if (target == null) {
              _write(socket, <String, dynamic>{
                'kind': 'error',
                'message': 'peer-unavailable',
              });
              continue;
            }
            _write(target, <String, dynamic>{
              'kind': 'relay',
              'from': from,
              'data': data,
            });
          }
        }
      },
      onDone: () {
        final left = registeredId;
        if (left != null && _peers[left] == socket) _peers.remove(left);
        if (left != null && left.isNotEmpty) {
          for (final entry in _peers.entries) {
            if (identical(entry.value, socket)) continue;
            _write(entry.value, <String, dynamic>{'kind': 'peerleft', 'from': left});
          }
        }
        try {
          socket.destroy();
        } catch (_) {}
      },
      onError: (Object _) {
        try {
          socket.destroy();
        } catch (_) {}
      },
    );
  }

  void _handleClientLine(String line) {
    final envelope = _decode(line);
    if (envelope == null) return;
    final kind = envelope['kind'];
    if (kind == 'relay') {
      final from = envelope['from'];
      final data = envelope['data'];
      if (from is String && data is Map<String, dynamic>) {
        onMessage?.call(from, data);
      }
    } else if (kind == 'peerleft') {
      final from = envelope['from'];
      if (from is String) onPeerLeft?.call(from);
    } else if (kind == 'error') {
      onError?.call((envelope['message'] ?? 'LAN relay error').toString());
    }
  }

  Map<String, dynamic>? _decode(String line) {
    if (line.trim().isEmpty) return null;
    try {
      final value = jsonDecode(line);
      return value is Map<String, dynamic> ? value : null;
    } catch (_) {
      return null;
    }
  }

  void _write(Socket socket, Map<String, dynamic> envelope) {
    try {
      socket.writeln(jsonEncode(envelope));
    } catch (_) {}
  }
}

/// Accumulates UTF-8 bytes and emits complete newline-delimited lines.
class _LineReader {
  final List<int> _pending = <int>[];

  List<String> push(List<int> bytes) {
    _pending.addAll(bytes);
    final lines = <String>[];
    int start = 0;
    for (int i = 0; i < _pending.length; i++) {
      if (_pending[i] == 10) {
        final end = (i > start && _pending[i - 1] == 13) ? i - 1 : i;
        lines.add(utf8.decode(_pending.sublist(start, end), allowMalformed: true));
        start = i + 1;
      }
    }
    if (start > 0) _pending.removeRange(0, start);
    return lines;
  }
}
