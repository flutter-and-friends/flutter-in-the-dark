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
      home: const Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}

const alek = AssetImage('assets/photos/alek.png');
const lukas = AssetImage('assets/photos/lukas.png');
const johannes = AssetImage('assets/photos/johannes.png');
const dash = AssetImage('assets/photos/dash.png');
