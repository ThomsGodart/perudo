import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bots/bot.dart';
import '../engine/game.dart';
import '../game/table.dart';
import '../theme/tokens.dart';

/// Where the settings are kept between launches.
abstract interface class SettingsStore {
  String? read(String key);
  void write(String key, String value);
}

class MemorySettingsStore implements SettingsStore {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? read(String key) => _prefs.getString(key);

  @override
  void write(String key, String value) {
    // A setting that is not saved is asked again: never a reason to crash.
    _prefs.setString(key, value).catchError((Object _) => false);
  }
}

enum BotSpeed { slow, normal, fast }

/// The player's profile and preferences.
class AppSettings extends ChangeNotifier {
  AppSettings(this._store) {
    // Nobody is called « Toi »: a name is drawn at the first launch, and
    // kept until the player picks their own.
    final saved = _store.read('name');
    if (saved == null || !isAllowedName(saved)) {
      playerName = randomName();
      _store.write('name', playerName);
    } else {
      playerName = saved;
    }
    diceColor = (_int('color') ?? 0).clamp(0, Tokens.diceColors.length - 1);
    showDiceTally = _bool('showDiceTally') ?? true;
    showOpponentDice = _bool('showOpponentDice') ?? true;
    cupAlwaysUp = _bool('cupAlwaysUp') ?? false;
    reduceMotion = _bool('reduceMotion') ?? false;
    botSpeed = BotSpeed.values[(_int('botSpeed') ?? 1).clamp(0, 2)];
    botLevel = BotLevel.values[(_int('botLevel') ?? 1).clamp(0, 2)];
    soloBots = (_int('soloBots') ?? 3).clamp(1, 5);
    startDice = (_int('startDice') ?? GameOptions.maxDice).clamp(
      GameOptions.minDice,
      GameOptions.maxDice,
    );
    calza = _bool('calza') ?? true;
    var id = _store.read('id');
    if (id == null) {
      final random = Random.secure();
      id = List.generate(
        12,
        (_) => random.nextInt(36).toRadixString(36),
      ).join();
      _store.write('id', id);
    }
    deviceId = id;
  }

  final SettingsStore _store;

  static const _animals = [
    'Lama',
    'Condor',
    'Puma',
    'Alpaga',
    'Jaguar',
    'Toucan',
    'Tatou',
    'Colibri',
    'Caïman',
    'Vigogne',
    'Tapir',
    'Ocelot',
  ];

  /// A name to start with, such as « Lama 42 ».
  static String randomName([Random? random]) {
    final source = random ?? Random();
    return '${_animals[source.nextInt(_animals.length)]} '
        '${10 + source.nextInt(90)}';
  }

  /// Whether [name] tells a player apart: not blank, and not « Toi ».
  static bool isAllowedName(String name) {
    final trimmed = name.trim().toLowerCase();
    return trimmed.isNotEmpty && trimmed != 'toi';
  }

  static const maxNameLength = 14;

  /// What this phone is known as in online rooms; made once.
  late final String deviceId;

  late String playerName;

  /// An index into [Tokens.diceColors].
  late int diceColor;

  /// Whether the centre of the table counts the dice in play and lost.
  late bool showDiceTally;

  /// Whether each opponent's number of dice is written at their seat.
  late bool showOpponentDice;

  /// Whether the player's dice stay in sight instead of under the cup.
  late bool cupAlwaysUp;
  late bool reduceMotion;
  late BotSpeed botSpeed;
  late BotLevel botLevel;

  /// How many bots a solo game was last played against.
  late int soloBots;

  /// How many dice each player starts a solo game with.
  late int startDice;
  late bool calza;

  int? _int(String key) => int.tryParse(_store.read(key) ?? '');
  bool? _bool(String key) => switch (_store.read(key)) {
    'true' => true,
    'false' => false,
    _ => null,
  };

  TablePace get pace => switch (botSpeed) {
    BotSpeed.slow => const TablePace(botThinks: Duration(milliseconds: 2600)),
    BotSpeed.normal => const TablePace(),
    BotSpeed.fast => const TablePace(
      botThinks: Duration(milliseconds: 700),
      afterRoll: Duration(milliseconds: 1600),
    ),
  };

  /// Saves the profile. A name that is not allowed leaves the old one.
  void setProfile({required String name, required int color}) {
    final trimmed = name.trim();
    if (isAllowedName(trimmed)) {
      playerName = trimmed.substring(0, min(trimmed.length, maxNameLength));
    }
    diceColor = color;
    _store.write('name', playerName);
    _store.write('color', '$color');
    notifyListeners();
  }

  void update({
    bool? showDiceTally,
    bool? showOpponentDice,
    bool? cupAlwaysUp,
    bool? reduceMotion,
    BotSpeed? botSpeed,
    BotLevel? botLevel,
    int? soloBots,
    int? startDice,
    bool? calza,
  }) {
    this.showDiceTally = showDiceTally ?? this.showDiceTally;
    this.showOpponentDice = showOpponentDice ?? this.showOpponentDice;
    this.cupAlwaysUp = cupAlwaysUp ?? this.cupAlwaysUp;
    this.reduceMotion = reduceMotion ?? this.reduceMotion;
    this.botSpeed = botSpeed ?? this.botSpeed;
    this.botLevel = botLevel ?? this.botLevel;
    this.soloBots = soloBots ?? this.soloBots;
    this.startDice = startDice ?? this.startDice;
    this.calza = calza ?? this.calza;
    _store.write('showDiceTally', '${this.showDiceTally}');
    _store.write('showOpponentDice', '${this.showOpponentDice}');
    _store.write('cupAlwaysUp', '${this.cupAlwaysUp}');
    _store.write('reduceMotion', '${this.reduceMotion}');
    _store.write('botSpeed', '${this.botSpeed.index}');
    _store.write('botLevel', '${this.botLevel.index}');
    _store.write('soloBots', '${this.soloBots}');
    _store.write('startDice', '${this.startDice}');
    _store.write('calza', '${this.calza}');
    notifyListeners();
  }
}
