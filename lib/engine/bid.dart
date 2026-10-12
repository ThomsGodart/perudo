/// An announcement: « at least [count] dice show [face] ».
final class Bid {
  const Bid(this.count, this.face);

  final int count;

  /// 1 to 6; 1 is the paco.
  final int face;

  bool get isPaco => face == 1;

  List<int> toJson() => [count, face];

  static Bid fromJson(Object? json) {
    final list = json as List;
    return Bid((list[0] as num).toInt(), (list[1] as num).toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is Bid && other.count == count && other.face == face;

  @override
  int get hashCode => Object.hash(count, face);

  @override
  String toString() => '$count×$face';
}

/// What may be announced, and how dice are counted.
abstract final class Rules {
  /// Whether [bid] may follow [last] (null when it opens the round).
  ///
  /// In a normal round the opening cannot be on pacos; a raise is more dice
  /// of any face, or as many of a higher face. Going to pacos halves the
  /// count (rounded up); leaving them takes twice as many plus one.
  /// In a palifico round the face never changes: only the count goes up.
  static bool isLegal(
    Bid bid, {
    required Bid? last,
    required bool palifico,
    required int totalDice,
  }) {
    if (bid.count < 1 || bid.count > totalDice) return false;
    if (bid.face < 1 || bid.face > 6) return false;
    if (last == null) return palifico || !bid.isPaco;
    if (palifico) return bid.face == last.face && bid.count > last.count;
    if (bid.isPaco) {
      return last.isPaco
          ? bid.count > last.count
          : bid.count >= (last.count + 1) ~/ 2;
    }
    if (last.isPaco) return bid.count >= last.count * 2 + 1;
    return bid.count > last.count ||
        (bid.count == last.count && bid.face > last.face);
  }

  /// The fewest dice that may be announced on [face], or null when the face
  /// cannot be announced at all.
  static int? minCount(
    int face, {
    required Bid? last,
    required bool palifico,
    required int totalDice,
  }) {
    for (var count = 1; count <= totalDice; count++) {
      if (isLegal(
        Bid(count, face),
        last: last,
        palifico: palifico,
        totalDice: totalDice,
      )) {
        return count;
      }
    }
    return null;
  }

  /// How many of [dice] count for [face]; pacos join in when [wild].
  static int count(Iterable<int> dice, int face, {required bool wild}) =>
      dice.where((die) => die == face || (wild && die == 1)).length;
}
