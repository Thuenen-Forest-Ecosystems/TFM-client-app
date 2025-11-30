// Export the appropriate implementation based on platform
export 'validation_service_io.dart' if (dart.library.html) 'validation_service_web.dart';
