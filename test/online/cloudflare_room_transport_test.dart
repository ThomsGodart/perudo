import 'package:flutter_test/flutter_test.dart';
import 'package:perudo/online/cloudflare_room_transport.dart';

void main() {
  test('the line to a room is a websocket on the worker', () {
    expect(
      roomSocketUri(
        'https://perudo-rooms.example.workers.dev',
        room: 'ABCD',
        selfId: 'abc123',
      ).toString(),
      'wss://perudo-rooms.example.workers.dev/room/ABCD?id=abc123',
    );
    expect(
      roomSocketUri('http://localhost:8787/', room: 'ABCD', selfId: 'a').scheme,
      'ws',
    );
  });

  test('a relayed message is read with its sender', () {
    final message = roomMessageFrom('{"from":"host","body":{"t":"hello"}}');
    expect(message?.from, 'host');
    expect(message?.payload, {'t': 'hello'});
  });

  test('what is not a room message is dropped', () {
    expect(roomMessageFrom('not json'), isNull);
    expect(roomMessageFrom('[]'), isNull);
    expect(roomMessageFrom('{"body":{"t":"hello"}}'), isNull);
    expect(roomMessageFrom('{"from":"host","body":"hello"}'), isNull);
  });
}
