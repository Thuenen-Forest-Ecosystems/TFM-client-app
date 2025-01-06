import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Add this line
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:beamer/beamer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:get_storage/get_storage.dart';
import 'package:terrestrial_forest_monitor/brick/models/cluster.model.dart';
import 'package:terrestrial_forest_monitor/brick/models/schemas.model.dart';

import 'package:terrestrial_forest_monitor/providers/json-schema.dart';
import 'package:terrestrial_forest_monitor/route/404.dart';
import 'package:terrestrial_forest_monitor/screens/admin.dart';
import 'package:terrestrial_forest_monitor/screens/headless.dart';
import 'package:terrestrial_forest_monitor/screens/home.dart';
import 'package:terrestrial_forest_monitor/screens/settings.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/providers/theme-mode.dart';

import 'package:terrestrial_forest_monitor/providers/gps-position.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:terrestrial_forest_monitor/services/api.dart';

import 'package:terrestrial_forest_monitor/services/powersync.dart';

import 'package:terrestrial_forest_monitor/transitions/no-animation.dart';

import 'package:terrestrial_forest_monitor/providers/api-log.dart';
//import 'package:hive_flutter/hive_flutter.dart';

//import 'package:terrestrial_forest_monitor/no-animation.dart';

import 'package:terrestrial_forest_monitor/brick/repository.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:brick_core/query.dart';

final routerDelegate = BeamerDelegate(
  notFoundPage: BeamPage(key: ValueKey('not-found'), title: 'Not Found', child: Error404()),
  transitionDelegate: const NoAnimationTransitionDelegate(),
  locationBuilder: RoutesLocationBuilder(
    routes: {
      // Return either Widgets or BeamPages if more customization is needed
      '*': (context, state, data) => BeamPage(
            key: ValueKey('home-${DateTime.now()}'),
            title: 'TFM',
            child: Home(),
          ),
      '/settings': (context, state, data) => BeamPage(
            key: ValueKey('settings-${DateTime.now()}'),
            title: AppLocalizations.of(context)!.settings,
            child: Settings(),
          ),
      '/admin': (context, state, data) => BeamPage(
            key: ValueKey('admin-${DateTime.now()}'),
            title: AppLocalizations.of(context)!.settings,
            child: AdminScreen(),
          ),
      '/headless': (context, state, data) => BeamPage(
            key: ValueKey('headless-${DateTime.now()}'),
            title: AppLocalizations.of(context)!.settings,
            child: StatelessTest(),
          ),
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

  if (kDebugMode) {
    await dotenv.load(fileName: ".env");
  } else {
    await dotenv.load(fileName: ".env");
  }

  // Save Map offline
  if (!kIsWeb) {
    await FMTCObjectBoxBackend().initialise();
    await FMTCStore('wms_dtk25__').manage.create();
    await FMTCStore('wms_dop__').manage.create();
  }

  //await Hive.initFlutter();
  //await GetStorage.init();

  try {
    await openDatabase();
    print('Database opened');
  } catch (e) {
    print('Error opening database: $e');
  }

  //String? token = await ApiService().init('${dotenv.env['HOST']}:${dotenv.env['PORT']}');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => Language(Locale(defaultLocale))),
        ChangeNotifierProvider(create: (_) => ThemeModeProvider(initialThemeMode)),
        //ChangeNotifierProvider(create: (_) => ApiLog(token)),
        //ChangeNotifierProvider(create: (_) => JsonSchemaProvider()),

        ChangeNotifierProvider(create: (_) => MapState()),
        ChangeNotifierProvider(create: (_) => GpsPositionProvider())
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
          builders: kIsWeb
              ? {
                  for (final platform in TargetPlatform.values) platform: const NoTransitionsBuilder(),
                }
              : {
                  TargetPlatform.android: ZoomPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.green,
          brightness: Brightness.light,
        ),
        primaryColor: const Color(0xFFC3E399),
        appBarTheme: AppBarTheme(
          color: const Color(0xFFC3E399),
        ),
        useMaterial3: true,
      ),

      darkTheme: ThemeData(
        scaffoldBackgroundColor: Color(0xFF333333),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.green,
          brightness: Brightness.dark,
        ),
        primaryColor: const Color(0xFFC3E399),
        appBarTheme: AppBarTheme(
          color: const Color(0xFFC3E399),
          foregroundColor: Colors.black,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: const Color(0xFFC3E399),
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.black,
        ),
        useMaterial3: true,
        /* dark theme settings */
      ),

      themeMode: themeProvider.mode,
      routeInformationParser: BeamerParser(),
      routerDelegate: routerDelegate,
    );
  }
}
