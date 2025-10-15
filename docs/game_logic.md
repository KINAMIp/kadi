# KADI Core Game Logic

This document captures the authoritative reference for how cards behave in Tucheze Kadi. Use it alongside the rule engine implementation to keep game behaviour and UI cues aligned.

## Table of Contents
- [Terminology](#terminology)
- [Turn Flow](#turn-flow)
- [Special Card Reference](#special-card-reference)
  - [A♠ — The Commander](#a♠--the-commander)
  - [A♦, A♥, A♣ — The Negotiators](#a♦-a♥-a♣--the-negotiators)
  - [2 — Pick Two](#2--pick-two)
  - [3 — Pick Three](#3--pick-three)
  - [4 / 5 / 6 / 7 — Calm Answers](#4--5--6--7--calm-answers)
  - [8 — Question](#8--question)
  - [9 / 10 — Neutral Answers](#9--10--neutral-answers)
  - [J — Jump](#j--jump)
  - [Q — Question](#q--question)
  - [K — Kickback](#k--kickback)
  - [Jokers — Punishers](#jokers--punishers)
- [Niko Kadi Win Condition](#niko-kadi-win-condition)
- [Penalty Resolution Rules](#penalty-resolution-rules)
- [Combos](#combos)

## Terminology
- **Top card** – the last card in the discard pile.
- **Pending pick** – number of cards the next player must draw if they cannot respond to the active penalty.
- **Question mode** – state triggered by 8s and Queens that requires an answer card before play advances.
- **Forced suit** – suit selected by an Ace when it is used to change play.
- **Requested card** – rank (and optionally suit) demanded by the Ace of Spades.

## Turn Flow
1. Active player must either:
   - Obey pending penalties (stack or cancel),
   - Answer questions, or
   - Follow normal matching rules (rank/suit) when no modifiers are active.
2. After a valid play, resolve the card effect to update penalties, direction, questions, and other state.
3. Multi-card combos resolve sequentially. Each card must be valid at the moment it is played.
4. Pop-out timers (jump/kickback cancel, Niko Kadi) pause the global turn countdown.

## Special Card Reference

### A♠ — The Commander
- Cancels all penalties and optionally requests a specific card.
- When requesting, the player states the target rank and suit (e.g. “Queen of Hearts”).
- The next player must play the requested card if they hold it; otherwise they draw a single card.
- If the requested card is played, its suit/rank govern subsequent turns.

### A♦, A♥, A♣ — The Negotiators
- Dual purpose based on context:
  1. **Cancel penalty chains** (2s, 3s, Jokers) resetting `pendingPick` to zero and clearing forced/requested requirements.
  2. **Change suit** when no penalty is active. The chosen suit becomes the required suit for the next player.

### 2 — Pick Two
- Adds +2 to `pendingPick` unless canceled by an Ace.
- Stackable with additional 2s; each adds +2.
- When a player draws due to the penalty, the 2 remains the top card and standard matching resumes from that card.

### 3 — Pick Three
- Adds +3 to `pendingPick` and stacks with other 3s and 2s.
- Cancelled only by an Ace.
- If the next player draws, the 3 remains the top card for suit/rank matching.

### 4 / 5 / 6 / 7 — Calm Answers
- Neutral cards for normal play.
- Valid responses to question cards (8 or Q) when the suit matches or rank matches the top card.

### 8 — Question
- Initiates question mode asking for an answer card.
- Acceptable answers: 4, 5, 6, 7, 9, 10 matching either suit or rank of the top card.
- Can be played as a combo; each additional 8 extends the question until answered.
- If the active player cannot answer, they must pick one card and question mode ends.

### 9 / 10 — Neutral Answers
- Behave like Calm Answer cards.
- Included in the list of valid responses during question mode.

### J — Jump
- Skips the next player’s turn.
- Multiple Jacks in a combo skip additional players.
- Triggers a 5-second cancel window; only non-skipped opponents may cancel with their own Jack.
- Players cannot cancel their own jump.

### Q — Question
- Identical to the behaviour of 8s.
- Can form combos and require answer cards (4,5,6,7,9,10) that match suit or rank.

### K — Kickback
- Reverses direction of play.
- Multiple Kings toggle direction multiple times (effectively cancelling out in pairs).
- Triggers a 5-second cancel window; other players may cancel with their own King.

### Jokers — Punishers
- Red Joker playable on red suits; Black Joker on black suits.
- Adds +5 to `pendingPick` and stacks with 2s/3s/Jokers.
- Next player must match Joker color when responding with another Joker.
- Any Ace cancels the entire penalty chain.

## Niko Kadi Win Condition
- Eligible ranks: 4, 5, 6, 7, 9, 10.
- When a player’s remaining hand consists exclusively of eligible cards, show a **“Niko Kadi?”** pop-out for 5 seconds.
- A successful declaration displays a badge under the player profile.
- To win, the final card(s) must match top suit/rank or satisfy an Ace request. Jokers cannot be part of the final play.

## Penalty Resolution Rules
- Penalty chains (2/3/Joker) continue accumulating until a player either stacks another penalty card or an Ace cancels them.
- When a player draws instead of responding, the most recent penalty card remains on top and normal matching rules resume from it.
- Ace cancellation also clears forced suits, requested ranks, active Jokers, and skip cancel windows.

## Combos
- Players may drop multiple cards of the same rank in one turn (e.g. double 4s).
- Each card in the combo must respect suit/rank matching at the time it is played and must individually satisfy question or penalty requirements.
- After the combo resolves, apply the effect of each card in sequence to update turn direction, skips, questions, or penalties.
