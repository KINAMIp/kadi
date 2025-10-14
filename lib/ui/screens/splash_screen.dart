import 'package:flutter/material.dart';
import 'lobby_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _scaleAnimation = Tween<double>(begin: 1.2, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 4), () {
      Navigator.of(context).pushReplacement(_createRoute());
    });
  }

  Route _createRoute() {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 1200),
      pageBuilder: (context, animation, secondaryAnimation) => const LobbyScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const beginOffset = Offset(0.0, 0.2);
        const endOffset = Offset.zero;
        final tween = Tween(begin: beginOffset, end: endOffset)
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
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Fade-in card logo
                    Image.asset(
                      'assets/images/aces.png',
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "KADI",
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 60,
                      height: 3,
                      color: Colors.amberAccent,
                    ),
                  ],
                ),
              ),
              // Footer text
              const Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Text(
                  "© 2025 Kinami LLC. All rights reserved.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}