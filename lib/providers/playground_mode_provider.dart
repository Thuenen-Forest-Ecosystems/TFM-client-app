import 'package:flutter/foundation.dart';

class PlaygroundModeProvider with ChangeNotifier {
  bool _isPlaygroundMode = false;

  bool get isPlaygroundMode => _isPlaygroundMode;

  void toggle() {
    _isPlaygroundMode = !_isPlaygroundMode;
    notifyListeners();
  }

  void setPlaygroundMode(bool value) {
    if (_isPlaygroundMode != value) {
      _isPlaygroundMode = value;
      notifyListeners();
    }
  }
}
