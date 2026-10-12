/// Where the rooms of online games live: the Cloudflare Worker of
/// `cloudflare/`, which relays what the phones of a room say to each other.
///
/// Its address is meant to ship with the app. Another one, such as a local
/// `wrangler dev`, is passed with `--dart-define=ROOMS_URL=http://localhost:8787`;
/// while it is empty, the app plays against bots only.
abstract final class OnlineBackend {
  static const roomsUrl = String.fromEnvironment(
    'ROOMS_URL',
    defaultValue: 'https://perudo-rooms.thomsgodart.workers.dev',
  );

  static bool get configured => roomsUrl.isNotEmpty;
}
