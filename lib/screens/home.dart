import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/providers/api-log.dart';
import 'package:terrestrial_forest_monitor/route/404.dart';
import 'package:terrestrial_forest_monitor/route/forbidden-screen.dart';
import 'package:terrestrial_forest_monitor/screens/clusters.dart';
import 'package:terrestrial_forest_monitor/screens/plot-edit.dart';
import 'package:terrestrial_forest_monitor/screens/plot.dart';

//import 'package:terrestrial_forest_monitor/polyfill/libserial.dart' if (dart.library.html) 'package:terrestrial_forest_monitor/polyfill/libserial.dart' if (dart.library.io) 'package:terrestrial_forest_monitor/screens/libserial.dart';

import 'package:terrestrial_forest_monitor/screens/plots.dart';
import 'package:terrestrial_forest_monitor/screens/drawer.dart';
import 'package:terrestrial_forest_monitor/widgets/buttons/admin-button.dart';
//import 'package:terrestrial_forest_monitor/widgets/gps-connection-button.dart';
import 'package:terrestrial_forest_monitor/widgets/login-dialog.dart';
import 'package:terrestrial_forest_monitor/widgets/map.dart';
import 'package:terrestrial_forest_monitor/screens/thuenengrid.dart';
import 'package:terrestrial_forest_monitor/screens/verticalbar.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:provider/provider.dart';

import 'package:terrestrial_forest_monitor/widgets/login-button.dart';

import 'package:beamer/beamer.dart';

import 'package:flutter_svg/flutter_svg.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:terrestrial_forest_monitor/widgets/online-status.dart';
import 'package:terrestrial_forest_monitor/widgets/painter.dart';
import 'package:terrestrial_forest_monitor/widgets/sign-in-btn.dart';

///StateLess
class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final GlobalKey<ScaffoldState> _navigatorKey = GlobalKey();

  double screenWidth = 0;
  double screenWidth2 = 0;
  double _draggedValue = 300;
  bool _dragging = false;

  final routerDelegate = BeamerDelegate(
    notFoundPage: BeamPage(key: ValueKey('not-found'), title: 'Not Found', child: Error404()),
    initialPath: '/',
    guards: [
      BeamGuard(
        pathPatterns: ['/schema/*'],
        check: (context, state) => true, //Provider.of<ApiLog>(context, listen: false).token != null,
        beamToNamed: (_, __) => '/',
        /*showPage: BeamPage(
          key: ValueKey('forbidden'),
          title: 'Forbidden',
          child: Scaffold(
            body: Center(
              child: Text('Forbidden.'),
            ),
          ),
        ),*/
      ),
    ],
    locationBuilder: RoutesLocationBuilder(
      routes: {
        '/': (context, state, data) => BeamPage(
              key: ValueKey('TFM-grid'),
              title: 'Terrestrial Forest Monitoring',
              child: ThuenenGrid(),
            ),
        '403': (context, state, data) => BeamPage(
              key: ValueKey('TFM-grid'),
              title: '403',
              child: ForbiddenScreen(),
            ),
        'schema/:schemaId': (context, state, data) {
          final schemaId = state.pathParameters['schemaId']!;
          return Clusters(schemaId: schemaId);
        },
        'cluster/:schemaId/:clusterId': (context, state, data) {
          final schemaId = state.pathParameters['schemaId']!;
          final clusterId = state.pathParameters['clusterId']!;
          return Plots(clusterId: clusterId, schemaId: schemaId);
        },
        'plot/:schemaId/:clusterId/:plot': (context, state, data) {
          final schemaId = state.pathParameters['schemaId']!;
          final clusterId = state.pathParameters['clusterId']!;
          final plotId = state.pathParameters['plot']!;
          return Plot(schemaId: schemaId, plotId: plotId, clusterId: clusterId);
        },
        /*'schema/:schemaId/:clusterId': (context, state, data) {
          final schemaId = state.pathParameters['schemaId']!;
          final clusterId = state.pathParameters['clusterId']!;
          return Plots(clusterId: clusterId, schemaId: schemaId);
        },
        'schema/:schemaId/:clusterId/:plot': (context, state, data) {
          final schemaId = state.pathParameters['schemaId']!;
          final clusterId = state.pathParameters['clusterId']!;
          final plotId = state.pathParameters['plot']!;
          return Plot(schemaId: schemaId, plotId: plotId, clusterId: clusterId);
        },*/
      },
    ).call,
  );

  @override
  void initState() {
    super.initState();
  }

  void _handleDragInit(DragStartDetails details) {
    _dragging = true;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    // get relative dx
    final int deltaX = details.delta.dx.toInt();
    if (_draggedValue + deltaX < screenWidth2 / 2) {
      if (_draggedValue + deltaX >= 50) {
        setState(() {
          _draggedValue += deltaX;
        });
      } else {
        Provider.of<MapState>(context, listen: false).closeMap();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
    screenWidth = view.physicalSize.width;

    /*screenWidth2 = screenWidth; //MediaQuery.sizeOf(context).width;
    print(screenWidth2);*/
    screenWidth2 = MediaQuery.sizeOf(context).width;
    // https://pub.dev/packages/get_storage

    return Scaffold(
      key: _navigatorKey,
      /*bottomNavigationBar: screenWidth2 >= 600
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.map),
                  label: 'Karte',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.inventory),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Einstellungen',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_circle),
                  label: 'Login',
                ),
              ],
              onTap: (index) {
                if (index == 0) {
                  _navigatorKey.currentState?.openDrawer();
                  //context.read<MapState>().toggleMap();
                } else if (index == 1) {
                  context.beamToNamed('/');
                  //_navigatorKey.currentState?.pushNamed('thuenen/inventory', arguments: ThuenenArguments('inventory'));
                  //_navigatorKey.currentState?.popUntil(ModalRoute.withName('/'));
                } else if (index == 2) {
                  context.beamToNamed('/settings');
                } else {
                  showDialog<String>(
                    context: context,
                    builder: (BuildContext context) => AlertDialog(
                      title: const Text('Login'),
                      content: LoginDialog(),
                    ),
                  );
                }
              },
            ),*/
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: screenWidth2 >= 600
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.map),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
        title: Row(
          children: [
            InkWell(
              onTap: () {
                Beamer.of(context).beamToNamed('/');
              },
              child: SvgPicture.asset(
                'assets/logo/THUENEN_SCREEN_Black.svg',
                height: 50,
              ),
            ),
          ],
        ),
        actions: [
          //if (!kIsWeb && (Platform.isAndroid || Platform.isLinux || Platform.isWindows || Platform.isIOS || Platform.isMacOS))

          //SystemMessageIcon(),
          OnlineStatus(),
          LoginButton(),
          const AdminButton(),
          //SignInBtn(),
          IconButton(
            onPressed: () {
              //Beamer.of(context).beamToNamed('/settings');
              context.beamToNamed('/settings');
              //_navigatorKey.currentState?.pushNamed('monitor/sdfgsdfg', arguments: ThuenenArguments('inventory'));
              //Navigator.pushNamed(context, '/settings');
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      drawer: const TfmDrawer(),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (screenWidth2 >= 600)
                VertialBar(
                  isDrawer: false,
                ),
              if (screenWidth2 >= 600)
                Stack(
                  children: [
                    AnimatedContainer(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          const BoxShadow(
                            color: Color.fromARGB(255, 255, 22, 224),
                          ),
                          BoxShadow(
                            color: const Color.fromARGB(255, 255, 22, 224).withOpacity(0.5),
                            spreadRadius: -5,
                            blurRadius: 7,
                            offset: const Offset(0, 3), // changes position of shadow
                          ),
                        ],
                        color: Color.fromRGBO(150, 150, 150, 1),
                      ),
                      duration: Duration(milliseconds: _dragging ? 0 : 200),
                      width: context.watch<MapState>().mapOpen ? max(_draggedValue, 100) : 0,
                      child: TFMMap(),
                    ),
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          // https://stackoverflow.com/questions/51216747/constraining-draggable-area
                          //Draggable
                          onHorizontalDragStart: _handleDragInit,
                          onHorizontalDragUpdate: _handleDragUpdate,
                          onHorizontalDragEnd: (details) {
                            setState(() {
                              _dragging = false;
                            });
                          },

                          child: Container(
                            width: 15,
                            height: 100,
                            decoration: BoxDecoration(
                              color: Color.fromRGBO(108, 108, 108, 1),
                            ),
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: const Icon(
                                Icons.drag_handle,
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              Expanded(
                child: Beamer(
                  routerDelegate: routerDelegate,
                ),
              )
              /*Expanded(
                // https://api.flutter.dev/flutter/widgets/Navigator-class.html
                child: Navigator(
                  key: _navigatorKey,
                  initialRoute: widget.pageRoute,
                  onGenerateRoute: (RouteSettings settings) {
                    Widget page;
                    if (settings.name!.startsWith('/monitor/')) {
                      List routes = settings.name!.split('/');
                      if (routes.length == 3) {
                        page = Clusters(schemaId: routes[2]);
                      } else if (routes.length == 4) {
                        page = SingleChildScrollView(child: Plots(clusterId: routes[3]));
                      } else {
                        page = const Text('Error');
                      }
                    } else {
                      page = const ThuenenGrid();
                    }
                    return MaterialPageRoute<void>(
                        builder: (context) {
                          return page;
                        },
                        settings: settings);
                  },
                ),
              ),*/
            ],
          ),
          if (screenWidth2 >= 600)
            Positioned(
              left: 49,
              child: CustomPaint(
                painter: ImageEditor(),
              ),
            ),
        ],
      ),
    );
  }
}
