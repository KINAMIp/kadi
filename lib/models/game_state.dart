import 'kadi_card.dart';
import 'kadi_player.dart';

class GameState {
  final String id;
  final List<KadiPlayer> players;
  final List<KadiCard> drawPile;
  final List<KadiCard> discardPile;
  final int turnIndex;
  final String gameStatus; // waiting | playing | finished
  final DateTime createdAt;
  final Suit? requiredSuit; // after Ace rule, null otherwise

  GameState({
    required this.id,
    required this.players,
    required this.drawPile,
    required this.discardPile,
    required this.turnIndex,
    required this.gameStatus,
    required this.createdAt,
    this.requiredSuit,
  });

  KadiCard get top => discardPile.isNotEmpty ? discardPile.last : drawPile.first;

  GameState copyWith({
    String? id,
    List<KadiPlayer>? players,
    List<KadiCard>? drawPile,
    List<KadiCard>? discardPile,
    int? turnIndex,
    String? gameStatus,
    DateTime? createdAt,
    Suit? requiredSuit,
  }) =>
      GameState(
        id: id ?? this.id,
        players: players ?? List<KadiPlayer>.from(this.players),
        drawPile: drawPile ?? List<KadiCard>.from(this.drawPile),
        discardPile: discardPile ?? List<KadiCard>.from(this.discardPile),
        turnIndex: turnIndex ?? this.turnIndex,
        gameStatus: gameStatus ?? this.gameStatus,
        createdAt: createdAt ?? this.createdAt,
        requiredSuit: requiredSuit,
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
      );
}