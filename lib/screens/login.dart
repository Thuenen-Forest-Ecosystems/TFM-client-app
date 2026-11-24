import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
import 'package:terrestrial_forest_monitor/widgets/bluetooth-icon-combined.dart';
import 'package:terrestrial_forest_monitor/widgets/serial-port-gps-icon.dart';
import 'package:terrestrial_forest_monitor/screens/proxy_settings.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:terrestrial_forest_monitor/services/connectivity_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;
  bool _isFormValid = false;
  bool _isOffline = false;
  bool _hasPreviousLogin = false;
  String? _cachedEmail;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);

    // Store reference to AuthProvider to avoid context access in dispose
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_onAuthStateChanged);

    // Check connectivity and previous login
    _checkConnectivityAndCache();

    // Listen to connectivity changes
    ConnectivityService.instance.onStatusChanged.listen((online) {
      if (mounted) {
        setState(() {
          _isOffline = !online;
        });
      }
    });
  }

  Future<void> _checkConnectivityAndCache() async {
    final isOffline = !await ConnectivityService.instance.checkOnline();
    final hasPreviousLogin = await _authProvider.hasPreviousLogin();
    final cachedEmail = await _authProvider.getCachedEmail();

    if (mounted) {
      setState(() {
        _isOffline = isOffline;
        _hasPreviousLogin = hasPreviousLogin;
        _cachedEmail = cachedEmail;
        if (_cachedEmail != null && _emailController.text.isEmpty) {
          _emailController.text = _cachedEmail!;
        }
      });
    }
  }

  void _onAuthStateChanged() {
    // Show a banner when the user was silently signed out by Supabase
    // (token expiry / failed refresh) rather than by an explicit logout.
    if (_authProvider.sessionExpiredError && mounted) {
      _authProvider.clearSessionExpiredError();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.loginSessionExpired),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      });
    }

    if (_authProvider.isAuthenticated && mounted) {
      // Dismiss keyboard and close text input connections through the
      // framework BEFORE the widget tree changes.
      _dismissKeyboard();

      if (!kIsWeb && Platform.isWindows) {
        // On Windows tablets, delay navigation by one frame so that the
        // platform has time to process TextInput.hide. Navigating
        // immediately causes the Login widget to dispose while the
        // platform still thinks there is an active text-input client,
        // leaving the Windows touch keyboard stuck open.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // One more hide after the frame to catch any re-attachment
            // from EditableText disposal/deactivation.
            SystemChannels.textInput.invokeMethod('TextInput.hide');
            context.beamToNamed('/');
          }
        });
      } else {
        context.beamToNamed('/');
      }
    }
  }

  void _validateForm() {
    final isValid =
        _emailController.text.isNotEmpty &&
        _emailController.text.contains('@') &&
        _passwordController.text.length >= 6;

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  /// Force-close the soft keyboard on Windows tablets.
  ///
  /// Important: Do NOT call `TextInput.clearClient` via the raw platform
  /// channel — it bypasses Flutter's internal `TextInput._currentConnection`
  /// bookkeeping.  When `EditableText` later disposes and tries to close its
  /// connection through the framework the mismatch can cause the Windows
  /// touch-keyboard to re-activate.
  void _dismissKeyboard() {
    // 1. Unfocus the entire focus tree so that EditableText closes its
    //    TextInputConnection through the framework (keeps internal state
    //    in sync with the platform).
    FocusManager.instance.primaryFocus?.unfocus();

    // 2. Also unfocus our own nodes to be safe.
    _emailFocusNode.unfocus();
    _passwordFocusNode.unfocus();

    // 3. Explicitly hide the platform soft keyboard.
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  void _handleLogin() async {
    // Dismiss keyboard before login
    _dismissKeyboard();

    // Always validate first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Prevent double-clicks
    if (_authProvider.loggingIn) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Capture ScaffoldMessenger before async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    try {
      await _authProvider.login(email, password);

      // Check if still mounted after async operation
      if (!mounted) {
        return;
      }

      // Notify autofill service that login was successful.
      // SKIP on Windows: finishAutofillContext re-engages the platform text
      // input connection, and since _onAuthStateChanged has already triggered
      // navigation at this point, it creates a dangling text input client
      // that causes the keyboard to stick open on the next page.
      if (kIsWeb || !Platform.isWindows) {
        TextInput.finishAutofillContext();
      }

      // Final keyboard cleanup
      _dismissKeyboard();

      // Navigation will be handled by the auth state listener
    } catch (e) {
      String errorMessage = l10n.loginFailed;

      if (e is AuthException) {
        switch (e.message) {
          case 'Invalid login credentials':
            errorMessage = l10n.loginInvalidCredentials;
          case 'Email not confirmed':
            errorMessage = l10n.loginEmailNotConfirmed;
          default:
            errorMessage = l10n.loginAuthError(e.message);
        }
      } else {
        // Check for proxy-related errors
        if (e.toString().contains('proxy') ||
            e.toString().contains('Proxy') ||
            (e.toString().contains('Failed host lookup') &&
                (e.toString().contains('proxy') || e.toString().contains('11001')))) {
          errorMessage = l10n.loginProxyError;
        }
        // Check for timeout errors
        else if (e.toString().contains('ClientException') &&
            (e.toString().contains('Zeitlimit') ||
                e.toString().contains('Semaphore') ||
                e.toString().contains('timeout'))) {
          errorMessage = l10n.loginTimeoutError;
        }
        // Check for certificate/SSL errors
        else if (e.toString().contains('HandshakeException') ||
            e.toString().contains('CERTIFICATE_VERIFY_FAILED') ||
            e.toString().contains('unable to get local certificate') ||
            e.toString().contains('unable to get local issuer certificate')) {
          errorMessage = l10n.loginCertificateError;
        } else {
          errorMessage = l10n.loginUnexpectedError(e.toString());
        }
      }

      // Show error using captured ScaffoldMessenger (works even if widget is unmounted)
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(errorMessage), duration: const Duration(seconds: 6)),
      );
    }
  }

  void _handleOfflineLogin() async {
    // Dismiss keyboard before login
    _dismissKeyboard();

    // Always validate first
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Prevent double-clicks
    if (_authProvider.loggingIn) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // Capture ScaffoldMessenger before async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;

    try {
      await _authProvider.loginOffline(email, password);

      // Check if still mounted after async operation
      if (!mounted) {
        return;
      }

      // Notify autofill service that login was successful.
      // SKIP on Windows (see comment in _handleLogin).
      if (kIsWeb || !Platform.isWindows) {
        TextInput.finishAutofillContext();
      }

      // Final keyboard cleanup
      _dismissKeyboard();

      // Navigation will be handled by the auth state listener
    } catch (e) {
      String errorMessage = l10n.loginOfflineFailed;

      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = l10n.loginUnexpectedError(e.toString());
      }

      // Show error using captured ScaffoldMessenger
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(errorMessage), duration: const Duration(seconds: 6)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // We use _authProvider for loggingIn, but still watch for rebuilds if needed
    // Since AuthProvider notifies listeners, and we have our own listener, but for UI, we can watch
    final authProvider = context.watch<AuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      resizeToAvoidBottomInset: true, // Ensure keyboard resizes the view
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 48, maxWidth: 500),
                  child: IntrinsicHeight(
                    child: SizedBox(
                      width: double.infinity,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            //const Text(
                            //  'Für die Nutzung ist eine Einladung durch das Thünen Institut erforderlich.',
                            //  textAlign: TextAlign.center,
                            //  style: TextStyle(fontSize: 12, color: Colors.grey),
                            //),
                            const Spacer(),
                            const Image(image: AssetImage('assets/logo/tfm.png'), height: 100),
                            const SizedBox(height: 10),
                            TextFormField(
                              key: const Key('loginEmailField'),
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              keyboardType: TextInputType.emailAddress,
                              // Skip autofillHints on Windows: the platform-level
                              // IME / autofill connection persists beyond widget
                              // disposal on Windows tablets, causing the touch
                              // keyboard to re-appear on any tap after navigation.
                              autofillHints: (!kIsWeb && Platform.isWindows)
                                  ? null
                                  : const [AutofillHints.email],
                              decoration: InputDecoration(
                                labelText: l10n.loginEmail,
                                prefixIcon: const Icon(Icons.email),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(50.0)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.loginEmailRequired;
                                }
                                if (!value.contains('@')) {
                                  return l10n.loginEmailInvalid;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const Key('loginPasswordField'),
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              obscureText: _obscurePassword,
                              autofillHints: (!kIsWeb && Platform.isWindows)
                                  ? null
                                  : const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: l10n.loginPassword,
                                prefixIcon: const Icon(Icons.lock),
                                border: const OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(50.0)),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return l10n.loginPasswordRequired;
                                }
                                if (value.length < 6) {
                                  return l10n.loginPasswordTooShort;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            // Online Login Button
                            if (!_isOffline)
                              ElevatedButton(
                                key: const Key('loginSubmitButton'),
                                onPressed: _isFormValid && !authProvider.loggingIn
                                    ? _handleLogin
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: authProvider.loggingIn
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : Text(l10n.loginSubmit),
                              ),
                            // Offline Login Button
                            if (_isOffline && _hasPreviousLogin)
                              Column(
                                children: [
                                  ElevatedButton(
                                    key: const Key('loginOfflineSubmitButton'),
                                    onPressed: _isFormValid && !authProvider.loggingIn
                                        ? _handleOfflineLogin
                                        : null,
                                    child: authProvider.loggingIn
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [Text(l10n.loginSubmit)],
                                          ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    l10n.loginOfflineMode,
                                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                                  ),
                                ],
                              ),
                            // No credentials message
                            if (_isOffline && !_hasPreviousLogin)
                              Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.wifi_off,
                                          size: 48,
                                          color: Colors.orange.shade700,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          l10n.loginNoInternet,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.loginNoInternetFirstLogin,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.orange.shade800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 24),
                            TextButton(
                              onPressed: () {
                                launchUrl(
                                  Uri.parse(
                                    'https://thuenen-forest-ecosystems.github.io/TFM-Documentation/authentication/sign-in',
                                  ),
                                );
                              },
                              child: Text(l10n.loginForgotPassword),
                            ),
                            const Spacer(),
                            Column(
                              children: [
                                // GNSS test and proxy settings need Bluetooth/serial
                                // and dart:io HTTP; the browser has neither (it uses
                                // its own proxy settings).
                                if (!kIsWeb) ...[
                                  // GNSS Test Button
                                  TextButton.icon(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isDismissible: true,
                                        enableDrag: true,
                                        isScrollControlled: true,
                                        builder: (context) => !kIsWeb && Platform.isWindows
                                            ? const SerialPortMenuSheet()
                                            : const BluetoothDeviceMenuSheet(popOnConnect: false),
                                      );
                                    },
                                    icon: const Icon(Icons.satellite_alt, size: 16),
                                    label: const Text(
                                      'GNSS Connection Test',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                  ),
                                  // Proxy/Network Settings Button
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => const ProxySettingsScreen(),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.settings_ethernet, size: 16),
                                    label: Text(
                                      l10n.loginNetworkSettings,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        launchUrl(Uri.parse('https://www.thuenen.de/de/impressum'));
                                      },
                                      child: Text(
                                        l10n.profileImprint,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    const Text('|', style: TextStyle(color: Colors.grey)),
                                    TextButton(
                                      onPressed: () {
                                        launchUrl(
                                          Uri.parse(
                                            'https://www.thuenen.de/de/datenschutzerklaerung',
                                          ),
                                        );
                                      },
                                      child: Text(
                                        l10n.profilePrivacy,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                                FutureBuilder<PackageInfo>(
                                  future: PackageInfo.fromPlatform(),
                                  builder: (context, snapshot) {
                                    if (snapshot.connectionState == ConnectionState.done &&
                                        snapshot.hasData) {
                                      final packageInfo = snapshot.data!;
                                      return Center(
                                        child: Text(
                                          l10n.profileAppVersion(packageInfo.version, packageInfo.buildNumber),
                                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                      );
                                    } else {
                                      return const SizedBox.shrink();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateForm);
    _passwordController.removeListener(_validateForm);
    _authProvider.removeListener(_onAuthStateChanged);

    // Dispose focus nodes FIRST so that the framework tears down its
    // TextInputConnection cleanly.  If we send TextInput.hide before
    // disposal, the framework's own dispose-path can briefly re-register
    // a text-input client with the platform, causing the Windows touch
    // keyboard to re-appear on the next screen.
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    // THEN hide the keyboard in a post-frame callback so the platform
    // processes the disposal (clearClient) before receiving the hide.
    if (!kIsWeb && Platform.isWindows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      });
    }

    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
