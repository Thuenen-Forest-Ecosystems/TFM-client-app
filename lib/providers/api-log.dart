import 'package:flutter/foundation.dart';

class ApiLog with ChangeNotifier, DiagnosticableTreeMixin {
  List<dynamic> _errorLog = [];
  String? _token;

  ApiLog(this._token);

  List<dynamic> get errorLog => _errorLog;
  String? get token => _token;

  void addLog(dynamic log) {
    _errorLog.add(log);
    notifyListeners();
  }

  void changeToken(String? token) {
    _token = token;
    notifyListeners();
  }

  /// Makes `Counter` readable inside the devtools by listing all of its properties
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('ApiLog', _errorLog.toString()));
  }
}
