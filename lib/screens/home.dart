import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/route/404.dart';
import 'package:terrestrial_forest_monitor/route/forbidden-screen.dart';
import 'package:terrestrial_forest_monitor/screens/cluster-admin.dart';
import 'package:terrestrial_forest_monitor/screens/dynamic-form-screen.dart';
import 'package:terrestrial_forest_monitor/screens/organizations.dart';
import 'package:terrestrial_forest_monitor/screens/plot.dart';
import 'package:terrestrial_forest_monitor/screens/plots-by-permissions.dart';

//import 'package:terrestrial_forest_monitor/polyfill/libserial.dart' if (dart.library.html) 'package:terrestrial_forest_monitor/polyfill/libserial.dart' if (dart.library.io) 'package:terrestrial_forest_monitor/screens/libserial.dart';

import 'package:terrestrial_forest_monitor/screens/plots.dart';
import 'package:terrestrial_forest_monitor/screens/previous-record.dart';
import 'package:terrestrial_forest_monitor/services/powersync.dart';
import 'package:terrestrial_forest_monitor/widgets/buttons/admin-button.dart';
import 'package:terrestrial_forest_monitor/widgets/buttons/permissions-admin-button.dart';
import 'package:terrestrial_forest_monitor/widgets/cluster-adminbutton.dart';
import 'package:terrestrial_forest_monitor/widgets/gps-button.dart';
//import 'package:terrestrial_forest_monitor/widgets/gps-connection-button.dart';
import 'package:terrestrial_forest_monitor/widgets/map.dart';
import 'package:terrestrial_forest_monitor/screens/thuenengrid.dart';
import 'package:terrestrial_forest_monitor/screens/verticalbar.dart';
import 'package:terrestrial_forest_monitor/providers/map-state.dart';
import 'package:provider/provider.dart';

import 'package:terrestrial_forest_monitor/widgets/login-button.dart';

import 'package:beamer/beamer.dart';

import 'package:flutter_svg/flutter_svg.dart';
//import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:terrestrial_forest_monitor/widgets/organizations-button.dart';
import 'package:terrestrial_forest_monitor/widgets/painter.dart';

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
    transitionDelegate: const NoAnimationTransitionDelegate(),
    updateListenable: ValueNotifier<bool>(false), // Prevents navigation animations
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
    locationBuilder:
        RoutesLocationBuilder(
          routes: {
            '/': (context, state, data) => BeamPage(key: ValueKey('TFM-grid'), title: 'Terrestrial Forest Monitoring', child: ThuenenGrid(), type: BeamPageType.noTransition),
            '403': (context, state, data) => BeamPage(key: ValueKey('TFM-grid'), title: '403', child: ForbiddenScreen(), type: BeamPageType.noTransition),
            'records': (context, state, data) {
              return BeamPage(key: ValueKey('records'), title: 'Clusters', child: PlotsByPermissions(), type: BeamPageType.noTransition);
            },
            'schema/:schemaId': (context, state, data) {
              final schemaId = state.pathParameters['schemaId']!;
              return BeamPage(key: ValueKey('clusters-$schemaId'), title: 'Clusters', child: PlotsByPermissions(), type: BeamPageType.noTransition);
            },
            'cluster/admin': (context, state, data) {
              return ClusterAdmin();
            },
            'cluster/:schemaId/:clusterId': (context, state, data) {
              final schemaId = state.pathParameters['schemaId']!;
              final clusterId = state.pathParameters['clusterId']!;
              return Plots(clusterId: clusterId, schemaId: schemaId);
            },
            'record/:recordId': (context, state, data) {
              final recordId = state.pathParameters['recordId']!;
              return PreviousRecord(recordId: recordId);
            },
            'organizations': (context, state, data) {
              return OrganizationsScreen();
            },
            'plot/edit/:schemaId/:clusterId/:plot': (context, state, data) {
              final schemaId = state.pathParameters['schemaId']!;
              final clusterId = state.pathParameters['clusterId']!;
              final plotId = state.pathParameters['plot']!;
              return DynamicFormScreen(schemaId: schemaId, recordsId: plotId, clusterId: clusterId);
            },
            /*'plot/edit/:schemaId/:clusterId/:plot': (context, state, data) {
              final schemaId = state.pathParameters['schemaId']!;
              final clusterId = state.pathParameters['clusterId']!;
              final plotId = state.pathParameters['plot']!;
              return PlotEdit(schemaId: schemaId, plotId: plotId, clusterId: clusterId);
            },
            'plot/edit/:schemaId/:clusterId/:plot': (context, state, data) {
              final schemaId = state.pathParameters['schemaId']!;
              final clusterId = state.pathParameters['clusterId']!;
              final plotId = state.pathParameters['plot']!;
              return PlotEditBySchema(schemaId: schemaId, plotId: plotId, clusterId: clusterId);
            },*/
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

    screenWidth2 = MediaQuery.sizeOf(context).width;
    // https://pub.dev/packages/get_storage

    return Scaffold(
      key: _navigatorKey,
      appBar: AppBar(
        centerTitle: false,
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFFC3E399),
        leading:
            screenWidth2 >= 600
                ? null
                : Builder(
                  builder:
                      (context) => IconButton(
                        icon: Icon(Icons.map),
                        onPressed: () {
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                ),

        title:
            screenWidth2 >= 600
                ? Row(
                  children: [
                    InkWell(
                      onTap: () {
                        Beamer.of(context).beamToNamed('/');
                      },
                      child: SvgPicture.asset('assets/logo/THUENEN_SCREEN_Black.svg', height: 50),
                    ),
                  ],
                )
                : SizedBox(),
        actions: [
          //if (!kIsWeb && (Platform.isAndroid || Platform.isLinux || Platform.isWindows || Platform.isIOS || Platform.isMacOS))

          //SystemMessageIcon(),
          //OnlineStatus(),
          //SignInBtn(),

          //SizedBox(width: 10),
          const GpsButton(),
          const AdminButton(),
          //const PermissionsAdminButton(),
          IconButton(
            onPressed: () {
              context.beamToNamed('/settings');
            },
            icon: Icon(Icons.settings),
          ),
          ClusterAdminButton(),
          OrganizationsButton(),
          SizedBox(width: 10),
          LoginButton(),
          SizedBox(width: 10),
          /*IconButton(
            onPressed: () {
              context.beamToNamed('/headless');
            },
            icon: Icon(Icons.car_crash),
          ),*/
          /*IconButton(
            onPressed: () {
              context.beamToNamed('/FlutterJsHomeScreen');
            },
            icon: Icon(Icons.car_crash_outlined),
          ),*/
        ],
      ),
      //drawer: const TfmDrawer(),
      body: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (screenWidth2 >= 600) VertialBar(isDrawer: false),
              if (screenWidth2 >= 600)
                Stack(
                  children: [
                    AnimatedContainer(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          const BoxShadow(color: Color.fromARGB(255, 255, 22, 224)),
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

                          child: Container(width: 15, height: 100, decoration: BoxDecoration(color: Color.fromRGBO(108, 108, 108, 1)), child: RotatedBox(quarterTurns: 1, child: const Icon(Icons.drag_handle, size: 15))),
                        ),
                      ),
                    ),
                  ],
                ),
              Expanded(child: Beamer(routerDelegate: routerDelegate)),
            ],
          ),
          if (screenWidth2 >= 600) Positioned(left: 49, child: CustomPaint(painter: ImageEditor())),
        ],
      ),
    );
  }
}
