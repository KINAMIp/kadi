import 'kadi_card.dart';

class KadiPlayer {
  final String uid;
  final String name;
  final bool isAI;
  final List<KadiCard> hand;

  KadiPlayer({
    required this.uid,
    required this.name,
    this.isAI = false,
    List<KadiCard>? hand,
  }) : hand = hand ?? [];

  KadiPlayer copyWith({
    String? uid,
    String? name,
    bool? isAI,
    List<KadiCard>? hand,
  }) =>
      KadiPlayer(
        uid: uid ?? this.uid,
        name: name ?? this.name,
        isAI: isAI ?? this.isAI,
        hand: hand ?? List<KadiCard>.from(this.hand),
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'isAI': isAI,
        'hand': hand.map((e) => e.toJson()).toList(),
      };

  factory KadiPlayer.fromJson(Map<String, dynamic> json) => KadiPlayer(
        uid: json['uid'] as String,
        name: json['name'] as String,
        isAI: (json['isAI'] ?? false) as bool,
        hand: (json['hand'] as List<dynamic>? ?? [])
            .map((e) => KadiCard.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}