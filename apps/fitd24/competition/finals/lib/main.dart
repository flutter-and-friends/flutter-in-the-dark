import 'package:flutter/material.dart';
import 'package:vector_graphics/vector_graphics_compat.dart';

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

final cardBackground = createCompatVectorGraphic(
  loader: const AssetBytesLoader(
    'assets/svgs/ff_card_background.svg',
  ),
);

final kulturhuset = Image.asset(
  'assets/images/kulturhuset.png',
);

final dash = Image.asset(
  'assets/photos/dash.png',
);

final ffLogo = createCompatVectorGraphic(
  loader: const AssetBytesLoader(
    'assets/svgs/ff_logo.svg',
  ),
);
