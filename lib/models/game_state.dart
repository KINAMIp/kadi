import 'kadi_card.dart';
import 'kadi_player.dart';

class GameState {
  static const Object _sentinel = Object();

  final String id;
  final List<KadiPlayer> players;
  final List<KadiCard> drawPile;
  final List<KadiCard> discardPile;
  final int turnIndex;
  final String gameStatus; // waiting | playing | finished
  final DateTime createdAt;
  final Suit? requiredSuit; // suit requested by Ace change
  final Rank? requestedRank; // Ace of spades request
  final Suit? requestedCardSuit; // suit requested alongside rank
  final Suit? questionSuit; // pending 8/Q follow-up suit
  final int pendingDraw; // accumulated penalty cards to draw
  final bool clockwise; // true => clockwise, false => counter
  final int skipCount; // number of players to skip on advance
  final int maxPlayers; // desired seats in room
  final String? winnerUid;
  final List<String> nikoPending; // players who must announce
  final List<String> nikoDeclared; // players that already called Niko Kadi
  final List<String> eventLog; // chronological description of actions
  final CardColor? requiredJokerColor; // forced joker color after cancel

  GameState({
    required this.id,
    required this.players,
    required this.drawPile,
    required this.discardPile,
    required this.turnIndex,
    required this.gameStatus,
    required this.createdAt,
    this.requiredSuit,
    this.requestedRank,
    this.requestedCardSuit,
    this.questionSuit,
    this.pendingDraw = 0,
    this.clockwise = true,
    this.skipCount = 0,
    this.maxPlayers = 2,
    this.winnerUid,
    List<String>? nikoPending,
    List<String>? nikoDeclared,
    List<String>? eventLog,
    this.requiredJokerColor,
  })  : nikoPending = nikoPending ?? const [],
        nikoDeclared = nikoDeclared ?? const [],
        eventLog = eventLog ?? const [];

  KadiCard get top => discardPile.isNotEmpty ? discardPile.last : drawPile.first;

  GameState copyWith({
    String? id,
    List<KadiPlayer>? players,
    List<KadiCard>? drawPile,
    List<KadiCard>? discardPile,
    int? turnIndex,
    String? gameStatus,
    DateTime? createdAt,
    Object? requiredSuit = _sentinel,
    Object? requestedRank = _sentinel,
    Object? requestedCardSuit = _sentinel,
    Object? questionSuit = _sentinel,
    int? pendingDraw,
    bool? clockwise,
    int? skipCount,
    int? maxPlayers,
    Object? winnerUid = _sentinel,
    List<String>? nikoPending,
    List<String>? nikoDeclared,
    List<String>? eventLog,
    Object? requiredJokerColor = _sentinel,
  }) =>
      GameState(
        id: id ?? this.id,
        players: players ?? List<KadiPlayer>.from(this.players),
        drawPile: drawPile ?? List<KadiCard>.from(this.drawPile),
        discardPile: discardPile ?? List<KadiCard>.from(this.discardPile),
        turnIndex: turnIndex ?? this.turnIndex,
        gameStatus: gameStatus ?? this.gameStatus,
        createdAt: createdAt ?? this.createdAt,
        requiredSuit: identical(requiredSuit, _sentinel)
            ? this.requiredSuit
            : requiredSuit as Suit?,
        requestedRank: identical(requestedRank, _sentinel)
            ? this.requestedRank
            : requestedRank as Rank?,
        requestedCardSuit: identical(requestedCardSuit, _sentinel)
            ? this.requestedCardSuit
            : requestedCardSuit as Suit?,
        questionSuit: identical(questionSuit, _sentinel)
            ? this.questionSuit
            : questionSuit as Suit?,
        pendingDraw: pendingDraw ?? this.pendingDraw,
        clockwise: clockwise ?? this.clockwise,
        skipCount: skipCount ?? this.skipCount,
        maxPlayers: maxPlayers ?? this.maxPlayers,
        winnerUid: identical(winnerUid, _sentinel)
            ? this.winnerUid
            : winnerUid as String?,
        nikoPending: nikoPending ?? List<String>.from(this.nikoPending),
        nikoDeclared: nikoDeclared ?? List<String>.from(this.nikoDeclared),
        eventLog: eventLog ?? List<String>.from(this.eventLog),
        requiredJokerColor: identical(requiredJokerColor, _sentinel)
            ? this.requiredJokerColor
            : requiredJokerColor as CardColor?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'players': players.map((p) => p.toJson()).toList(),
        'drawPile': drawPile.map((c) => c.toJson()).toList(),
        'discardPile': discardPile.map((c) => c.toJson()).toList(),
        'turnIndex': turnIndex,
        'gameStatus': gameStatus,
        'createdAt': createdAt.toIso8601String(),
        'requiredSuit': requiredSuit?.name,
        'requestedRank': requestedRank?.name,
        'requestedCardSuit': requestedCardSuit?.name,
        'questionSuit': questionSuit?.name,
        'pendingDraw': pendingDraw,
        'clockwise': clockwise,
        'skipCount': skipCount,
        'maxPlayers': maxPlayers,
        'winnerUid': winnerUid,
        'nikoPending': nikoPending,
        'nikoDeclared': nikoDeclared,
        'eventLog': eventLog,
        'requiredJokerColor': requiredJokerColor?.name,
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        id: json['id'] as String,
        players: (json['players'] as List<dynamic>? ?? [])
            .map((e) => KadiPlayer.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        drawPile: (json['drawPile'] as List<dynamic>? ?? [])
            .map((e) => KadiCard.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        discardPile: (json['discardPile'] as List<dynamic>? ?? [])
            .map((e) => KadiCard.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        turnIndex: (json['turnIndex'] ?? 0) as int,
        gameStatus: (json['gameStatus'] ?? 'waiting') as String,
        createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
        requiredSuit: (json['requiredSuit'] as String?) == null
            ? null
            : Suit.values.firstWhere((e) => e.name == json['requiredSuit']),
        requestedRank: (json['requestedRank'] as String?) == null
            ? null
            : Rank.values.firstWhere((e) => e.name == json['requestedRank']),
        requestedCardSuit: (json['requestedCardSuit'] as String?) == null
            ? null
            : Suit.values.firstWhere((e) => e.name == json['requestedCardSuit']),
        questionSuit: (json['questionSuit'] as String?) == null
            ? null
            : Suit.values.firstWhere((e) => e.name == json['questionSuit']),
        pendingDraw: (json['pendingDraw'] ?? 0) as int,
        clockwise: (json['clockwise'] ?? true) as bool,
        skipCount: (json['skipCount'] ?? 0) as int,
        maxPlayers: (json['maxPlayers'] ?? 2) as int,
        winnerUid: json['winnerUid'] as String?,
        nikoPending: (json['nikoPending'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        nikoDeclared: (json['nikoDeclared'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        eventLog: (json['eventLog'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        requiredJokerColor: (json['requiredJokerColor'] as String?) == null
            ? null
            : CardColor.values.firstWhere((e) => e.name == json['requiredJokerColor']),
      );
}
