import 'dart:async';

typedef Json = Map<String, Object?>;

/// A message received in a room, and who sent it.
final class RoomMessage {
  const RoomMessage(this.from, this.payload);

  final String from;
  final Json payload;
}

/// How the phones of a room talk to each other. Delivery is not guaranteed:
/// whoever uses it must cope with a message that never arrives.
abstract interface class RoomTransport {
  /// What this phone is known as in a room.
  String get selfId;

  /// Messages sent to everyone, or to this phone alone.
  Stream<RoomMessage> get messages;

  Future<void> connect(String room);

  /// Sends [payload] to [to], or to everyone else in the room.
  void send(Json payload, {String? to});

  Future<void> disconnect();
}

/// Makes the transport of the phone known as the given id.
typedef TransportFactory = RoomTransport Function(String selfId);

/// Rooms that live in memory, for tests: every transport made by the same
/// hub can reach the others.
class MemoryRoomHub {
  final Map<String, Map<String, MemoryRoomTransport>> _rooms = {};

  MemoryRoomTransport transport(String id) => MemoryRoomTransport._(this, id);
}

class MemoryRoomTransport implements RoomTransport {
  MemoryRoomTransport._(this._hub, this.selfId);

  final MemoryRoomHub _hub;
  final _messages = StreamController<RoomMessage>.broadcast();
  String? _room;

  /// When true, what this phone sends is lost, as on a bad connection.
  bool dropOutgoing = false;

  @override
  final String selfId;

  @override
  Stream<RoomMessage> get messages => _messages.stream;

  @override
  Future<void> connect(String room) async {
    _room = room;
    (_hub._rooms[room] ??= {})[selfId] = this;
  }

  @override
  void send(Json payload, {String? to}) {
    final room = _room;
    if (room == null || dropOutgoing) return;
    final members = _hub._rooms[room] ?? const {};
    for (final member in members.values.toList()) {
      if (member.selfId == selfId) continue;
      if (to != null && member.selfId != to) continue;
      // As a network would: later, and as a copy.
      scheduleMicrotask(() {
        if (member._room == room && !member._messages.isClosed) {
          member._messages.add(RoomMessage(selfId, Map.of(payload)));
        }
      });
    }
  }

  @override
  Future<void> disconnect() async {
    final room = _room;
    if (room == null) return;
    _room = null;
    _hub._rooms[room]?.remove(selfId);
  }
}
