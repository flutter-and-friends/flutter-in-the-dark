import 'package:flutter_in_the_dark/build_marker.dart';
import 'package:flutter_in_the_dark/override_en_timeago.dart';
import 'package:flutter_in_the_dark/room/room_sync.dart';
import 'package:flutter_in_the_dark/screens/admin_screen.dart';
import 'package:flutter_in_the_dark/screens/burn_test_screen.dart';
import 'package:flutter_in_the_dark/screens/player_selection_screen.dart';
import 'package:flutter_in_the_dark/screens/show_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timeago_flutter/timeago_flutter.dart'
    show setDefaultLocale, setLocaleMessages;

Future<void> main() async {
  // Build marker first: every route logs hash+timestamp to the browser
  // console so a stale deploy-cache page is identifiable at a glance.
  logBuildMarker();
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  setLocaleMessages('en', OverrideEnTimeAgo());
  setDefaultLocale('en');
  await initializeDateFormatting('sv_SE');

  // One room-state connection shared by every route (replaces Firestore).
  final roomSync = RoomSync()..start();

  runApp(MainApp(roomSync: roomSync));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key, required this.roomSync});

  final RoomSync roomSync;

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
        // Session role-scoping (WI-012): the stored session is a PLAYER
        // identity (SessionStore, player-scoped key). /admin is
        // network-gated, not identity-gated, and /show never joins — so
        // NEITHER reads the player session; only the player route does. This
        // keeps an /admin or /show tab in the same browser (shared
        // localStorage) from picking up a player identity and rendering as
        // a joined contestant.
        // Match on the path only: a deep link with a query string (e.g.
        // the burn-reveal debug knobs `?burnDebug=1&burnSlow=…`) must still
        // resolve to its route, not fall through to the default.
        switch (Uri.parse(settings.name ?? '/').path) {
          case '/admin':
            return MaterialPageRoute(
              builder: (context) => AdminScreen(roomSync: roomSync),
            );
          case '/show':
            return MaterialPageRoute(
              builder: (context) => ShowScreen(roomSync: roomSync),
            );
          // Standalone looping burn-reveal demo: no room state, no SSE —
          // must NOT touch `roomSync` (this route exists so the animation
          // can be steered on a device where the backend is unreachable).
          case '/test':
          case '/burn_test':
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => BurnTestPage.fromSettings(settings),
            );
          // Burn-free steering harness for the /show overlay widgets
          // (pill / time-over banner) — screenshot without room_service.
          case '/show_mock':
            return MaterialPageRoute(
              settings: settings,
              builder: (context) => ShowMockPage.fromSettings(settings),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => PlayerSelectionScreen(roomSync: roomSync),
            );
        }
      },
    );
  }
}
