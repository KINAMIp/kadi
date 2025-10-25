import 'dart:collection';

import '../models/game_state.dart';
import '../models/kadi_card.dart';
import '../models/kadi_player.dart';

const _ordinaryRanks = <Rank>{
  Rank.four,
  Rank.five,
  Rank.six,
  Rank.seven,
  Rank.nine,
  Rank.ten,
};

const _penaltyRanks = <Rank>{
  Rank.two,
  Rank.three,
  Rank.joker,
};

const _suitGlyphs = <Suit, String>{
  Suit.clubs: '♣',
  Suit.diamonds: '♦',
  Suit.hearts: '♥',
  Suit.spades: '♠',
  Suit.joker: '🃏',
};

String _describeCard(KadiCard card) {
  final glyph = _suitGlyphs[card.suit] ?? card.suit.name;
  return '${card.rank.label}$glyph';
}

String _describeSuit(Suit suit) => _suitGlyphs[suit] ?? suit.name;

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
  }) {
    return JumpWindow(
      initiatorId: initiatorId ?? this.initiatorId,
      skipCount: skipCount ?? this.skipCount,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
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
  }) {
    return KickWindow(
      initiatorId: initiatorId ?? this.initiatorId,
      toggleCount: toggleCount ?? this.toggleCount,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
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
    AceRequest? request;
    if (game.requestedRank != null &&
        game.requestedCardSuit != null &&
        game.aceRequesterId != null &&
        game.aceRequesterId!.isNotEmpty) {
      request = AceRequest(
        requesterId: game.aceRequesterId!,
        rank: game.requestedRank!,
        suit: game.requestedCardSuit!,
      );
    }
    JumpWindow? jump;
    if (game.jumpInitiatorId != null &&
        game.jumpExpiresAt != null &&
        game.pendingJumpSkips > 0) {
      jump = JumpWindow(
        initiatorId: game.jumpInitiatorId!,
        skipCount: game.pendingJumpSkips,
        expiresAt: game.jumpExpiresAt!,
      );
    }
    KickWindow? kick;
    if (game.kickInitiatorId != null &&
        game.kickExpiresAt != null &&
        game.pendingKickToggles > 0) {
      kick = KickWindow(
        initiatorId: game.kickInitiatorId!,
        toggleCount: game.pendingKickToggles,
        expiresAt: game.kickExpiresAt!,
      );
    }
    return RuleState(
      forcedSuit: game.requiredSuit,
      aceRequest: request,
      pendingDraw: game.pendingDraw,
      penaltyStarterId: game.penaltyStarterId,
      clockwise: game.clockwise,
      skipCount: game.skipCount,
      jumpWindow: jump,
      kickWindow: kick,
      nikoPending: game.nikoPending.toSet(),
      nikoDeclared: game.nikoDeclared.toSet(),
      waitingForWinnerConfirmation: game.waitingForWinnerConfirmation,
    );
  }

  GameState apply(GameState game) {
    return game.copyWith(
      requiredSuit: forcedSuit,
      requestedRank: aceRequest?.rank,
      requestedCardSuit: aceRequest?.suit,
      aceRequesterId: aceRequest?.requesterId,
      pendingDraw: pendingDraw,
      penaltyStarterId: penaltyStarterId,
      clockwise: clockwise,
      skipCount: skipCount,
      pendingJumpSkips: jumpWindow?.skipCount ?? 0,
      jumpInitiatorId: jumpWindow?.initiatorId,
      jumpExpiresAt: jumpWindow?.expiresAt,
      pendingKickToggles: kickWindow?.toggleCount ?? 0,
      kickInitiatorId: kickWindow?.initiatorId,
      kickExpiresAt: kickWindow?.expiresAt,
      nikoPending: nikoPending.toList(),
      nikoDeclared: nikoDeclared.toList(),
      waitingForWinnerConfirmation: waitingForWinnerConfirmation,
      questionSuit: null,
      questionAnswerRank: null,
      requiredJokerColor: null,
      comboOwnerId: null,
      comboRank: null,
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

  const RuleOutcome._({
    required this.isValid,
    required this.state,
    required this.timeline,
    this.reason,
    this.instruction,
    this.advanceTurn = true,
    this.startJumpTimer = false,
    this.startKickTimer = false,
  });

  factory RuleOutcome.invalid(RuleState state, String reason) {
    return RuleOutcome._(
      isValid: false,
      state: state,
      timeline: const [],
      reason: reason,
      advanceTurn: false,
    );
  }

  factory RuleOutcome.valid({
    required RuleState state,
    List<String>? timeline,
    String? instruction,
    bool advanceTurn = true,
    bool startJumpTimer = false,
    bool startKickTimer = false,
  }) {
    return RuleOutcome._(
      isValid: true,
      state: state,
      timeline: timeline ?? const [],
      instruction: instruction,
      advanceTurn: advanceTurn,
      startJumpTimer: startJumpTimer,
      startKickTimer: startKickTimer,
    );
  }
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
        'Select at least one card.',
      );
    }

    final ruleState = RuleState.fromGame(game);

    if (ruleState.waitingForWinnerConfirmation) {
      return RuleOutcome.invalid(
        ruleState,
        'Round review in progress — wait for confirmations.',
      );
    }

    final now = DateTime.now();
    final top = game.discardPile.isNotEmpty
        ? game.discardPile.last
        : game.drawPile.last;

    if (ruleState.jumpWindow != null && now.isBefore(ruleState.jumpWindow!.expiresAt)) {
      return _handleJumpCancel(ruleState, player, cards);
    }
    if (ruleState.kickWindow != null && now.isBefore(ruleState.kickWindow!.expiresAt)) {
      return _handleKickCancel(ruleState, player, cards);
    }

    final first = cards.first;

    final forcedRequest = ruleState.aceRequest;
    if (forcedRequest != null) {
      final isRequiredPlayer = player.uid != forcedRequest.requesterId;
      final matchesRequest =
          first.rank == forcedRequest.rank && first.suit == forcedRequest.suit;
      final cancelsWithAce = first.rank == Rank.ace;
      if (isRequiredPlayer && !matchesRequest && !cancelsWithAce) {
        return RuleOutcome.invalid(
          ruleState,
          'Play ${forcedRequest.rank.label}${_describeSuit(forcedRequest.suit)} or cancel with an Ace.',
        );
      }
    }

    if (ruleState.pendingDraw > 0 && !first.isPenaltyCard && !first.isAce) {
      return RuleOutcome.invalid(
        ruleState,
        'Continue the penalty with 2, 3, or Joker or cancel it with an Ace.',
      );
    }

    if (first.isAceOfSpades) {
      return _handleAceOfSpades(ruleState, player, cards, aceRequest);
    }
    if (first.isAce) {
      return _handleOtherAce(ruleState, player, cards);
    }
    if (first.isPenaltyCard) {
      return _handlePenalty(ruleState, player, cards, top);
    }
    if (first.isQuestionCard) {
      return _handleQuestion(ruleState, player, cards, top);
    }
    if (first.isSkip) {
      return _handleJump(ruleState, player, cards, top);
    }
    if (first.rank == Rank.king) {
      return _handleKick(ruleState, player, cards, top);
    }
    return _handleOrdinary(ruleState, player, cards, top);
  }

  RuleOutcome applyJumpExpiry(GameState game) {
    final state = RuleState.fromGame(game);
    final window = state.jumpWindow;
    if (window == null) {
      return RuleOutcome.invalid(state, 'No jump pending.');
    }
    if (DateTime.now().isBefore(window.expiresAt)) {
      return RuleOutcome.invalid(state, 'Jump cancel window still active.');
    }
    final updated = state.copyWith(
      skipCount: window.skipCount,
      jumpWindow: null,
    );
    final count = window.skipCount;
    return RuleOutcome.valid(
      state: updated,
      timeline: [
        'Jump stands – skipping $count ${count == 1 ? 'person' : 'people'}.',
      ],
      instruction: 'Skip $count ${count == 1 ? 'player' : 'players'} then play.',
      advanceTurn: true,
    );
  }

  RuleOutcome applyKickExpiry(GameState game) {
    final state = RuleState.fromGame(game);
    final window = state.kickWindow;
    if (window == null) {
      return RuleOutcome.invalid(state, 'No kickback pending.');
    }
    if (DateTime.now().isBefore(window.expiresAt)) {
      return RuleOutcome.invalid(state, 'Kickback cancel window still active.');
    }
    var direction = state.clockwise;
    for (var i = 0; i < window.toggleCount; i++) {
      direction = !direction;
    }
    final updated = state.copyWith(
      clockwise: direction,
      kickWindow: null,
    );
    final toggles = window.toggleCount;
    final descriptor = direction ? 'clockwise' : 'counterclockwise';
    final outcomeDescription = toggles.isOdd
        ? 'direction reversed'
        : 'direction unchanged';
    return RuleOutcome.valid(
      state: updated,
      timeline: [
        'Kickback stands – $outcomeDescription.',
      ],
      instruction: 'Play continues $descriptor.',
      advanceTurn: true,
    );
  }

  static bool winningHand(List<KadiCard> hand) {
    if (hand.isEmpty) return false;
    return hand.every((card) => _ordinaryRanks.contains(card.rank));
  }

  RuleOutcome _handleJumpCancel(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
  ) {
    final window = state.jumpWindow!;
    if (cards.length != 1 || !cards.first.isSkip) {
      return RuleOutcome.invalid(
        state,
        'Only a single J may cancel the jump.',
      );
    }
    if (player.uid == window.initiatorId) {
      return RuleOutcome.invalid(
        state,
        'You cannot cancel your own jump.',
      );
    }
    final updated = state.copyWith(
      jumpWindow: null,
      skipCount: 0,
    );
    return RuleOutcome.valid(
      state: updated,
      timeline: ['${player.name} canceled the jump.'],
      instruction: 'Play continues from ${_describeCard(cards.first)}.',
      advanceTurn: true,
    );
  }

  RuleOutcome _handleKickCancel(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
  ) {
    final window = state.kickWindow!;
    if (cards.length != 1 || cards.first.rank != Rank.king) {
      return RuleOutcome.invalid(
        state,
        'Only a single K may cancel the kickback.',
      );
    }
    if (player.uid == window.initiatorId) {
      return RuleOutcome.invalid(
        state,
        'You cannot cancel your own kickback.',
      );
    }
    final updated = state.copyWith(
      kickWindow: null,
    );
    final descriptor = state.clockwise ? 'clockwise' : 'counterclockwise';
    return RuleOutcome.valid(
      state: updated,
      timeline: ['${player.name} canceled the kickback.'],
      instruction: 'Direction stays $descriptor.',
      advanceTurn: true,
    );
  }

  RuleOutcome _handleAceOfSpades(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
    AceRequest? request,
  ) {
    if (cards.length != 1) {
      return RuleOutcome.invalid(state, 'A♠ must be played alone.');
    }
    if (request == null) {
      return RuleOutcome.invalid(
        state,
        'Declare the exact card for the Ace of Spades.',
      );
    }
    final updated = state.copyWith(
      pendingDraw: 0,
      penaltyStarterId: null,
      forcedSuit: null,
      aceRequest: AceRequest(
        requesterId: player.uid,
        rank: request.rank,
        suit: request.suit,
      ),
    );
    final label = '${request.rank.label}${_describeSuit(request.suit)}';
    return RuleOutcome.valid(
      state: updated,
      timeline: [
        '${player.name} canceled penalties with A♠ and requested $label.',
      ],
      instruction: 'Next player must play $label or draw 1 card.',
    );
  }

  RuleOutcome _handleOtherAce(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
  ) {
    if (cards.length != 1) {
      return RuleOutcome.invalid(state, 'Aces cannot be combined.');
    }
    final card = cards.first;
    final clearsPenalty = state.pendingDraw > 0;
    final clearsRequest = state.aceRequest != null;
    final updated = state.copyWith(
      pendingDraw: 0,
      penaltyStarterId: null,
      forcedSuit: card.suit,
      aceRequest: null,
    );
    final timeline = <String>[];
    if (clearsPenalty) {
      timeline.add('${player.name} canceled the penalty.');
    }
    if (clearsRequest) {
      timeline.add('${player.name} canceled the request.');
    }
    if (timeline.isEmpty) {
      timeline.add('${player.name} changed suit to ${_describeSuit(card.suit)}.');
    } else {
      timeline.add('${player.name} set play to ${_describeSuit(card.suit)}.');
    }
    return RuleOutcome.valid(
      state: updated,
      timeline: timeline,
      instruction: 'Next player must follow ${_describeSuit(card.suit)} or play an Ace.',
    );
  }

  RuleOutcome _handlePenalty(
    RuleState state,
    KadiPlayer player,
    List<KadiCard> cards,
    KadiCard top,
  ) {
    if (!_validPenaltySequence(state, top, cards)) {
      return RuleOutcome.invalid(
        state,
        'Penalty cards must match by suit, rank, or joker colour.',
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
    return RuleOutcome.valid(
      state: updated,
      timeline: [
        '${player.name} stacked penalty to +$total.',
      ],
      instruction:
          'Next player must add to the penalty or draw $total ${total == 1 ? 'card' : 'cards'}.',
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
        'Resolve penalties before asking questions.',
      );
    }
    final queue = Queue<KadiCard>.of(cards);
    final questions = <KadiCard>[];
    final answers = <KadiCard>[];
    while (queue.isNotEmpty) {
      final card = queue.removeFirst();
      if (card.isQuestionCard && answers.isEmpty) {
        questions.add(card);
      } else {
        answers.add(card);
      }
    }
    if (questions.isEmpty || answers.isEmpty) {
      return RuleOutcome.invalid(
        state,
        'Question cards must be followed by answers in the same play.',
      );
    }
    if (!_allSameRank(questions)) {
      return RuleOutcome.invalid(
        state,
        'Combine questions of the same rank only.',
      );
    }
    final firstQuestion = questions.first;
    if (!_matchesTop(firstQuestion, top, state.forcedSuit)) {
      return RuleOutcome.invalid(
        state,
        'First question must match pile by suit or rank.',
      );
    }
    final firstAnswer = answers.first;
    if (!_ordinaryRanks.contains(firstAnswer.rank)) {
      return RuleOutcome.invalid(
        state,
        'Answers must be ordinary cards.',
      );
    }
    if (firstAnswer.suit != questions.last.suit) {
      return RuleOutcome.invalid(
        state,
        'First answer must follow the suit of the last question.',
      );
    }
    if (!_allSameRank(answers)) {
      return RuleOutcome.invalid(
        state,
        'All answers must share the same rank.',
      );
    }
    final answerRank = answers.first.rank;
    for (final card in answers) {
      if (!_ordinaryRanks.contains(card.rank) || card.rank != answerRank) {
        return RuleOutcome.invalid(
          state,
          'Answers must repeat the chosen ordinary rank.',
        );
      }
    }
    final updated = state.copyWith(
      forcedSuit: null,
      aceRequest: null,
    );
    final questionLabel = questions.map(_describeCard).join(', ');
    final answerLabel = answers.map(_describeCard).join(', ');
    return RuleOutcome.valid(
      state: updated,
      timeline: [
        '${player.name} played $questionLabel and answered with $answerLabel.',
      ],
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
        'Finish the penalty chain before jumping.',
      );
    }
    if (cards.any((card) => !card.isSkip)) {
      return RuleOutcome.invalid(
        state,
        'Jump combos may only contain Js.',
      );
    }
    if (!_matchesTop(cards.first, top, state.forcedSuit)) {
      return RuleOutcome.invalid(
        state,
        'J must match the pile by suit or rank.',
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
    return RuleOutcome.valid(
      state: updated,
      timeline: [
        '${player.name} jumped $skipCount ${skipCount == 1 ? 'person' : 'people'}.',
      ],
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
        'Finish the penalty chain before reversing direction.',
      );
    }
    if (cards.any((card) => card.rank != Rank.king)) {
      return RuleOutcome.invalid(
        state,
        'Kickback combos may only contain Ks.',
      );
    }
    if (!_matchesTop(cards.first, top, state.forcedSuit)) {
      return RuleOutcome.invalid(
        state,
        'K must match the pile by suit or rank.',
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
    final countLabel =
        '$toggles ${toggles == 1 ? 'time' : 'times'}';
    return RuleOutcome.valid(
      state: updated,
      timeline: [
        '${player.name} triggered a kickback $countLabel.',
      ],
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
          'Use ranks 4,5,6,7,9,10 for ordinary plays.',
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

  bool _validPenaltySequence(
    RuleState state,
    KadiCard top,
    List<KadiCard> cards,
  ) {
    if (cards.any((card) => !_penaltyRanks.contains(card.rank))) {
      return false;
    }
    final sequence = Queue<KadiCard>.of(cards);
    var reference = top;
    var forcedSuit = state.forcedSuit;
    while (sequence.isNotEmpty) {
      final card = sequence.removeFirst();
      if (!_penaltyMatches(card, reference, forcedSuit)) {
        return false;
      }
      reference = card;
      forcedSuit = null;
    }
    return true;
  }

  bool _penaltyMatches(KadiCard card, KadiCard reference, Suit? forcedSuit) {
    if (forcedSuit != null) {
      if (card.isJoker) {
        return _jokerMatchesSuit(card.color, forcedSuit);
      }
      return card.suit == forcedSuit;
    }
    if (reference.isJoker) {
      if (card.isJoker) {
        return card.color == reference.color;
      }
      return _jokerMatchesSuit(reference.color, card.suit);
    }
    if (card.isJoker) {
      return _jokerMatchesSuit(card.color, reference.suit);
    }
    return card.rank == reference.rank || card.suit == reference.suit;
  }

  bool _jokerMatchesSuit(CardColor color, Suit suit) {
    switch (suit) {
      case Suit.hearts:
      case Suit.diamonds:
        return color == CardColor.red;
      case Suit.clubs:
      case Suit.spades:
        return color == CardColor.black;
      case Suit.joker:
        return true;
    }
  }

  bool _matchesTop(KadiCard card, KadiCard top, Suit? forcedSuit) {
    if (forcedSuit != null) {
      if (card.isJoker) {
        return _jokerMatchesSuit(card.color, forcedSuit);
      }
      return card.suit == forcedSuit || card.rank == Rank.ace;
    }
    if (card.isJoker) return true;
    if (top.isJoker) {
      return _jokerMatchesSuit(card.color, top.suit) || card.rank == top.rank;
    }
    return card.suit == top.suit || card.rank == top.rank;
  }

  bool _allSameRank(List<KadiCard> cards) {
    if (cards.isEmpty) return true;
    final rank = cards.first.rank;
    return cards.every((card) => card.rank == rank);
  }
}
