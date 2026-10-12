import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'online/room_transport.dart';
import 'settings/app_settings.dart';
import 'theme/tokens.dart';
import 'ui/strings.dart';

class PerudoApp extends StatelessWidget {
  const PerudoApp({
    super.key,
    required this.settings,
    required this.transports,
  });

  final AppSettings settings;

  /// How this phone reaches the rooms of online games, if it can.
  final TransportFactory? transports;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: Strings.appTitle,
    debugShowCheckedModeBanner: false,
    theme: Tokens.theme(),
    home: HomeScreen(settings: settings, transports: transports),
  );
}
