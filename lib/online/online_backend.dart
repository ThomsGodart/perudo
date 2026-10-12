/// Where the rooms of online games live: the Cloudflare Worker of
/// `cloudflare/`, which relays what the phones of a room say to each other.
///
/// Its address is meant to ship with the app. It is written here, or passed
/// with `--dart-define=ROOMS_URL=https://perudo-rooms.xxxx.workers.dev`;
/// while it is empty, the app plays against bots only.
abstract final class OnlineBackend {
  static const roomsUrl = String.fromEnvironment('ROOMS_URL', defaultValue: '');

  static bool get configured => roomsUrl.isNotEmpty;
}
