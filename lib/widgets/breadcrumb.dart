import 'package:flutter/material.dart';
//import 'package:navigation_history_observer/navigation_history_observer.dart';

class BreadCrumb extends StatefulWidget {
  const BreadCrumb({super.key});

  @override
  State<BreadCrumb> createState() => _BreadCrumbState();
}

class _BreadCrumbState extends State<BreadCrumb> {
  //final NavigationHistoryObserver historyObserver = NavigationHistoryObserver();

  @override
  void initState() {
    super.initState();
    //NavigationHistoryObserver().addListener(_onNavigationHistoryChange);

    /*historyObserver.historyChangeStream.listen(_getBreadCrumb);

    print(NavigationHistoryObserver().history);*/
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    /*BeamLocation beamLocation = Beamer.of(context).currentBeamLocation;
    print('BEAMER STATE');
    List history = beamLocation.history;
    //print(BeamState.fromUri(Uri.parse('/schema/private_ci2027_001')));
    for (var entry in history) {
      print(entry.buildPages());
    }*/
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color.fromARGB(255, 224, 241, 203),
      width: double.infinity,
      height: 40,
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'TODO: Refresh Breadcrumb on change Route (BEAMER)',
                style: TextStyle(color: Colors.black),
              ),
            ),

            /*Row(
              children: historyObserver.history.map(
                (entry) {
                  String routeName = entry.settings.name ?? '/';
                  return FilledButton(
                    onPressed: () {
                      Navigator.popUntil(context, ModalRoute.withName(routeName));
                    },
                    child: Text(routeName),
                  );
                },
              ).toList(),
            )*/
          ],
        ),
      ),
    );
  }
}
