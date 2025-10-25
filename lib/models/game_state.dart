import 'kadi_card.dart';
import 'kadi_player.dart';

class GameState {
  static const Object _sentinel = Object();

  final String id;
  final List<KadiPlayer> players;
  final String hostUid;
  final String hostName;
  final List<KadiCard> drawPile;
  final List<KadiCard> discardPile;
  final int turnIndex;
  final String gameStatus; // waiting | playing | finished
  final DateTime createdAt;

  // Active requirements and penalties
  final Suit? requiredSuit; // suit requested by ace (non spade)
  final Rank? requestedRank; // Ace of spades requested rank
  final Suit? requestedCardSuit; // Ace of spades requested suit
  final String? aceRequesterId; // player who issued the request
  final Suit? questionSuit; // last question suit that must be answered
  final Rank? questionAnswerRank; // rank required for subsequent answers
  final int pendingDraw; // accumulated penalty cards to draw
  final String? penaltyStarterId; // player who triggered the pending penalty

  // Direction and skip handling
  final bool clockwise; // true => clockwise, false => counterclockwise
  final int skipCount; // players to skip when advancing turn (applied value)
  final int pendingJumpSkips; // skips waiting for the cancel window to resolve
  final String? jumpInitiatorId; // player who played jump combo
  final DateTime? jumpExpiresAt; // cancel deadline for the jump

  final int pendingKickToggles; // pending direction flips awaiting cancel window
  final String? kickInitiatorId; // player who played kickback combo
  final DateTime? kickExpiresAt; // cancel deadline for kickback

  // Win state and niko tracking
  final int maxPlayers;
  final String? winnerUid;
  final bool waitingForWinnerConfirmation;
  final List<String> winnerConfirmations;
  final List<String> nikoPending; // players who must decide whether to announce
  final List<String> nikoDeclared; // players that already called "Niko Kadi"

  // Timeline and other ui metadata
  final List<String> eventLog; // chronological description of actions
  final CardColor? requiredJokerColor; // forced joker color after cancel
  final String? comboOwnerId; // player allowed to continue identical plays
  final Rank? comboRank; // active identical rank being chained

  GameState({
    required this.id,
    required this.players,
    required this.drawPile,
    required this.discardPile,
    required this.turnIndex,
    required this.gameStatus,
    required this.createdAt,
    required this.hostUid,
    required this.hostName,
    this.requiredSuit,
    this.requestedRank,
    this.requestedCardSuit,
    this.aceRequesterId,
    this.questionSuit,
    this.questionAnswerRank,
    this.pendingDraw = 0,
    this.penaltyStarterId,
    this.clockwise = true,
    this.skipCount = 0,
    this.pendingJumpSkips = 0,
    this.jumpInitiatorId,
    this.jumpExpiresAt,
    this.pendingKickToggles = 0,
    this.kickInitiatorId,
    this.kickExpiresAt,
    this.maxPlayers = 2,
    this.winnerUid,
    this.waitingForWinnerConfirmation = false,
    List<String>? winnerConfirmations,
    List<String>? nikoPending,
    List<String>? nikoDeclared,
    List<String>? eventLog,
    this.requiredJokerColor,
    this.comboOwnerId,
    this.comboRank,
  })  : winnerConfirmations = winnerConfirmations ?? const [],
        nikoPending = nikoPending ?? const [],
        nikoDeclared = nikoDeclared ?? const [],
        eventLog = eventLog ?? const [];

  KadiCard get top => discardPile.isNotEmpty ? discardPile.last : drawPile.first;

  GameState copyWith({
    String? id,
    List<KadiPlayer>? players,
    String? hostUid,
    String? hostName,
    List<KadiCard>? drawPile,
    List<KadiCard>? discardPile,
    int? turnIndex,
    String? gameStatus,
    DateTime? createdAt,
    Object? requiredSuit = _sentinel,
    Object? requestedRank = _sentinel,
    Object? requestedCardSuit = _sentinel,
    Object? aceRequesterId = _sentinel,
    Object? questionSuit = _sentinel,
    Object? questionAnswerRank = _sentinel,
    int? pendingDraw,
    Object? penaltyStarterId = _sentinel,
    bool? clockwise,
    int? skipCount,
    int? pendingJumpSkips,
    Object? jumpInitiatorId = _sentinel,
    Object? jumpExpiresAt = _sentinel,
    int? pendingKickToggles,
    Object? kickInitiatorId = _sentinel,
    Object? kickExpiresAt = _sentinel,
    int? maxPlayers,
    Object? winnerUid = _sentinel,
    bool? waitingForWinnerConfirmation,
    List<String>? winnerConfirmations,
    List<String>? nikoPending,
    List<String>? nikoDeclared,
    List<String>? eventLog,
    Object? requiredJokerColor = _sentinel,
    Object? comboOwnerId = _sentinel,
    Object? comboRank = _sentinel,
  }) =>
      GameState(
        id: id ?? this.id,
        players: players ?? List<KadiPlayer>.from(this.players),
        hostUid: hostUid ?? this.hostUid,
        hostName: hostName ?? this.hostName,
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
        aceRequesterId: identical(aceRequesterId, _sentinel)
            ? this.aceRequesterId
            : aceRequesterId as String?,
        questionSuit: identical(questionSuit, _sentinel)
            ? this.questionSuit
            : questionSuit as Suit?,
        questionAnswerRank: identical(questionAnswerRank, _sentinel)
            ? this.questionAnswerRank
            : questionAnswerRank as Rank?,
        pendingDraw: pendingDraw ?? this.pendingDraw,
        penaltyStarterId: identical(penaltyStarterId, _sentinel)
            ? this.penaltyStarterId
            : penaltyStarterId as String?,
        clockwise: clockwise ?? this.clockwise,
        skipCount: skipCount ?? this.skipCount,
        pendingJumpSkips: pendingJumpSkips ?? this.pendingJumpSkips,
        jumpInitiatorId: identical(jumpInitiatorId, _sentinel)
            ? this.jumpInitiatorId
            : jumpInitiatorId as String?,
        jumpExpiresAt: identical(jumpExpiresAt, _sentinel)
            ? this.jumpExpiresAt
            : jumpExpiresAt as DateTime?,
        pendingKickToggles: pendingKickToggles ?? this.pendingKickToggles,
        kickInitiatorId: identical(kickInitiatorId, _sentinel)
            ? this.kickInitiatorId
            : kickInitiatorId as String?,
        kickExpiresAt: identical(kickExpiresAt, _sentinel)
            ? this.kickExpiresAt
            : kickExpiresAt as DateTime?,
        maxPlayers: maxPlayers ?? this.maxPlayers,
        winnerUid: identical(winnerUid, _sentinel)
            ? this.winnerUid
            : winnerUid as String?,
        waitingForWinnerConfirmation:
            waitingForWinnerConfirmation ?? this.waitingForWinnerConfirmation,
        winnerConfirmations:
            winnerConfirmations ?? List<String>.from(this.winnerConfirmations),
        nikoPending: nikoPending ?? List<String>.from(this.nikoPending),
        nikoDeclared: nikoDeclared ?? List<String>.from(this.nikoDeclared),
        eventLog: eventLog ?? List<String>.from(this.eventLog),
        requiredJokerColor: identical(requiredJokerColor, _sentinel)
            ? this.requiredJokerColor
            : requiredJokerColor as CardColor?,
        comboOwnerId: identical(comboOwnerId, _sentinel)
            ? this.comboOwnerId
            : comboOwnerId as String?,
        comboRank: identical(comboRank, _sentinel)
            ? this.comboRank
            : comboRank as Rank?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'players': players.map((p) => p.toJson()).toList(),
        'drawPile': drawPile.map((c) => c.toJson()).toList(),
        'discardPile': discardPile.map((c) => c.toJson()).toList(),
        'turnIndex': turnIndex,
        'gameStatus': gameStatus,
        'createdAt': createdAt.toIso8601String(),
        'hostUid': hostUid,
        'hostName': hostName,
        'requiredSuit': requiredSuit?.name,
        'requestedRank': requestedRank?.name,
        'requestedCardSuit': requestedCardSuit?.name,
        'aceRequesterId': aceRequesterId,
        'questionSuit': questionSuit?.name,
        'questionAnswerRank': questionAnswerRank?.name,
        'pendingDraw': pendingDraw,
        'penaltyStarterId': penaltyStarterId,
        'clockwise': clockwise,
        'skipCount': skipCount,
        'pendingJumpSkips': pendingJumpSkips,
        'jumpInitiatorId': jumpInitiatorId,
        'jumpExpiresAt': jumpExpiresAt?.toIso8601String(),
        'pendingKickToggles': pendingKickToggles,
        'kickInitiatorId': kickInitiatorId,
        'kickExpiresAt': kickExpiresAt?.toIso8601String(),
        'maxPlayers': maxPlayers,
        'winnerUid': winnerUid,
        'waitingForWinnerConfirmation': waitingForWinnerConfirmation,
        'winnerConfirmations': winnerConfirmations,
        'nikoPending': nikoPending,
        'nikoDeclared': nikoDeclared,
        'eventLog': eventLog,
        'requiredJokerColor': requiredJokerColor?.name,
        'comboOwnerId': comboOwnerId,
        'comboRank': comboRank?.name,
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
        hostUid: (json['hostUid'] as String?) ?? '',
        hostName: (json['hostName'] as String?) ?? 'Host',
        requiredSuit: (json['requiredSuit'] as String?) == null
            ? null
            : Suit.values.firstWhere((e) => e.name == json['requiredSuit']),
        requestedRank: (json['requestedRank'] as String?) == null
            ? null
            : Rank.values.firstWhere((e) => e.name == json['requestedRank']),
        requestedCardSuit: (json['requestedCardSuit'] as String?) == null
            ? null
            : Suit.values.firstWhere((e) => e.name == json['requestedCardSuit']),
        aceRequesterId: json['aceRequesterId'] as String?,
        questionSuit: (json['questionSuit'] as String?) == null
            ? null
            : Suit.values.firstWhere((e) => e.name == json['questionSuit']),
        questionAnswerRank: (json['questionAnswerRank'] as String?) == null
            ? null
            : Rank.values
                .firstWhere((e) => e.name == json['questionAnswerRank']),
        pendingDraw: (json['pendingDraw'] ?? 0) as int,
        penaltyStarterId: json['penaltyStarterId'] as String?,
        clockwise: (json['clockwise'] ?? true) as bool,
        skipCount: (json['skipCount'] ?? 0) as int,
        pendingJumpSkips: (json['pendingJumpSkips'] ?? 0) as int,
        jumpInitiatorId: json['jumpInitiatorId'] as String?,
        jumpExpiresAt: DateTime.tryParse(json['jumpExpiresAt'] ?? ''),
        pendingKickToggles: (json['pendingKickToggles'] ?? 0) as int,
        kickInitiatorId: json['kickInitiatorId'] as String?,
        kickExpiresAt: DateTime.tryParse(json['kickExpiresAt'] ?? ''),
        maxPlayers: (json['maxPlayers'] ?? 2) as int,
        winnerUid: json['winnerUid'] as String?,
        waitingForWinnerConfirmation:
            (json['waitingForWinnerConfirmation'] ?? false) as bool,
        winnerConfirmations: (json['winnerConfirmations'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
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
            : CardColor.values
                .firstWhere((e) => e.name == json['requiredJokerColor']),
        comboOwnerId: json['comboOwnerId'] as String?,
        comboRank: (json['comboRank'] as String?) == null
            ? null
            : Rank.values.firstWhere((e) => e.name == json['comboRank']),
      );
}
