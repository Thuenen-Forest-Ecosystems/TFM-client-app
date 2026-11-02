// flutter_js needs dart:ffi, which the web compiler rejects; in the browser the
// plausibility script runs in the page's own JS engine instead.
export 'plausibility_runner_io.dart' if (dart.library.js_interop) 'plausibility_runner_web.dart';
