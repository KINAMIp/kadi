import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lobby_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _orbitController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _fadeAnimation = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutBack),
    );

    _textOpacity = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.35, 1, curve: Curves.easeIn),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(_createRoute());
      }
    });
  }

  Route _createRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 1100),
      pageBuilder: (context, animation, secondaryAnimation) => const LobbyScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(0, 0.15), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeInOut));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(tween),
            child: child,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF040D21), Color(0xFF102542), Color(0xFF041C32)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _orbitController,
            builder: (context, child) {
              return CustomPaint(
                painter: _SparklePainter(_orbitController.value),
              );
            },
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: AnimatedBuilder(
                      animation: _orbitController,
                      builder: (context, child) {
                        final wobble = math.sin(_orbitController.value * math.pi);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: 0.45 + 0.12 * wobble,
                              child: _CardTile(
                                color: const Color(0xFFFFA000),
                                icon: Icons.favorite,
                                iconColor: Colors.red.shade900,
                              ),
                            ),
                            Transform.rotate(
                              angle: -0.35 + 0.12 * wobble,
                              child: _CardTile(
                                color: const Color(0xFFFFF59D),
                                icon: Icons.spa,
                                iconColor: Colors.green.shade800,
                              ),
                            ),
                            Transform.rotate(
                              angle: 0.05 - 0.18 * wobble,
                              child: _CardTile(
                                color: const Color(0xFFB3E5FC),
                                icon: Icons.change_circle_outlined,
                                iconColor: Colors.indigo.shade900,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: _AnimatedTitle(progress: _orbitController),
                  ),
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: const Text(
                      'Tucheze kadi',
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 1.1,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            bottom: 36,
            left: 0,
            right: 0,
            child: Text(
              '© 2025 Kinami LLC. All rights reserved',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTitle extends StatelessWidget {
  final Animation<double> progress;

  const _AnimatedTitle({required this.progress});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, child) {
        final slide = progress.value;
        return ShaderMask(
          shaderCallback: (rect) {
            return LinearGradient(
              colors: const [
                Color(0xFFFFD54F),
                Color(0xFFFF7043),
                Color(0xFF80CBC4),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1 + slide, 0),
              end: Alignment(1 + slide, 0),
            ).createShader(rect);
          },
          child: const Text(
            'KADI',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: Colors.white,
            ),
          ),
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Color iconColor;

  const _CardTile({
    required this.color,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color,
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 18, offset: Offset(0, 8)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.65), width: 1.2),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 46, color: iconColor),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double progress;

  _SparklePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final center = size.center(Offset.zero);
    for (var i = 0; i < 6; i++) {
      final angle = (progress * 2 * math.pi) + (i * math.pi / 3);
      final radius = 140 + 40 * math.sin(progress * math.pi * 2 + i);
      final offset = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawCircle(offset, 16, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}