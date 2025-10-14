import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'services/online_service.dart';
import 'ui/screens/lobby_screen.dart';
import 'ui/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Prewarm the online service so FirebaseAuth signs the player in quickly.
  OnlineService();
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