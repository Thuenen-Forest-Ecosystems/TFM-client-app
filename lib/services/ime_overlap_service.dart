import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bottom area covered by the soft keyboard that Android does NOT report as
/// an inset (#505): system bars hidden + Samsung floating keyboard. The keyboard
/// then paints an opaque strip over the hidden navigation bar while
/// `MediaQuery.viewInsets.bottom` and `padding.bottom` both stay 0.
///
/// [overlap] is in logical pixels; 0 on every other platform/situation.
class ImeOverlapService {
  ImeOverlapService._();

  static const _channel = EventChannel('com.thuenen.tfm/ime_overlap');
  static final ValueNotifier<double> overlap = ValueNotifier<double>(0);
  static StreamSubscription<dynamic>? _sub;

  static void start() {
    if (kIsWeb || !Platform.isAndroid || _sub != null) return;
    _sub = _channel.receiveBroadcastStream().listen((event) {
      final px = (event as num?)?.toDouble() ?? 0;
      final views = PlatformDispatcher.instance.views;
      final dpr = views.isEmpty ? 1.0 : views.first.devicePixelRatio;
      overlap.value = px / dpr;
    }, onError: (_) => overlap.value = 0);
  }
}
