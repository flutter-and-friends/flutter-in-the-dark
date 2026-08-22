import 'package:flutter/material.dart';
import 'package:fitd23/challenges/canvas.dart';
import 'package:fitd23/challenges/final_final.dart';
import 'package:fitd23/challenges/finals.dart';
import 'package:fitd23/challenges/flutter_chat.dart';
import 'package:fitd23/challenges/flutter_friend_list.dart';
import 'package:fitd23/challenges/mirror.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        HomeScreen.path: (_) => const HomeScreen(),
        FlutterFriendList.path: (_) => const FlutterFriendList(),
        Mirror.path: (_) => const Mirror(),
        FlutterChat.path: (_) => const FlutterChat(),
        CanvasHouse.path: (_) => const CanvasHouse(),
        Finals.path: (_) => const Finals(),
        FinalFinal.path: (_) => const FinalFinal(),
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
  bool finalFinal = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 100),
        child: ListView(
          children: [
            Center(
              child: InkWell(
                onTap: () {
                  setState(() {
                    finalFinal = !finalFinal;
                  });
                },
                child: const Text(
                  "Challenges:",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushNamed(context, FlutterFriendList.path),
              child: const Text("Flutter Friend List"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, CanvasHouse.path),
              child: const Text("Canvas House"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, Mirror.path),
              child: const Text("Mirror"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, FlutterChat.path),
              child: const Text("Flutter Chat"),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, Finals.path),
              child: const Text("Finals"),
            ),
            if (finalFinal) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                style: ButtonStyle(
                    backgroundColor: WidgetStateColor.resolveWith(
                  (states) => Colors.pink,
                )),
                onPressed: () => Navigator.pushNamed(context, FinalFinal.path),
                child: const Text("Lukas vs Alek 💪"),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
