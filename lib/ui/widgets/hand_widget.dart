import 'package:flutter/material.dart';

import '../../models/kadi_card.dart';
import 'card_widget.dart';

class HandWidget extends StatefulWidget {
  final List<KadiCard> cards;
  final bool faceUp;
  final void Function(KadiCard)? onPlayTap;

  const HandWidget({
    super.key,
    required this.cards,
    this.faceUp = true,
    this.onPlayTap,
  });

  @override
  State<HandWidget> createState() => _HandWidgetState();
}

class _HandWidgetState extends State<HandWidget> {
  final ScrollController _controller = ScrollController();
  bool _showLeftGlow = false;
  bool _showRightGlow = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateIndicators);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndicators());
  }

  @override
  void didUpdateWidget(covariant HandWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateIndicators());
  }

  void _updateIndicators() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final canScroll = position.maxScrollExtent > 0;
    final left = position.pixels > 2;
    final right = position.pixels < position.maxScrollExtent - 2;
    if (canScroll) {
      if (left != _showLeftGlow || right != _showRightGlow) {
        setState(() {
          _showLeftGlow = left;
          _showRightGlow = right;
        });
      }
    } else if (_showLeftGlow || _showRightGlow) {
      setState(() {
        _showLeftGlow = false;
        _showRightGlow = false;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_updateIndicators);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    final showThumb = cards.length * 24 > MediaQuery.of(context).size.width;
    return Stack(
      children: [
        Scrollbar(
          controller: _controller,
          thumbVisibility: showThumb,
          interactive: true,
          radius: const Radius.circular(12),
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: cards.map((c) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: KadiCardWidget(
                    card: c,
                    faceUp: widget.faceUp,
                    onTap:
                        widget.onPlayTap != null ? () => widget.onPlayTap!(c) : null,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (_showLeftGlow)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: _HandScrollIndicator(isStart: true),
          ),
        if (_showRightGlow)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: _HandScrollIndicator(isStart: false),
          ),
      ],
    );
  }
}

class _HandScrollIndicator extends StatelessWidget {
  final bool isStart;

  const _HandScrollIndicator({required this.isStart});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 28,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(isStart ? 0.18 : 0.0),
              Colors.white.withOpacity(isStart ? 0.0 : 0.18),
            ],
            begin: isStart ? Alignment.centerLeft : Alignment.centerRight,
            end: isStart ? Alignment.centerRight : Alignment.centerLeft,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          isStart ? Icons.keyboard_arrow_left : Icons.keyboard_arrow_right,
          color: Colors.white.withOpacity(0.7),
        ),
      ),
    );
  }
}