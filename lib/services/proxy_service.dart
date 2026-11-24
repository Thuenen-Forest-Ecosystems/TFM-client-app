import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/services/log_service.dart';

/// Service for managing HTTP/HTTPS proxy configuration
/// Supports both system proxy auto-detection and manual configuration
class ProxyService {
  static const String _keyProxyEnabled = 'proxy_enabled';
  static const String _keyProxyHost = 'proxy_host';
  static const String _keyProxyPort = 'proxy_port';
  static const String _keyProxyUsername = 'proxy_username';
  static const String _keyProxyPassword = 'proxy_password';
  static const String _keyUseSystemProxy = 'use_system_proxy';

  final LogService _logger = LogService();

  // Static cache for proxy config (loaded once at app start)
  static ProxyConfig? _cachedConfig;

  /// Initialize and cache proxy configuration at app startup
  static Future<void> initialize() async {
    final service = ProxyService();
    _cachedConfig = await service.getProxyConfig();
    service._logger.log(
      '🚀 Proxy service initialized: ${_cachedConfig!.toDebugString()}',
      level: LogLevel.info,
    );
  }

  /// Get cached proxy configuration (synchronous)
  static ProxyConfig? getCachedConfig() {
    return _cachedConfig;
  }

  /// Get current proxy configuration
  Future<ProxyConfig> getProxyConfig() async {
    final prefs = await SharedPreferences.getInstance();

    return ProxyConfig(
      enabled: prefs.getBool(_keyProxyEnabled) ?? false,
      useSystemProxy: prefs.getBool(_keyUseSystemProxy) ?? true,
      host: prefs.getString(_keyProxyHost) ?? '',
      port: prefs.getInt(_keyProxyPort) ?? 8080,
      username: prefs.getString(_keyProxyUsername) ?? '',
      password: prefs.getString(_keyProxyPassword) ?? '',
    );
  }

  /// Save proxy configuration
  Future<void> saveProxyConfig(ProxyConfig config) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_keyProxyEnabled, config.enabled);
    await prefs.setBool(_keyUseSystemProxy, config.useSystemProxy);
    await prefs.setString(_keyProxyHost, config.host);
    await prefs.setInt(_keyProxyPort, config.port);
    await prefs.setString(_keyProxyUsername, config.username);
    await prefs.setString(_keyProxyPassword, config.password);

    // Update cache
    _cachedConfig = config;

    _logger.log('💾 Proxy configuration saved: ${config.toDebugString()}', level: LogLevel.info);
  }

  /// Configure HttpClient with proxy settings
  void configureHttpClient(HttpClient client) {
    final config = _cachedConfig;

    if (config == null) {
      _logger.log('⚠️ No cached proxy config, using system proxy', level: LogLevel.warning);
      _configureSystemProxy(client);
      return;
    }

    if (!config.enabled) {
      _logger.log('🔓 Proxy disabled', level: LogLevel.info);
      return;
    }

    if (config.useSystemProxy) {
      _configureSystemProxy(client);
    } else if (config.host.isNotEmpty) {
      _configureManualProxy(client, config);
    } else {
      _logger.log('⚠️ Proxy enabled but no configuration found', level: LogLevel.warning);
    }
  }

  /// Configure HttpClient asynchronously with full config support
  Future<void> configureHttpClientAsync(HttpClient client) async {
    final config = await getProxyConfig();

    if (!config.enabled) {
      _logger.log('🔓 Proxy disabled', level: LogLevel.info);
      return;
    }

    if (config.useSystemProxy) {
      // Use system proxy settings (Windows Registry, environment variables, etc.)
      _configureSystemProxy(client);
    } else if (config.host.isNotEmpty) {
      // Use manual proxy configuration
      _configureManualProxy(client, config);
    } else {
      _logger.log('⚠️ Proxy enabled but no configuration found', level: LogLevel.warning);
    }
  }

  /// Configure system proxy (reads from Windows/macOS/Linux system settings)
  void _configureSystemProxy(HttpClient client) {
    // Check environment variables first (cross-platform)
    final httpProxy = Platform.environment['HTTP_PROXY'] ?? Platform.environment['http_proxy'];
    final httpsProxy = Platform.environment['HTTPS_PROXY'] ?? Platform.environment['https_proxy'];
    final noProxy = Platform.environment['NO_PROXY'] ?? Platform.environment['no_proxy'];

    if (httpProxy != null || httpsProxy != null) {
      final proxyUrl = httpsProxy ?? httpProxy;
      _logger.log('🌐 Using environment proxy: $proxyUrl', level: LogLevel.info);

      // Parse proxy URL to extract host:port (strip http:// or https:// prefix)
      String proxyString = proxyUrl!;
      try {
        final uri = Uri.parse(proxyUrl);
        if (uri.host.isNotEmpty) {
          final port = uri.hasPort ? uri.port : 8080;
          proxyString = '${uri.host}:$port';
        } else {
          // If parsing fails or no scheme, assume it's already in host:port format
          proxyString = proxyUrl.replaceAll(RegExp(r'^https?://'), '');
        }
        _logger.log('🔧 Parsed proxy string: PROXY $proxyString', level: LogLevel.debug);
      } catch (e) {
        _logger.log('⚠️ Failed to parse proxy URL, using as-is: $e', level: LogLevel.warning);
        // Strip common prefixes if parsing completely fails
        proxyString = proxyUrl.replaceAll(RegExp(r'^https?://'), '');
      }

      client.findProxy = (uri) {
        if (noProxy != null && _shouldBypassProxy(uri.host, noProxy)) {
          return 'DIRECT';
        }
        return 'PROXY $proxyString';
      };
    } else {
      // Fall back to system default (Windows Registry on Windows)
      _logger.log('🌐 Using system default proxy settings', level: LogLevel.info);

      client.findProxy = (uri) {
        // Return 'DIRECT' to use system settings
        // On Windows, dart:io will automatically check Windows proxy settings
        return HttpClient.findProxyFromEnvironment(uri, environment: Platform.environment);
      };
    }

    // Enable automatic authentication for system proxy
    client.authenticateProxy = (host, port, scheme, realm) async {
      // For system proxy, credentials are typically stored in credential manager
      // Return false to indicate no credentials provided here
      _logger.log('🔐 Proxy authentication requested for $host:$port', level: LogLevel.info);
      return false;
    };
  }

  /// Configure manual proxy
  void _configureManualProxy(HttpClient client, ProxyConfig config) {
    final proxyString = 'PROXY ${config.host}:${config.port}';

    _logger.log('🌐 Using manual proxy: ${config.host}:${config.port}', level: LogLevel.info);
    _logger.log('   Proxy string: $proxyString', level: LogLevel.debug);

    client.findProxy = (uri) {
      _logger.log('🔍 findProxy called for: $uri', level: LogLevel.debug);
      _logger.log('   → Returning: $proxyString', level: LogLevel.debug);
      return proxyString;
    };

    // Set up proxy authentication if credentials are provided
    if (config.username.isNotEmpty && config.password.isNotEmpty) {
      _logger.log('🔐 Setting up proxy authentication', level: LogLevel.info);

      // Add credentials first
      client.addProxyCredentials(
        config.host,
        config.port,
        '',
        HttpClientBasicCredentials(config.username, config.password),
      );

      // Set up authentication callback
      client.authenticateProxy = (host, port, scheme, realm) async {
        _logger.log(
          '🔐 Authenticating proxy: $scheme://${config.username}@$host:$port (realm: $realm)',
          level: LogLevel.info,
        );
        // Return true to indicate credentials were added via addProxyCredentials
        return true;
      };
    } else {
      _logger.log('   No authentication configured', level: LogLevel.debug);
    }
  }

  /// Check if host should bypass proxy based on NO_PROXY rules
  bool _shouldBypassProxy(String host, String noProxyList) {
    final noProxyHosts = noProxyList.split(',').map((h) => h.trim().toLowerCase());
    final hostLower = host.toLowerCase();

    for (final noProxyHost in noProxyHosts) {
      if (noProxyHost.isEmpty) continue;

      // Exact match
      if (hostLower == noProxyHost) return true;

      // Wildcard match (e.g., *.example.com)
      if (noProxyHost.startsWith('*')) {
        final domain = noProxyHost.substring(1);
        if (hostLower.endsWith(domain)) return true;
      }

      // Domain suffix match (e.g., .example.com)
      if (noProxyHost.startsWith('.')) {
        if (hostLower.endsWith(noProxyHost) || hostLower == noProxyHost.substring(1)) {
          return true;
        }
      }
    }

    return false;
  }

  /// Test proxy connection
  ///
  /// [l10n] is used for the user-visible result messages.
  Future<ProxyTestResult> testProxyConnection(
    ProxyConfig config, {
    required AppLocalizations l10n,
  }) async {
    final client = HttpClient();

    try {
      // CRITICAL: Configure proxy BEFORE making any requests
      if (!config.enabled) {
        _logger.log('⚠️ Testing with proxy disabled', level: LogLevel.warning);
      } else if (config.useSystemProxy) {
        _logger.log('🌐 Testing with system proxy', level: LogLevel.info);
        _configureSystemProxy(client);
      } else if (config.host.isNotEmpty) {
        _logger.log(
          '🌐 Testing with manual proxy: ${config.host}:${config.port}',
          level: LogLevel.info,
        );
        _configureManualProxy(client, config);
      } else {
        _logger.log('⚠️ No proxy configured', level: LogLevel.warning);
      }

      _logger.log('📡 Attempting connection to ci.thuenen.de...', level: LogLevel.info);

      // Test connection to ci.thuenen.de
      final request = await client.getUrl(Uri.parse('https://ci.thuenen.de/rest/v1/'));
      request.headers.set('User-Agent', 'TFM-ProxyTest/1.0');

      _logger.log('⏳ Waiting for response (timeout: 10s)...', level: LogLevel.info);

      final response = await request.close().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException(l10n.proxyServiceTimeoutAfter10s);
        },
      );

      final success = response.statusCode >= 200 && response.statusCode < 500;

      _logger.log(
        success
            ? '✅ HTTP test successful: ${response.statusCode}'
            : '⚠️ HTTP test returned: ${response.statusCode}',
        level: success ? LogLevel.info : LogLevel.warning,
      );

      // Also test WebSocket connection (critical for PowerSync)
      String wsMessage = '';
      try {
        _logger.log('🔌 Testing WebSocket connection (PowerSync)...', level: LogLevel.info);

        // Note: WebSocket.connect uses the global HttpOverrides automatically
        final wsUri = Uri.parse('wss://ci.thuenen.de/sync/');
        final ws =
            await WebSocket.connect(
              wsUri.toString(),
              headers: {'User-Agent': 'TFM-ProxyTest/1.0'},
            ).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw TimeoutException(l10n.proxyServiceWebSocketTimeout);
              },
            );

        await ws.close();
        _logger.log('WebSocket test successful', level: LogLevel.info);
        wsMessage = '\n${l10n.proxyServiceWebSocketWorks}';
      } catch (wsError) {
        _logger.log('WebSocket test failed: $wsError', level: LogLevel.warning);
        wsMessage = '\nWebSocket: ${wsError.toString().split('\n').first}';
      }

      return ProxyTestResult(
        success: success,
        statusCode: response.statusCode,
        message: success
            ? '${l10n.proxyServiceHttpSuccess(response.statusCode)}$wsMessage'
            : '${l10n.proxyServiceServerStatus(response.statusCode)}$wsMessage',
      );
    } on SocketException catch (e) {
      final errorMsg = e.osError?.message ?? e.message;
      final address = e.address?.host ?? 'unknown';
      final port = e.port ?? 0;

      _logger.log('❌ Socket error: $errorMsg (${e.osError?.errorCode})', level: LogLevel.error);
      _logger.log('   Address: $address:$port', level: LogLevel.error);

      String userMessage;
      if (e.osError?.errorCode == 111 || errorMsg.contains('refused')) {
        userMessage = l10n.proxyServiceConnectionRefused(address, port);
      } else if (e.osError?.errorCode == 113 || errorMsg.contains('No route to host')) {
        userMessage = l10n.proxyServiceHostUnreachable(address);
      } else {
        userMessage = l10n.proxyServiceNetworkError(errorMsg);
      }

      return ProxyTestResult(success: false, statusCode: null, message: userMessage);
    } on TimeoutException catch (e) {
      _logger.log('❌ Timeout: ${e.message}', level: LogLevel.error);

      return ProxyTestResult(
        success: false,
        statusCode: null,
        message: l10n.proxyServiceTimeout(e.message ?? l10n.proxyServiceNoResponse10s),
      );
    } catch (e) {
      _logger.log('❌ Proxy test failed: $e', level: LogLevel.error);

      return ProxyTestResult(
        success: false,
        statusCode: null,
        message: l10n.proxyServiceUnexpectedError(e.toString()),
      );
    } finally {
      client.close();
    }
  }
}

/// Proxy configuration model
class ProxyConfig {
  final bool enabled;
  final bool useSystemProxy;
  final String host;
  final int port;
  final String username;
  final String password;

  ProxyConfig({
    required this.enabled,
    required this.useSystemProxy,
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  String toDebugString() {
    if (!enabled) return 'disabled';
    if (useSystemProxy) return 'system proxy';

    final auth = username.isNotEmpty ? '$username@' : '';
    return '$auth$host:$port';
  }

  ProxyConfig copyWith({
    bool? enabled,
    bool? useSystemProxy,
    String? host,
    int? port,
    String? username,
    String? password,
  }) {
    return ProxyConfig(
      enabled: enabled ?? this.enabled,
      useSystemProxy: useSystemProxy ?? this.useSystemProxy,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }
}

/// Result of proxy connection test
class ProxyTestResult {
  final bool success;
  final int? statusCode;
  final String message;

  ProxyTestResult({required this.success, required this.statusCode, required this.message});
}
