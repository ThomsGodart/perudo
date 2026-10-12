import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'room_transport.dart';

/// Rooms carried by a Cloudflare Worker: one WebSocket per phone, to the
/// Durable Object of the room, which passes each message on to the phones it
/// is meant for (see `cloudflare/src/index.js`).
///
/// A line that drops is opened again; what was sent meanwhile is lost.
class CloudflareRoomTransport implements RoomTransport {
  CloudflareRoomTransport(this._roomsUrl, this.selfId);

  /// Where the Worker lives, as `wss://…` or `https://…`.
  final String _roomsUrl;
  final _messages = StreamController<RoomMessage>.broadcast();
  WebSocketChannel? _socket;
  StreamSubscription<Object?>? _incoming;
  Timer? _retry;
  String? _room;
  int _failures = 0;

  @override
  final String selfId;

  @override
  Stream<RoomMessage> get messages => _messages.stream;

  @override
  Future<void> connect(String room) async {
    _room = room;
    try {
      await _open(room);
    } on Object catch (error) {
      _room = null;
      throw StateError('could not join the room: $error');
    }
  }

  Future<void> _open(String room) async {
    final socket = WebSocketChannel.connect(
      roomSocketUri(_roomsUrl, room: room, selfId: selfId),
    );
    await socket.ready;
    if (_room != room) {
      unawaited(socket.sink.close());
      return;
    }
    _failures = 0;
    _socket = socket;
    _incoming = socket.stream.listen(
      _onData,
      onError: (Object _) {},
      onDone: () => _onLost(socket),
      cancelOnError: false,
    );
  }

  void _onData(Object? data) {
    if (data is! String) return;
    final received = roomMessageFrom(data);
    if (received != null && !_messages.isClosed) _messages.add(received);
  }

  void _onLost(WebSocketChannel socket) {
    if (_socket != socket) return;
    _socket = null;
    _incoming = null;
    _reopenLater();
  }

  void _reopenLater() {
    final room = _room;
    if (room == null) return;
    final wait = Duration(seconds: _failures < 4 ? 1 << _failures : 10);
    _failures++;
    _retry = Timer(wait, () async {
      if (_room != room) return;
      try {
        await _open(room);
      } on Object {
        _reopenLater();
      }
    });
  }

  @override
  void send(Json payload, {String? to}) {
    // Lost messages are expected and made up for by whoever sends them.
    _socket?.sink.add(jsonEncode({'to': to, 'body': payload}));
  }

  @override
  Future<void> disconnect() async {
    _room = null;
    _retry?.cancel();
    final socket = _socket;
    _socket = null;
    await _incoming?.cancel();
    _incoming = null;
    await socket?.sink.close();
  }
}

/// The address of [selfId]'s line to [room], on the Worker at [roomsUrl].
Uri roomSocketUri(
  String roomsUrl, {
  required String room,
  required String selfId,
}) {
  final base = Uri.parse(roomsUrl);
  return base.replace(
    scheme: switch (base.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      final scheme => scheme,
    },
    path: '/room/$room',
    queryParameters: {'id': selfId},
  );
}

/// The room message the Worker relayed as [text], or null when it is not one
/// of ours.
RoomMessage? roomMessageFrom(String text) {
  final Object? envelope;
  try {
    envelope = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (envelope is! Map) return null;
  final from = envelope['from'];
  final body = envelope['body'];
  if (from is! String || body is! Map) return null;
  return RoomMessage(from, {
    for (final entry in body.entries)
      if (entry.key is String) entry.key as String: entry.value,
  });
}
