import 'package:flutter/material.dart';

class HomeMenuScreen extends StatelessWidget {
  const HomeMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('KADI MENU')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                textStyle: const TextStyle(fontSize: 20),
              ),
              onPressed: () {
                Navigator.pushNamed(context, '/lobby');
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.info_outline),
              label: const Text('Rules'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                textStyle: const TextStyle(fontSize: 20),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const _RulesDialog(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RulesDialog extends StatefulWidget {
  const _RulesDialog();

  @override
  State<_RulesDialog> createState() => _RulesDialogState();
}

class _RulesDialogState extends State<_RulesDialog> {
  final ScrollController _controller = ScrollController();
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  void _handleScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final shouldShow = position.maxScrollExtent > 0 &&
        position.pixels < position.maxScrollExtent - 8;
    if (shouldShow != _showHint) {
      setState(() {
        _showHint = shouldShow;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final bulletStyle = textTheme.bodyMedium?.copyWith(height: 1.4);
    final rules = [
      'Match suit or rank to stay in play and discard everything first.',
      'Combo answers are welcome — keep chaining cards of the same rank.',
      'All Aces except spades can cancel penalties or change the suit instantly.',
      'The Ace of Spades may request a specific card (rank + suit).',
      'Jokers must follow the color of the card they land on.',
      'Jacks jump one player at a time. Two Jacks = two skips. Kings kick back one step each.',
      'Jacks and Kings can be comboed, giving rivals a 5 second window to cancel with a Five.',
      'Remember to shout “Niko Kadi!” with one ordinary card left.',
    ];

    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: const Text(
        'Kadi Rulebook',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 420,
        child: Stack(
          children: [
            Scrollbar(
              controller: _controller,
              thumbVisibility: true,
              radius: const Radius.circular(12),
              child: SingleChildScrollView(
                controller: _controller,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎯 Goal: Clear your hand before anyone else.',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      for (final rule in rules)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(color: Colors.amberAccent)),
                              Expanded(
                                child: Text(
                                  rule,
                                  style: bulletStyle?.copyWith(color: Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        '⚠️ Forget to call “Niko Kadi!” before the next play and you draw two cards.',
                        style: bulletStyle?.copyWith(
                          color: Colors.redAccent.shade100,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_showHint)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Column(
                  children: const [
                    Icon(Icons.swipe_down_alt, color: Colors.white70),
                    Text(
                      'Scroll for more tips',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.amberAccent)),
        ),
      ],
    );
  }
}