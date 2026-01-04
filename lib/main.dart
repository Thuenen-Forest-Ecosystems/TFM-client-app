import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // Add this line
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:beamer/beamer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/route/404.dart';
import 'package:terrestrial_forest_monitor/screens/schema.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:terrestrial_forest_monitor/providers/language.dart';
import 'package:terrestrial_forest_monitor/providers/theme-mode.dart';
import 'package:terrestrial_forest_monitor/providers/gps-position.dart';
import 'package:terrestrial_forest_monitor/providers/database_provider.dart';
import 'package:terrestrial_forest_monitor/providers/records_list_provider.dart';
import 'package:terrestrial_forest_monitor/providers/map_controller_provider.dart';
import 'package:terrestrial_forest_monitor/repositories/forest_location_repository.dart';
import 'package:terrestrial_forest_monitor/repositories/schema_repository.dart';

import 'package:intl/intl.dart';
import 'package:terrestrial_forest_monitor/services/attachment-helper.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/services/validation_service.dart';
import 'package:terrestrial_forest_monitor/services/background_sync_service.dart';
import 'package:terrestrial_forest_monitor/services/app_lifecycle_manager.dart';
import 'package:terrestrial_forest_monitor/transitions/no-animation.dart';
import 'package:upgrader/upgrader.dart';

// NEW SCREENS -----
import 'package:terrestrial_forest_monitor/screens/start.dart';
import 'package:terrestrial_forest_monitor/screens/login.dart';
import 'package:terrestrial_forest_monitor/screens/profile.dart';
import 'package:terrestrial_forest_monitor/screens/logger.dart';
// provider
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/services/log_service.dart';

BeamerDelegate createRouterDelegate(AuthProvider authProvider) {
  return BeamerDelegate(
    notFoundPage: BeamPage(key: ValueKey('not-found'), title: 'Not Found', child: Error404()),
    //transitionDelegate: const NoAnimationTransitionDelegate(),
    updateListenable: authProvider,
    guards: [
      BeamGuard(
        pathPatterns: [
          '/settings',
          '/admin',
          '/admin-permissions',
          '/headless',
          '/',
          '/profile',
          '/logs',
        ],
        check: (context, location) {
          final authProvider = context.read<AuthProvider>();
          return authProvider.isAuthenticated;
        },
        beamToNamed: (origin, target) => '/login',
      ),
    ],
    locationBuilder: RoutesLocationBuilder(
      routes: {
        '/login': (context, state, data) => BeamPage(
          key: ValueKey('login'),
          title: 'Login',
          child: Login(),
          type: BeamPageType.noTransition,
        ),
        '/': (context, state, data) => BeamPage(
          key: ValueKey('home'),
          title: 'TFM',
          child: Schema(),
          type: BeamPageType.noTransition,
        ),
        //'/schema-selection': (context, state, data) => BeamPage(key: ValueKey('start-${DateTime.now()}'), title: 'TFM', child: Start(), type: BeamPageType.noTransition),
        '/records-selection/:intervalName': (context, state, data) => BeamPage(
          key: ValueKey('records-${state.pathParameters['intervalName']}'),
          title: 'TFM',
          child: Start(),
          type: BeamPageType.noTransition,
        ),
        '/properties-edit/:clusterName/:plotName': (context, state, data) => BeamPage(
          key: ValueKey(
            'properties-${state.pathParameters['clusterName']}-${state.pathParameters['plotName']}',
          ),
          title: 'TFM',
          child: Start(),
          type: BeamPageType.noTransition,
        ),
        '/profile': (context, state, data) => BeamPage(
          key: ValueKey('profile'),
          title: 'Profile',
          child: Profile(),
          type: BeamPageType.noTransition,
        ),
        '/logs': (context, state, data) => BeamPage(
          key: ValueKey('logs'),
          title: 'Logs',
          child: LoggerScreen(),
          type: BeamPageType.noTransition,
        ),
        //'/settings': (context, state, data) => BeamPage(key: ValueKey('settings-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: Settings(), type: BeamPageType.noTransition),
        //'/admin': (context, state, data) => BeamPage(key: ValueKey('admin-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: AdminScreen(), type: BeamPageType.noTransition),
        //'/admin-permissions': (context, state, data) => BeamPage(key: ValueKey('admin-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: AdminPermissionsScreen(), type: BeamPageType.noTransition),
        //'/headless': (context, state, data) => BeamPage(key: ValueKey('headless-${DateTime.now()}'), title: AppLocalizations.of(context)!.settings, child: StatelessTest(), type: BeamPageType.noTransition),
      },
    ).call,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Apply Windows SSL workaround with bundled certificate
  if (!kIsWeb && Platform.isWindows) {
    final certOverride = _WindowsCertificateOverride();
    await certOverride.initialize();
    HttpOverrides.global = certOverride;
    print('Windows certificate override enabled with bundled certificate');
  }

  usePathUrlStrategy();

  // set default Locale to Language provider
  final String defaultLocale = Intl.getCurrentLocale(); // = Platform.localeName;
  final Brightness brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
  final ThemeMode initialThemeMode = brightness == Brightness.dark
      ? ThemeMode.dark
      : ThemeMode.light;

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('Error loading .env file: $e');
  }

  // Initialize background sync service
  await BackgroundSyncService.initialize();

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
    // Initialize database and Supabase FIRST
    await openDatabase();

    // Skip attachment queue on web (uses file system)
    if (!kIsWeb) {
      await initializeAttachmentQueue(db);
    }

    // Initialize validation service (flutter_inappwebview not supported on web)
    if (!kIsWeb) {
      await ValidationService.instance.initialize();
    }

    // Initialize app lifecycle manager to keep sync running in background
    await appLifecycleManager.initialize();
  } catch (e) {
    print('Error opening database: $e');
    // Rethrow to prevent app from continuing with broken state
    rethrow;
  }
  //await Repository.configure(databaseFactory);
  //await Repository().initialize();

  // Create GPS provider but don't initialize yet (will be done when Start screen loads)
  final gpsProvider = GpsPositionProvider();

  final languageProvider = Language(Locale(defaultLocale));
  languageProvider.watchLanguageChange();

  // Create AuthProvider AFTER Supabase is initialized (in openDatabase)
  final authProvider = AuthProvider();
  await authProvider.checkAuthStatus();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider(create: (_) => DatabaseProvider()),
        ChangeNotifierProvider(create: (_) => languageProvider),
        ChangeNotifierProvider(create: (_) => ThemeModeProvider(initialThemeMode)),
        ChangeNotifierProvider(create: (_) => MapState()),
        ChangeNotifierProvider(create: (_) => gpsProvider),
        ChangeNotifierProvider(create: (_) => RecordsListProvider()),
        ChangeNotifierProvider(create: (_) => MapControllerProvider()),

        // Repositories
        Provider(create: (_) => ForestLocationRepository()),
        Provider(create: (_) => SchemaRepository()),
      ],
      child: Layout(routerDelegate: createRouterDelegate(authProvider)),
    ),
  );
  //context.read<Language>().setLocale(Locale(defaultLocale));
}

class Layout extends StatelessWidget {
  final BeamerDelegate routerDelegate;

  const Layout({super.key, required this.routerDelegate});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final String languageProvider = Provider.of<Language>(context).locale.toString();
    String selectedLanguage = languageProvider.split('_')[0];

    final themeProvider = Provider.of<ThemeModeProvider>(context);

    //context.watch<MapState>().mapOpen

    return UpgradeAlert(
      upgrader: Upgrader(
        durationUntilAlertAgain: Duration(days: 1),
        countryCode: 'DE',
        messages: UpgraderMessages(code: selectedLanguage),
      ),
      dialogStyle: UpgradeDialogStyle.material,
      showLater: true,
      showIgnore: false,
      child: MaterialApp.router(
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
                    for (final platform in TargetPlatform.values)
                      platform: const NoTransitionsBuilder(),
                  }
                : {
                    // Disable swipe-back gestures for both platforms
                    TargetPlatform.android: const NoTransitionsBuilder(),
                    TargetPlatform.iOS: const NoTransitionsBuilder(),
                  },
          ),
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.green,
            brightness: Brightness.light,
          ).copyWith(error: Colors.red.shade700),
          primaryColor: const Color(0xFFC3E399),
          appBarTheme: AppBarTheme(color: const Color(0xFFC3E399)),
          useMaterial3: true,
        ),

        darkTheme: ThemeData(
          scaffoldBackgroundColor: Color(0xFF333333),
          colorScheme: ColorScheme.fromSwatch(
            primarySwatch: Colors.green,
            brightness: Brightness.dark,
          ).copyWith(error: Colors.red.shade400),
          primaryColor: const Color(0xFFC3E399),
          appBarTheme: AppBarTheme(
            color: const Color.fromARGB(255, 224, 241, 203),
            foregroundColor: Colors.black,
          ), // color: const Color(0xFFC3E399), foregroundColor: Colors.black
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
      ),
    );
  }
}

/// Custom HttpOverrides to handle Windows certificate verification issues
/// Loads bundled SSL certificate from assets to avoid Windows cert store issues
class _WindowsCertificateOverride extends HttpOverrides {
  SecurityContext? _customContext;

  Future<void> initialize() async {
    if (kIsWeb || !Platform.isWindows) return;

    final logger = LogService();

    try {
      // Enhanced platform detection
      final osVersion = Platform.operatingSystemVersion;
      final executable = Platform.resolvedExecutable;

      logger.log('🔧 Windows Platform Detection:', level: LogLevel.info);
      logger.log('   OS Version: $osVersion', level: LogLevel.info);
      logger.log('   Executable: $executable', level: LogLevel.debug);
      logger.log('   Environment: ${Platform.environment}', level: LogLevel.debug);

      // Detect architecture
      final isARM =
          executable.contains('arm') ||
          Platform.environment['PROCESSOR_ARCHITECTURE']?.contains('ARM') == true;
      final isX86 =
          executable.contains('x86') || Platform.environment['PROCESSOR_ARCHITECTURE'] == 'x86';

      logger.log(
        '   Architecture: ${isARM
            ? "ARM"
            : isX86
            ? "x86"
            : "x64"}',
        level: LogLevel.info,
      );

      // Load bundled certificate from assets
      final certData = await rootBundle.load('assets/certs/ci_thuenen_root.pem');
      final certBytes = certData.buffer.asUint8List();

      logger.log('📄 Certificate loaded: ${certBytes.length} bytes', level: LogLevel.info);

      // Try multiple approaches for different Windows configurations
      try {
        // Approach 1: Fresh context with trusted roots (works on most systems)
        _customContext = SecurityContext(withTrustedRoots: true);
        _customContext!.setTrustedCertificatesBytes(certBytes);
        logger.log('✅ Method 1: Fresh SecurityContext with trusted roots', level: LogLevel.info);
      } catch (e) {
        logger.log('⚠️ Method 1 failed: $e', level: LogLevel.warning);
        try {
          // Approach 2: Fresh context WITHOUT trusted roots (for restricted devices)
          _customContext = SecurityContext(withTrustedRoots: false);
          _customContext!.setTrustedCertificatesBytes(certBytes);
          logger.log(
            '✅ Method 2: Fresh SecurityContext without system roots',
            level: LogLevel.info,
          );
        } catch (e2) {
          logger.log('⚠️ Method 2 failed: $e2', level: LogLevel.warning);
          // Approach 3: Use default context (last resort)
          _customContext = SecurityContext.defaultContext;
          _customContext!.setTrustedCertificatesBytes(certBytes);
          logger.log('✅ Method 3: Using default context', level: LogLevel.warning);
        }
      }

      logger.log(
        '✅ Bundled SSL certificate loaded successfully for ci.thuenen.de',
        level: LogLevel.info,
      );
    } catch (e, stackTrace) {
      logger.log('❌ ERROR: Could not load bundled certificate - $e', level: LogLevel.error);
      logger.log('   Stack trace: $stackTrace', level: LogLevel.error);
      logger.log('   Falling back to accepting all certificates', level: LogLevel.warning);
      _customContext = null;
    }
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final logger = LogService();
    final osVersion = Platform.operatingSystemVersion;
    final arch = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? 'unknown';

    logger.log(
      '🌐 Creating HttpClient - OS: $osVersion, Arch: $arch, CustomContext: ${_customContext != null}',
      level: LogLevel.info,
    );

    // CRITICAL: Use super.createHttpClient() to avoid infinite recursion
    // Pass our custom context with the bundled certificate
    final client = super.createHttpClient(_customContext ?? context);

    // Enhanced certificate callback with detailed logging
    client.badCertificateCallback = (X509Certificate cert, String host, int port) {
      logger.log('🔒 Certificate validation triggered for: $host:$port', level: LogLevel.warning);
      logger.log('   Issuer: ${cert.issuer}', level: LogLevel.info);
      logger.log('   Subject: ${cert.subject}', level: LogLevel.info);
      logger.log('   Valid from: ${cert.startValidity}', level: LogLevel.debug);
      logger.log('   Valid until: ${cert.endValidity}', level: LogLevel.debug);
      logger.log('   OS: $osVersion', level: LogLevel.debug);
      logger.log('   Architecture: $arch', level: LogLevel.debug);

      // Accept certificates for our specific domain (fallback if bundled cert doesn't work)
      if (host.contains('ci.thuenen.de') ||
          host.contains('supabase.co') ||
          host.contains('supabase.io')) {
        logger.log(
          '   ✓ Accepting certificate for $host (bundled cert or fallback)',
          level: LogLevel.info,
        );
        return true;
      }

      logger.log('   ✗ Rejecting certificate for $host', level: LogLevel.warning);
      return false;
    };

    client.connectionTimeout = const Duration(seconds: 30);

    logger.log('✅ HttpClient configured with 30s timeout', level: LogLevel.debug);

    return client;
  }
}
