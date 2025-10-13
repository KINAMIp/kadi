import 'package:flutter/material.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/lobby_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const KadiApp());
}

class KadiApp extends StatelessWidget {
  const KadiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kadi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        brightness: Brightness.dark,
      ),
      routes: {
        '/': (_) => const SplashScreen(),
        '/lobby': (_) => const LobbyScreen(),
      },
    );
  }
}