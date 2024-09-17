import 'package:beamer/beamer.dart';
import 'package:flutter/widgets.dart';

import 'package:terrestrial_forest_monitor/screens/home.dart';
import 'package:terrestrial_forest_monitor/screens/settings.dart';

class HomeLocation extends BeamLocation<BeamState> {
  HomeLocation(RouteInformation super.routeInformation);
  @override
  List<String> get pathPatterns => ['/*'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        BeamPage(
          key: ValueKey('home-${DateTime.now()}'),
          title: 'Home',
          child: Home(),
        )
      ];
}

class SettingsLocation extends BeamLocation<BeamState> {
  SettingsLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/settings'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        BeamPage(
          key: ValueKey('settings'),
          title: 'Einstellungen',
          child: Settings(),
        )
      ];
}

class BooksContentLocation extends BeamLocation<BeamState> {
  BooksContentLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/books/authors',
        '/books/genres',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        BeamPage(
          key: ValueKey('books-home'),
          title: 'Books Home',
          child: Home(),
        ),
        if (state.pathPatternSegments.contains('authors'))
          BeamPage(
            key: ValueKey('books-authors'),
            title: 'Books Authors',
            child: Home(),
          ),
        if (state.pathPatternSegments.contains('genres'))
          BeamPage(
            key: ValueKey('books-genres'),
            title: 'Books Genres',
            child: Home(),
          )
      ];
}

class ArticlesLocation extends BeamLocation<BeamState> {
  ArticlesLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => ['/articles/*'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        BeamPage(
          key: ValueKey('articles'),
          title: 'Articles',
          child: Home(),
        )
      ];
}

class ArticlesContentLocation extends BeamLocation<BeamState> {
  ArticlesContentLocation(RouteInformation super.routeInformation);

  @override
  List<String> get pathPatterns => [
        '/articles/authors',
        '/articles/genres',
      ];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
        BeamPage(
          key: ValueKey('articles-home'),
          title: 'Articles Home',
          child: Home(),
        ),
        if (state.pathPatternSegments.contains('authors'))
          BeamPage(
            key: ValueKey('articles-authors'),
            title: 'Articles Authors',
            child: Home(),
          ),
        if (state.pathPatternSegments.contains('genres'))
          BeamPage(
            key: ValueKey('articles-genres'),
            title: 'Articles Genres',
            child: Home(),
          )
      ];
}
