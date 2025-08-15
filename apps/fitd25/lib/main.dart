import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:fitd25/firebase_options.dart';
import 'package:fitd25/override_en_timeago.dart';
import 'package:fitd25/screens/admin_screen.dart';
import 'package:fitd25/screens/player_selection_screen.dart';
import 'package:fitd25/screens/show_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    show setDefaultLocale, setLocaleMessages;

Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  setLocaleMessages('en', OverrideEnTimeAgo());
  setDefaultLocale('en');
  await initializeDateFormatting('sv_SE');
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'US'), Locale('sv', 'SE')],
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/admin':
            return MaterialPageRoute(builder: (context) => const AdminScreen());
          case '/show':
            return MaterialPageRoute(builder: (context) => const ShowScreen());
          default:
            return MaterialPageRoute(
              builder: (context) => const PlayerSelectionScreen(),
            );
        }
      },
    );
  }
}
