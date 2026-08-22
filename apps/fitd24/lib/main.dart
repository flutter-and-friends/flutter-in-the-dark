import 'package:fitd24/challenges/final/final_card.dart';
import 'package:fitd24/challenges/first.dart';
import 'package:fitd24/challenges/fourth.dart';
import 'package:fitd24/challenges/second.dart';
import 'package:fitd24/challenges/third.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      routes: {
        HomeScreen.path: (_) => const HomeScreen(),
        '/first': (_) => const First(),
        '/second': (_) => const Second(),
        '/third': (_) => const Third(),
        '/fourth': (_) => const Fourth(),
        Final.path: (_) => const Final(),
      },
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  static const path = "/home";

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
        child: ListView(
          children: [
            const Center(
              child: Text(
                "Challenges:",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/first'),
              child: const Text("First"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/second'),
              child: const Text("Second"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/third'),
              child: const Text("Third"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, '/fourth'),
              child: const Text("Fourth"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, Final.path),
              child: const Text("Final 🎉"),
            ),
          ],
        ),
      ),
    );
  }
}
