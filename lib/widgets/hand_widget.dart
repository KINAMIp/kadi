import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

class TurnTimerWidget extends StatefulWidget {
  final Duration duration;
  final VoidCallback onTimeout;
  final bool isRunning;

  const TurnTimerWidget({
    super.key,
    required this.duration,
    required this.onTimeout,
    required this.isRunning,
  });

  @override
  State<TurnTimerWidget> createState() => _TurnTimerWidgetState();
}

class _TurnTimerWidgetState extends State<TurnTimerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(TurnTimerWidget old) {
    super.didUpdateWidget(old);
    if (widget.isRunning && !old.isRunning) {
      _start();
    } else if (!widget.isRunning && old.isRunning) {
      _controller.reset();
      _tick?.cancel();
    }
  }

  void _start() {
    _controller.forward(from: 0);
    _tick?.cancel();
    _tick = Timer(widget.duration, widget.onTimeout);
  }

  @override
  void dispose() {
    _controller.dispose();
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) {
          return CircularProgressIndicator(
            strokeWidth: 4,
            value: 1.0 - _controller.value,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isRunning ? AppColors.highlight : Colors.white30,
            ),
          );
        },
      ),
    );
  }
}