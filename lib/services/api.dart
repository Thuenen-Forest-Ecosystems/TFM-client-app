import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:get_storage/get_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'package:terrestrial_forest_monitor/providers/api-log.dart';
import 'package:provider/provider.dart';

import 'package:terrestrial_forest_monitor/types/error.dart';
import 'package:hive/hive.dart';

class ApiService {
  // Private constructor
  ApiService._internal();
  // Singleton instance
  static final ApiService _instance = ApiService._internal();

  factory ApiService() {
    return _instance;
  }
  // Getter for the instance
  static ApiService get instance => _instance;

  GetStorage users = GetStorage('Users');
  var userCollection;

  // Base URL
  String _baseUrl = 'localhost:3000';
  String _protocol = 'http';
  String? _token;

  Future initDB(username) async {
    userCollection = await BoxCollection.open(
      username, // Name of your database
      {'clusters'}, // Names of your boxes
      // path: './', // Path where to store your boxes (Only used in Flutter / Dart IO)
    );
  }

  Future init(baseUrl) async {
    setBaseUrl(baseUrl);
    return await Future.delayed(Duration(milliseconds: 1), () async {
      var user = await getLoggedInUser();
      if (user == null) return;
      await initDB(user['email']);
      return user['token'];
    });
  }

  get token => _token;

  // Set baseUrl
  void setBaseUrl(String baseUrl) {
    // Set the base URL
    _baseUrl = baseUrl;
  }

  // Get baseUrl
  String getBaseUrl() {
    // Get the base URL
    return _baseUrl;
  }

  Future<void> addUser(token) async {
    Map<String, dynamic> decodedToken = JwtDecoder.decode(token);
    decodedToken['token'] = token;
    return await users.write(decodedToken['email'], decodedToken);
  }

  Future<void> removeUser(username) async {
    return await users.remove(username);
  }

  Future<Map<String, dynamic>?> getUser(username) async {
    return users.read(username);
  }

  Future getAllUsers() async {
    return users.getValues();
  }

  Future<dynamic> getLoggedInUser() async {
    var activeUsers = await getAllUsers();
    var user = activeUsers.firstWhere((element) => element['token'] != null, orElse: () => null);
    if (user != null) {
      _token = user['token'];
    }
    return user;
  }

  Future logout(username) async {
    _token = null;
    Map<String, dynamic>? user = await getUser(username);
    user?['token'] = _token;
    users.write(user?['email'], user);
  }

  Future<Map<String, dynamic>?> addSchemataToUser(String username, List schemata) async {
    Map<String, dynamic>? user = await getUser(username);

    user?['schemata'] = schemata;

    users.write(user?['email'], user);

    return user;
  }

  addClusterToUser(String username, List clusters) async {
    int counter = 0;

    print('addClusterToUser');
    print(userCollection);
    if (userCollection == null) {
      await initDB(username);
    }
    final clustersBox = await userCollection!.openBox<Map>('clusters');

    for (var cluster in clusters) {
      if (cluster['id'] == null) {
        continue;
      }
      counter++;

      await clustersBox.put(cluster['id'].toString(), cluster);
    }
  }

  Future<List> getAllClusters() async {
    var user = await getLoggedInUser();

    if (user == null) {
      print('User not logged in');
      //throw Error('User not logged in', 401, {});
    }

    final clustersBox = await userCollection!.openBox<Map>('clusters');
    Map<String, dynamic>? clusters = await clustersBox.getAllValues();
    List values = [];
    //clusters.values.toList();
    clusters?.forEach((key, value) {
      values.add(value);
    });

    return values;
  }

  Future<Map> getCluster(clusterId) async {
    final clustersBox = await userCollection!.openBox<Map>('clusters');
    return await clustersBox.get(clusterId);
  }

  // Login method
  Future<Error> login(String username, String password) async {
    late http.Response response;
    // Login method
    final queryParameters = {
      'email': username,
      'pass': password,
    };
    const path = '/rpc/login';

    try {
      var url = _protocol == 'http' ? Uri.http(_baseUrl, path) : Uri.https(_baseUrl, path);
      response = await http.post(
        url,
        body: jsonEncode(queryParameters),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return Error('Could not connect to server', 500, {});
    }

    Map<String, dynamic> jsonResponse = jsonDecode(response.body);

    if (response.statusCode == 200 && jsonResponse['token'] != null) {
      _token = jsonResponse['token'];
      addUser(_token);
      await initDB(username);
      schemata();
      getClusters();
    }

    return Error('Success!', response.statusCode, jsonResponse);
  }

  // Get method
  Future<http.Response> get(String path) async {
    var url = _protocol == 'http' ? Uri.http(_baseUrl, path) : Uri.https(_baseUrl, path);
    return await http.get(url);
  }

  // Sync data method
  Future<Map<String, dynamic>> syncData(BuildContext context) async {
    List schema = [];
    List clusters;
    return schemata().then((value) {
      schema = value;

      return getClusters();
    }).then((value) {
      clusters = value;
      return {
        'schemata': schema,
        'clusters': clusters,
      };
    }).catchError((error) {
      Provider.of<ApiLog>(context, listen: false).addLog('Error syncing data');
    });
  }

  // Get clusters method
  Future<List<dynamic>> getClusters() async {
    http.Response response = await request('get', '/cluster', {
      //'id': 'eq.1',
      'select': '*,plot(*,plot_location(*),wzp_tree(*),deadwood(*),edges(*),position(*),sapling_1m(*),sapling_2m(*))',
    }, {
      'Accept-Profile': 'private_ci2027_001'
    });
    // Show snackbar if response is not 200
    if (response.statusCode != 200) {
      return [];
    }

    List clusters = jsonDecode(response.body);

    try {
      var user = await getLoggedInUser();
      await addClusterToUser(user['email'], clusters);
    } catch (e) {
      print(e);
    }

    return clusters;
  }

  // Get Schemata method
  Future<List<dynamic>> schemata() async {
    http.Response response = await request('get', '/schemata', {}, {});
    // Show snackbar if response is not 200
    if (response.statusCode != 200) {
      return [];
    }
    List schemata = jsonDecode(response.body);

    var user = await getLoggedInUser();
    user = await addSchemataToUser(user['email'], schemata);

    return schemata;
  }

  // Get Schemata method
  Future<http.Response> request(String type, String path, Map<String, dynamic> queryParameters, Map<String, String> headers) async {
    late http.Response response;

    headers['Accept'] = 'application/json';
    if (_token != '') {
      headers['Authorization'] = 'Bearer $_token';
    }

    try {
      if (type == 'get') {
        var url = _protocol == 'http' ? Uri.http(_baseUrl, path, queryParameters) : Uri.https(_baseUrl, path, queryParameters);
        response = await http.get(
          url,
          headers: headers,
        );
      } else if (type == 'post') {
        var url = _protocol == 'http' ? Uri.http(_baseUrl, path) : Uri.https(_baseUrl, path);
        response = await http.post(
          url,
          body: jsonEncode(queryParameters),
          headers: headers,
        );
      }
    } catch (e) {
      return http.Response('Could not connect to server', 500);
    }

    return response;
  }
}
