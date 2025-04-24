import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Add this line
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:beamer/beamer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/route/404.dart';
import 'package:terrestrial_forest_monitor/screens/admin-permissions.dart';
import 'package:terrestrial_forest_monitor/screens/admin.dart';
import 'package:terrestrial_forest_monitor/screens/brick.dart';
import 'package:terrestrial_forest_monitor/screens/headless.dart';
import 'package:terrestrial_forest_monitor/screens/home.dart';
import 'package:terrestrial_forest_monitor/screens/settings.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/providers/theme-mode.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

import 'package:intl/intl.dart';
import 'package:terrestrial_forest_monitor/services/attachment-helper.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/transitions/no-animation.dart';
//import 'package:hive_flutter/hive_flutter.dart';

//import 'package:terrestrial_forest_monitor/no-animation.dart';

// BRICK
import 'package:terrestrial_forest_monitor/brick/repository.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;

final routerDelegate = BeamerDelegate(
  notFoundPage: BeamPage(key: ValueKey('not-found'), title: 'Not Found', child: Error404()),
  transitionDelegate: const NoAnimationTransitionDelegate(),
  updateListenable: ValueNotifier<bool>(false), // Prevents navigation animations
  locationBuilder:
      RoutesLocationBuilder(
        routes: {
          '*': (context, state, data) => BeamPage(key: ValueKey('home-${DateTime.now()}'), title: 'TFM', child: Home(), type: BeamPageType.noTransition),
          '/settings': (context, state, data) => BeamPage(key: ValueKey('settings-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: Settings(), type: BeamPageType.noTransition),
          '/admin': (context, state, data) => BeamPage(key: ValueKey('admin-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: AdminScreen(), type: BeamPageType.noTransition),
          '/brick': (context, state, data) => BeamPage(key: ValueKey('admin-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: BrickScreen(), type: BeamPageType.noTransition),
          '/admin-permissions': (context, state, data) => BeamPage(key: ValueKey('admin-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: AdminPermissionsScreen(), type: BeamPageType.noTransition),
          '/headless': (context, state, data) => BeamPage(key: ValueKey('headless-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: StatelessTest(), type: BeamPageType.noTransition),
        },
      ).call,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  // set default Locale to Language provider
  final String defaultLocale = Intl.getCurrentLocale(); // = Platform.localeName;
  final Brightness brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
  final ThemeMode initialThemeMode = brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('Error loading .env file: $e');
  }

  // Save Map offline
  if (!kIsWeb) {
    print('Offline Map Cache');
    await FMTCObjectBoxBackend().initialise();
    await FMTCStore('wms_dtk25__').manage.create();
    await FMTCStore('wms_dop__').manage.create();
  }

  //await Hive.initFlutter();
  //await GetStorage.init();

  try {
    await openDatabase();
    await initializeAttachmentQueue(db);
  } catch (e) {
    print('Error opening database: $e');
  }
  //await Repository.configure(databaseFactory);
  //await Repository().initialize();

  final gpsProvider = GpsPositionProvider();
  gpsProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Language(Locale(defaultLocale))),
        ChangeNotifierProvider(create: (_) => ThemeModeProvider(initialThemeMode)),

        //ChangeNotifierProvider(create: (_) => ApiLog(token)),
        //ChangeNotifierProvider(create: (_) => JsonSchemaProvider()),
        ChangeNotifierProvider(create: (_) => MapState()),
        ChangeNotifierProvider(create: (_) => gpsProvider),
      ],
      child: Layout(),
    ),
  );
  //context.read<Language>().setLocale(Locale(defaultLocale));
}

class Layout extends StatelessWidget {
  Layout({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final String languageProvider = Provider.of<Language>(context).locale.toString();
    String selectedLanguage = languageProvider.split('_')[0];

    final themeProvider = Provider.of<ThemeModeProvider>(context);

    //context.watch<MapState>().mapOpen

    return MaterialApp.router(
      title: 'Terrestrial Forest Monitor',

      // LOCALIZATION
      locale: Locale(selectedLanguage),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      // THEME
      theme: ThemeData(
        scaffoldBackgroundColor: Color(0xFFeeeeee),
        // https://stackoverflow.com/questions/71597644/flutter-web-remove-default-page-transition-on-named-routes
        pageTransitionsTheme: PageTransitionsTheme(
          builders: kIsWeb ? {for (final platform in TargetPlatform.values) platform: const NoTransitionsBuilder()} : {TargetPlatform.android: ZoomPageTransitionsBuilder(), TargetPlatform.iOS: CupertinoPageTransitionsBuilder()},
        ),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green, brightness: Brightness.light),
        primaryColor: const Color(0xFFC3E399),
        appBarTheme: AppBarTheme(color: const Color(0xFFC3E399)),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        scaffoldBackgroundColor: Color(0xFF333333),
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.green, brightness: Brightness.dark),
        primaryColor: const Color(0xFFC3E399),
        appBarTheme: AppBarTheme(color: const Color.fromARGB(255, 224, 241, 203), foregroundColor: Colors.black), // color: const Color(0xFFC3E399), foregroundColor: Colors.black
        bottomNavigationBarTheme: BottomNavigationBarThemeData(backgroundColor: const Color(0xFFC3E399), selectedItemColor: Colors.black, unselectedItemColor: Colors.black),
        useMaterial3: true,
        /* dark theme settings */
      ),

      themeMode: themeProvider.mode,
      routeInformationParser: BeamerParser(),
      routerDelegate: routerDelegate,
    );
  }
}
