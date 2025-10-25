import 'dart:collection';

import '../models/game_state.dart';
import '../models/kadi_card.dart';
import '../models/kadi_player.dart';

const Set<Rank> _ordinaryRanks = {
  Rank.four,
  Rank.five,
  Rank.six,
  Rank.seven,
  Rank.nine,
  Rank.ten,
};

const Map<Suit, String> _suitSymbols = {
  Suit.hearts: '♥',
  Suit.diamonds: '♦',
  Suit.clubs: '♣',
  Suit.spades: '♠',
  Suit.joker: '🃏',
};

String _cardLabel(KadiCard card) {
  final symbol = _suitSymbols[card.suit] ?? card.suit.name;
  return '${card.rank.label}$symbol';
}

class AceRequest {
  final String requesterId;
  final Rank rank;
  final Suit suit;

  const AceRequest({
    required this.requesterId,
    required this.rank,
    required this.suit,
  });
}

class JumpWindow {
  final String initiatorId;
  final int skipCount;
  final DateTime expiresAt;

  const JumpWindow({
    required this.initiatorId,
    required this.skipCount,
    required this.expiresAt,
  });

  JumpWindow copyWith({
    String? initiatorId,
    int? skipCount,
    DateTime? expiresAt,
  }) =>
      JumpWindow(
        initiatorId: initiatorId ?? this.initiatorId,
        skipCount: skipCount ?? this.skipCount,
        expiresAt: expiresAt ?? this.expiresAt,
      );
}

class KickWindow {
  final String initiatorId;
  final int toggleCount;
  final DateTime expiresAt;

  const KickWindow({
    required this.initiatorId,
    required this.toggleCount,
    required this.expiresAt,
  });

  KickWindow copyWith({
    String? initiatorId,
    int? toggleCount,
    DateTime? expiresAt,
  }) =>
      KickWindow(
        initiatorId: initiatorId ?? this.initiatorId,
        toggleCount: toggleCount ?? this.toggleCount,
        expiresAt: expiresAt ?? this.expiresAt,
      );
}

class RuleState {
  final Suit? forcedSuit;
  final AceRequest? aceRequest;
  final int pendingDraw;
  final String? penaltyStarterId;
  final bool clockwise;
  final int skipCount;
  final JumpWindow? jumpWindow;
  final KickWindow? kickWindow;
  final Set<String> nikoPending;
  final Set<String> nikoDeclared;
  final bool waitingForWinnerConfirmation;

  const RuleState({
    this.forcedSuit,
    this.aceRequest,
    this.pendingDraw = 0,
    this.penaltyStarterId,
    this.clockwise = true,
    this.skipCount = 0,
    this.jumpWindow,
    this.kickWindow,
    Set<String>? nikoPending,
    Set<String>? nikoDeclared,
    this.waitingForWinnerConfirmation = false,
  })  : nikoPending = nikoPending ?? const <String>{},
        nikoDeclared = nikoDeclared ?? const <String>{};

  RuleState copyWith({
    Suit? forcedSuit,
    bool clearForcedSuit = false,
    AceRequest? aceRequest,
    bool clearAceRequest = false,
    int? pendingDraw,
    String? penaltyStarterId,
    bool clearPenaltyStarter = false,
    bool? clockwise,
    int? skipCount,
    JumpWindow? jumpWindow,
    bool clearJumpWindow = false,
    KickWindow? kickWindow,
    bool clearKickWindow = false,
    Set<String>? nikoPending,
    Set<String>? nikoDeclared,
    bool? waitingForWinnerConfirmation,
  }) {
    return RuleState(
      forcedSuit: clearForcedSuit
          ? null
          : (forcedSuit ?? this.forcedSuit),
      aceRequest: clearAceRequest ? null : (aceRequest ?? this.aceRequest),
      pendingDraw: pendingDraw ?? this.pendingDraw,
      penaltyStarterId: clearPenaltyStarter
          ? null
          : (penaltyStarterId ?? this.penaltyStarterId),
      clockwise: clockwise ?? this.clockwise,
      skipCount: skipCount ?? this.skipCount,
      jumpWindow: clearJumpWindow ? null : (jumpWindow ?? this.jumpWindow),
      kickWindow: clearKickWindow ? null : (kickWindow ?? this.kickWindow),
      nikoPending: nikoPending ?? this.nikoPending,
      nikoDeclared: nikoDeclared ?? this.nikoDeclared,
      waitingForWinnerConfirmation:
          waitingForWinnerConfirmation ?? this.waitingForWinnerConfirmation,
    );
  }

  factory RuleState.fromGame(GameState game) {
    final aceRequest =
        (game.requestedRank != null && game.requestedCardSuit != null)
            ? AceRequest(
                requesterId: game.aceRequesterId ?? '',
                rank: game.requestedRank!,
                suit: game.requestedCardSuit!,
              )
            : null;
    final jumpWindow = (game.jumpInitiatorId != null &&
            (game.pendingJumpSkips) > 0 &&
            game.jumpExpiresAt != null)
        ? JumpWindow(
            initiatorId: game.jumpInitiatorId!,
            skipCount: game.pendingJumpSkips,
            expiresAt: game.jumpExpiresAt!,
          )
        : null;
    final kickWindow = (game.kickInitiatorId != null &&
            (game.pendingKickToggles) > 0 &&
            game.kickExpiresAt != null)
        ? KickWindow(
            initiatorId: game.kickInitiatorId!,
            toggleCount: game.pendingKickToggles,
            expiresAt: game.kickExpiresAt!,
          )
        : null;
    return RuleState(
      forcedSuit: game.requiredSuit,
      aceRequest: aceRequest,
      pendingDraw: game.pendingDraw,
      penaltyStarterId: game.penaltyStarterId,
      clockwise: game.clockwise,
      skipCount: game.skipCount,
      jumpWindow: jumpWindow,
      kickWindow: kickWindow,
      nikoPending: game.nikoPending.toSet(),
      nikoDeclared: game.nikoDeclared.toSet(),
      waitingForWinnerConfirmation: game.waitingForWinnerConfirmation,
    );
  }

  GameState apply(GameState game) {
    return game.copyWith(
      requiredSuit: forcedSuit,
      requestedRank: aceRequest == null ? null : aceRequest!.rank,
      requestedCardSuit: aceRequest == null ? null : aceRequest!.suit,
      aceRequesterId: aceRequest == null ? null : aceRequest!.requesterId,
      pendingDraw: pendingDraw,
      penaltyStarterId: penaltyStarterId,
      clockwise: clockwise,
      skipCount: skipCount,
      pendingJumpSkips: jumpWindow?.skipCount ?? 0,
      jumpInitiatorId: jumpWindow == null ? null : jumpWindow!.initiatorId,
      jumpExpiresAt: jumpWindow?.expiresAt,
      pendingKickToggles: kickWindow?.toggleCount ?? 0,
      kickInitiatorId: kickWindow == null ? null : kickWindow!.initiatorId,
      kickExpiresAt: kickWindow?.expiresAt,
      nikoPending: nikoPending.toList(),
      nikoDeclared: nikoDeclared.toList(),
      waitingForWinnerConfirmation: waitingForWinnerConfirmation,
    );
  }
}

class RuleOutcome {
  final bool isValid;
  final String? reason;
  final RuleState state;
  final List<String> timeline;
  final String? instruction;
  final bool advanceTurn;
  final bool startJumpTimer;
  final bool startKickTimer;

  RuleOutcome._({
    required this.isValid,
    required this.state,
    required this.timeline,
    required this.reason,
    required this.instruction,
    required this.advanceTurn,
    required this.startJumpTimer,
    required this.startKickTimer,
  });

  factory RuleOutcome.invalid(RuleState state, String reason) => RuleOutcome._(
        isValid: false,
        state: state,
        timeline: const [],
        reason: reason,
        instruction: null,
        advanceTurn: false,
        startJumpTimer: false,
        startKickTimer: false,
      );

  factory RuleOutcome.valid({
    required RuleState state,
    List<String>? timeline,
    String? instruction,
    bool advanceTurn = true,
    bool startJumpTimer = false,
    bool startKickTimer = false,
  }) =>
      RuleOutcome._(
        isValid: true,
        state: state,
        timeline: timeline ?? const [],
        reason: null,
        instruction: instruction,
        advanceTurn: advanceTurn,
        startJumpTimer: startJumpTimer,
        startKickTimer: startKickTimer,
      );
}

class RuleEngine {
  const RuleEngine();

  RuleOutcome play({
    required GameState game,
    required KadiPlayer player,
    required List<KadiCard> cards,
    AceRequest? aceRequest,
  }) {
    if (cards.isEmpty) {
      return RuleOutcome.invalid(
        RuleState.fromGame(game),
        'You must select at least one card.',
      );
    }

    final ruleState = RuleState.fromGame(game);
    final first = cards.first;

    if (ruleState.waitingForWinnerConfirmation) {
      return RuleOutcome.invalid(
        ruleState,
        'Round is awaiting confirmation of the winning move.',
      );
    }

    // Jump/Kick cancel windows are handled separately.
    if (ruleState.jumpWindow != null && DateTime.now().isBefore(ruleState.jumpWindow!.expiresAt)) {
      // Only cancellation allowed
      if (!first.isSkip) {
        return RuleOutcome.invalid(
          ruleState,
          'Only a J may be played to cancel the jump during the timer.',
        );
      }
      if (player.uid == ruleState.jumpWindow!.initiatorId) {
        return RuleOutcome.invalid(
          ruleState,
          'You cannot cancel your own jump.',
        );
      }
      if (cards.length != 1) {
        return RuleOutcome.invalid(
          ruleState,
          'Play a single J to cancel the jump.',
        );
      }
      final updated = ruleState.copyWith(
        skipCount: 0,
        jumpWindow: null,
      );
      return RuleOutcome.valid(
        state: updated,
        timeline: ['${player.name} canceled the jump.'],
        instruction: 'Play continues from ${_cardLabel(first)}.',
        advanceTurn: true,
      );
    }

    if (ruleState.kickWindow != null &&
        DateTime.now().isBefore(ruleState.kickWindow!.expiresAt)) {
      if (first.rank != Rank.king) {
        return RuleOutcome.invalid(
          ruleState,
          'Only a K may be played to cancel the kickback during the timer.',
        );
      }
      if (player.uid == ruleState.kickWindow!.initiatorId) {
        return RuleOutcome.invalid(
          ruleState,
          'You cannot cancel your own kickback.',
        );
      }
      if (cards.length != 1) {
        return RuleOutcome.invalid(
          ruleState,
          'Play a single K to cancel the kickback.',
        );
      }
      final updated = ruleState.copyWith(
        kickWindow: null,
      );
      return RuleOutcome.valid(
        state: updated,
        timeline: ['${player.name} canceled the kickback.'],
        instruction: 'Direction remains ${updated.clockwise ? 'clockwise' : 'counterclockwise'}.',
        advanceTurn: true,
      );
    }

    // Ace request enforcement.
    if (ruleState.aceRequest != null) {
      final request = ruleState.aceRequest!;
      final bool matchesRequest =
          first.rank == request.rank && first.suit == request.suit;
      final bool cancelsWithAce = first.rank == Rank.ace && !first.isAceOfSpades;
      final bool playsCommander = first.isAceOfSpades;
      if (!matchesRequest && !cancelsWithAce && !playsCommander) {
        return RuleOutcome.invalid(
          ruleState,
          'You must answer the request with ${request.rank.label}${_suitSymbols[request.suit]} or cancel it with an Ace.',
        );
      }
    }

    if (ruleState.pendingDraw > 0 && !first.isPenaltyCard && !first.isAce) {
      return RuleOutcome.invalid(
        ruleState,
        'You must continue the penalty with another 2/3/Joker or cancel it with an Ace.',
      );
    }

    if (first.isAceOfSpades) {
      return _handleAceOfSpades(ruleState, player, cards, aceRequest);
    }
    if (first.isAce) {
      return _handleOtherAce(ruleState, player, cards);
    }
    if (first.isPenaltyCard) {
      return _handlePenalty(ruleState, player, cards, game.top);
    }
    if (first.isQuestionCard) {
      return _handleQuestion(ruleState, player, cards, game.top);
    }
    if (first.isSkip) {
      return _handleJump(ruleState, player, cards, game.top);
    }
    if (first.rank == Rank.king) {
      return _handleKick(ruleState, player, cards, game.top);
    }
    return _handleOrdinary(ruleState, player, cards, game.top);
  }

  RuleOutcome applyJumpExpiry(GameState game) {
    final ruleState = RuleState.fromGame(game);
    final window = ruleState.jumpWindow;
    if (window == null) {
      return RuleOutcome.invalid(ruleState, 'No jump is pending.');
    }
    if (DateTime.now().isBefore(window.expiresAt)) {
      return RuleOutcome.invalid(ruleState, 'Jump cancel window is still active.');
    }
    final updated = ruleState.copyWith(
      skipCount: window.skipCount,
      jumpWindow: null,
    );
    final timeline = [
      'Jump stands: skipping ${window.skipCount} player${window.skipCount == 1 ? '' : 's'}.',
    ];
    return RuleOutcome.valid(
      state: updated,
      timeline: timeline,
      instruction: 'Skip ${window.skipCount} player${window.skipCount == 1 ? '' : 's'} then continue.',
      advanceTurn: true,
    );
  }

  RuleOutcome applyKickExpiry(GameState game) {
    final ruleState = RuleState.fromGame(game);
    final window = ruleState.kickWindow;
    if (window == null) {
      return RuleOutcome.invalid(ruleState, 'No kickback is pending.');
    }
    if (DateTime.now().isBefore(window.expiresAt)) {
      return RuleOutcome.invalid(ruleState, 'Kickback cancel window is still active.');
    }
    var direction = ruleState.clockwise;
    for (var i = 0; i < window.toggleCount; i++) {
      direction = !direction;
    }
    final updated = ruleState.copyWith(
      clockwise: direction,
      kickWindow: null,
    );
    final timeline = [
      window.toggleCount % 2 == 0
          ? 'Kickback resolved with no net reversal.'
          : 'Direction is now ${direction ? 'clockwise' : 'counterclockwise'}.',
    ];
    return RuleOutcome.valid(
      state: updated,
      timeline: timeline,
      instruction: window.toggleCount % 2 == 0
          ? 'Play direction is unchanged.'
          : 'Play direction reversed to ${direction ? 'clockwise' : 'counterclockwise'}.',
      advanceTurn: true,
    );
  }

  static bool winningHand(List<KadiCard> hand) {
    if (hand.isEmpty) return false;
    return hand.every((card) => _ordinaryRanks.contains(card.rank));
  }

  static bool requestedCardSatisfied(GameState state, KadiCard card) {
    if (state.requestedRank == null || state.requestedCardSuit == null) {
      return false;
    }
    return card.rank == state.requestedRank &&
        card.suit == state.requestedCardSuit;
  }

  RuleOutcome _handleAceOfSpades(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
    AceRequest? request,
  ) {
    if (cards.length != 1) {
      return RuleOutcome.invalid(
        state,
        'Ace of Spades must be played alone.',
      );
    }
    if (request == null) {
      return RuleOutcome.invalid(
        state,
        'You must declare the rank and suit for the request.',
      );
    }
    final updated = state.copyWith(
      forcedSuit: null,
      aceRequest: request,
      pendingDraw: 0,
      penaltyStarterId: null,
      skipCount: 0,
    );
    final requestedLabel = '${request.rank.label}${_suitSymbols[request.suit]}';
    final timeline = [
      '${player.name} requested $requestedLabel.',
    ];
    final instruction =
        'Next player must play $requestedLabel or draw 1 card.';
    return RuleOutcome.valid(
      state: updated,
      timeline: timeline,
      instruction: instruction,
    );
  }

  RuleOutcome _handleOtherAce(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
  ) {
    if (cards.length != 1) {
      return RuleOutcome.invalid(
        state,
        'Aces cannot be combined with other cards.',
      );
    }
    final card = cards.first;
    if (state.pendingDraw > 0) {
      final updated = state.copyWith(
        pendingDraw: 0,
        penaltyStarterId: null,
        forcedSuit: null,
        aceRequest: null,
      );
      return RuleOutcome.valid(
        state: updated,
        timeline: ['${player.name} canceled the penalty.'],
        instruction:
            'Play resumes from ${_suitSymbols[card.suit]} — match the suit or play another Ace.',
      );
    }
    if (state.aceRequest != null) {
      final updated = state.copyWith(
        aceRequest: null,
        forcedSuit: card.suit,
      );
      return RuleOutcome.valid(
        state: updated,
        timeline: ['${player.name} canceled the request and changed suit to ${_suitSymbols[card.suit]}.'],
        instruction:
            'Next player must follow suit ${_suitSymbols[card.suit]} or play an Ace.',
      );
    }
    final updated = state.copyWith(
      forcedSuit: card.suit,
      aceRequest: null,
    );
    return RuleOutcome.valid(
      state: updated,
      timeline: ['${player.name} changed suit to ${_suitSymbols[card.suit]}.'],
      instruction:
          'Next player must follow suit ${_suitSymbols[card.suit]} or play an Ace.',
    );
  }

  RuleOutcome _handlePenalty(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
    KadiCard top,
  ) {
    if (_containsQuestion(cards) || cards.any((c) => c.isAce)) {
      return RuleOutcome.invalid(state, 'Penalty chains may only contain 2s, 3s, and Jokers.');
    }
    if (!_validPenaltySequence(top, state.forcedSuit, cards)) {
      return RuleOutcome.invalid(
        state,
        'Penalty cards must match by suit, rank, or joker color.',
      );
    }
    var total = state.pendingDraw;
    for (final card in cards) {
      total += card.penaltyValue;
    }
    final updated = state.copyWith(
      pendingDraw: total,
      penaltyStarterId: state.penaltyStarterId ?? player.uid,
      forcedSuit: null,
      aceRequest: null,
    );
    final timeline = [
      '${player.name} stacked penalty to +$total.',
    ];
    final instruction =
        'Next player must continue the penalty or draw $total card${total == 1 ? '' : 's'}.';
    return RuleOutcome.valid(
      state: updated,
      timeline: timeline,
      instruction: instruction,
    );
  }

  RuleOutcome _handleQuestion(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
    KadiCard top,
  ) {
    if (state.pendingDraw > 0) {
      return RuleOutcome.invalid(
        state,
        'Resolve the penalty before asking a question.',
      );
    }
    final questions = <KadiCard>[];
    final answers = <KadiCard>[];
    for (final card in cards) {
      if (card.isQuestionCard && answers.isEmpty) {
        questions.add(card);
      } else {
        answers.add(card);
      }
    }
    if (questions.isEmpty || answers.isEmpty) {
      return RuleOutcome.invalid(
        state,
        'Question cards must be followed by answer cards in the same play.',
      );
    }
    final firstQuestion = questions.first;
    if (!_matchesTop(firstQuestion, top, state.forcedSuit)) {
      return RuleOutcome.invalid(
        state,
        'The first question card must match the pile by suit or rank.',
      );
    }
    if (!_allSameRank(questions)) {
      return RuleOutcome.invalid(
        state,
        'Combined question cards must share the same rank.',
      );
    }
    final firstAnswer = answers.first;
    if (!_ordinaryRanks.contains(firstAnswer.rank)) {
      return RuleOutcome.invalid(
        state,
        'Answers must be ordinary cards.',
      );
    }
    if (!_allSameRank(answers)) {
      return RuleOutcome.invalid(
        state,
        'All answers must share the same rank.',
      );
    }
    final requiredSuit = questions.last.suit;
    if (firstAnswer.suit != requiredSuit) {
      return RuleOutcome.invalid(
        state,
        'The first answer must follow the suit of the final question card.',
      );
    }
    for (final card in answers.skip(1)) {
      if (!_ordinaryRanks.contains(card.rank) || card.rank != firstAnswer.rank) {
        return RuleOutcome.invalid(
          state,
          'All answers must repeat the same ordinary rank.',
        );
      }
    }
    final updated = state.copyWith(
      forcedSuit: null,
      aceRequest: null,
    );
    final questionLabel = questions.map(_cardLabel).join(', ');
    final answerLabel = answers.map(_cardLabel).join(', ');
    final timeline = [
      '${player.name} asked with $questionLabel and answered $answerLabel.',
    ];
    return RuleOutcome.valid(
      state: updated,
      timeline: timeline,
      instruction: null,
    );
  }

  RuleOutcome _handleJump(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
    KadiCard top,
  ) {
    if (state.pendingDraw > 0) {
      return RuleOutcome.invalid(
        state,
        'Settle the penalty chain before jumping.',
      );
    }
    if (!_matchesTop(cards.first, top, state.forcedSuit)) {
      return RuleOutcome.invalid(
        state,
        'J must match the pile by suit or rank.',
      );
    }
    if (cards.any((card) => card.rank != Rank.jack)) {
      return RuleOutcome.invalid(
        state,
        'Jump combos may only contain Js.',
      );
    }
    final skipCount = cards.length;
    final window = JumpWindow(
      initiatorId: player.uid,
      skipCount: skipCount,
      expiresAt: DateTime.now().add(const Duration(seconds: 10)),
    );
    final updated = state.copyWith(
      jumpWindow: window,
      skipCount: 0,
      forcedSuit: null,
      aceRequest: null,
    );
    final timeline = [
      '${player.name} jumped $skipCount player${skipCount == 1 ? '' : 's'}.',
    ];
    return RuleOutcome.valid(
      state: updated,
      timeline: timeline,
      instruction: 'Any player may cancel with a J within 10 seconds.',
      advanceTurn: false,
      startJumpTimer: true,
    );
  }

  RuleOutcome _handleKick(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
    KadiCard top,
  ) {
    if (state.pendingDraw > 0) {
      return RuleOutcome.invalid(
        state,
        'Settle the penalty chain before reversing direction.',
      );
    }
    if (!_matchesTop(cards.first, top, state.forcedSuit)) {
      return RuleOutcome.invalid(
        state,
        'K must match the pile by suit or rank.',
      );
    }
    if (cards.any((card) => card.rank != Rank.king)) {
      return RuleOutcome.invalid(
        state,
        'Kickback combos may only contain Ks.',
      );
    }
    final toggles = cards.length;
    final window = KickWindow(
      initiatorId: player.uid,
      toggleCount: toggles,
      expiresAt: DateTime.now().add(const Duration(seconds: 10)),
    );
    final updated = state.copyWith(
      kickWindow: window,
      forcedSuit: null,
      aceRequest: null,
    );
    final timeline = [
      '${player.name} kicked back $toggles time${toggles == 1 ? '' : 's'}.',
    ];
    return RuleOutcome.valid(
      state: updated,
      timeline: timeline,
      instruction: 'Any player may cancel with a K within 10 seconds.',
      advanceTurn: false,
      startKickTimer: true,
    );
  }

  RuleOutcome _handleOrdinary(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
    KadiCard top,
  ) {
    if (!_ordinaryRanks.contains(cards.first.rank)) {
      return RuleOutcome.invalid(
        state,
        'Play must follow the pile by suit or rank.',
      );
    }
    if (!_matchesTop(cards.first, top, state.forcedSuit)) {
      return RuleOutcome.invalid(
        state,
        'First card must match the pile by suit or rank.',
      );
    }
    if (!_allSameRank(cards)) {
      return RuleOutcome.invalid(
        state,
        'Ordinary combos must share the same rank.',
      );
    }
    for (final card in cards) {
      if (!_ordinaryRanks.contains(card.rank)) {
        return RuleOutcome.invalid(
          state,
          'Only 4, 5, 6, 7, 9, and 10 may be played as ordinary cards.',
        );
      }
    }
    final updated = state.copyWith(
      forcedSuit: null,
      aceRequest: null,
    );
    return RuleOutcome.valid(
      state: updated,
      timeline: const [],
      instruction: null,
    );
  }

  bool _matchesTop(KadiCard card, KadiCard top, Suit? forcedSuit) {
    if (forcedSuit != null) {
      return card.suit == forcedSuit || card.rank == Rank.ace;
    }
    if (card.isJoker) return true;
    if (top.isJoker) {
      return card.color == top.color || card.rank == top.rank;
    }
    return card.suit == top.suit || card.rank == top.rank;
  }

  bool _allSameRank(List<KadiCard> cards) {
    if (cards.isEmpty) return true;
    final rank = cards.first.rank;
    return cards.every((card) => card.rank == rank);
  }

  bool _containsQuestion(List<KadiCard> cards) {
    return cards.any((card) => card.isQuestionCard);
  }

  bool _validPenaltySequence(
    KadiCard top,
    Suit? forcedSuit,
    List<KadiCard> cards,
  ) {
    final sequence = Queue<KadiCard>.from(cards);
    final first = sequence.removeFirst();
    if (!_penaltyMatches(first, top, forcedSuit)) {
      return false;
    }
    var previous = first;
    while (sequence.isNotEmpty) {
      final card = sequence.removeFirst();
      if (!_penaltyMatches(card, previous, null)) {
        return false;
      }
      previous = card;
    }
    return true;
  }

  bool _penaltyMatches(KadiCard card, KadiCard reference, Suit? forcedSuit) {
    if (!card.isPenaltyCard) return false;
    if (forcedSuit != null) {
      if (card.isJoker) {
        return _colorMatchesSuit(card.color, forcedSuit);
      }
      return card.suit == forcedSuit;
    }
    if (reference.isJoker) {
      if (card.isJoker) {
        return card.color == reference.color;
      }
      return card.color == reference.color;
    }
    if (card.isJoker) {
      return _colorMatchesSuit(card.color, reference.suit);
    }
    return card.rank == reference.rank || card.suit == reference.suit;
  }

  bool _colorMatchesSuit(CardColor color, Suit suit) {
    if (suit == Suit.hearts || suit == Suit.diamonds) {
      return color == CardColor.red;
    }
    if (suit == Suit.spades || suit == Suit.clubs) {
      return color == CardColor.black;
    }
    return true;
  }
}
