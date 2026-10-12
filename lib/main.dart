import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'online/cloudflare_room_transport.dart';
import 'online/online_backend.dart';
import 'settings/app_settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings(
    PrefsSettingsStore(await SharedPreferences.getInstance()),
  );
  runApp(
    PerudoApp(
      settings: settings,
      transports: OnlineBackend.configured
          ? (selfId) => CloudflareRoomTransport(OnlineBackend.roomsUrl, selfId)
          : null,
    ),
  );
}
