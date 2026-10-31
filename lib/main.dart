import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BubbleBlastApp());
}
class BubbleBlastApp extends StatelessWidget {
  const BubbleBlastApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bubble Blast Adventure',

      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        scaffoldBackgroundColor: const Color(0xFF120B3D),
      ),
      // IMPORTANT:
      // SplashScreen MUST be the first screen.
      home: const SplashScreen(),
    );
  }
}