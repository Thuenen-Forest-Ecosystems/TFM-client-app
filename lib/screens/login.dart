import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
//import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
import 'package:terrestrial_forest_monitor/widgets/network-wrapper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isFormValid = false;
  late AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);

    // Store reference to AuthProvider to avoid context access in dispose
    _authProvider = context.read<AuthProvider>();
    _authProvider.addListener(_onAuthStateChanged);
  }

  void _onAuthStateChanged() {
    if (_authProvider.isAuthenticated && mounted) {
      context.beamToNamed('/');
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

  void _handleLogin() async {
    // Always validate first
    if (!_formKey.currentState!.validate()) {
      print('Login: Form validation failed');
      return;
    }

    // Prevent double-clicks
    if (_authProvider.loggingIn) {
      print('Login: Already logging in, ignoring');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    print('Login: Attempting login for email: $email');

    // Capture ScaffoldMessenger before async operation
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await _authProvider.login(email, password);

      // Check if still mounted after async operation
      if (!mounted) {
        print('Login: Widget unmounted after login attempt');
        return;
      }

      print('Login: Login successful');

      // Notify Android autofill service that login was successful
      TextInput.finishAutofillContext();

      // Navigation will be handled by the auth state listener
    } catch (e) {
      print('Login: Error occurred: $e');

      String errorMessage = 'Login fehlgeschlagen';

      if (e is AuthException) {
        print('Login: AuthException - ${e.message}');
        switch (e.message) {
          case 'Invalid login credentials':
            errorMessage = 'Ungültige Anmeldedaten. Bitte überprüfen Sie E-Mail und Passwort.';
          case 'Email not confirmed':
            errorMessage =
                'E-Mail-Adresse wurde noch nicht bestätigt. Bitte überprüfen Sie Ihr Postfach.';
          default:
            errorMessage = 'Anmeldefehler: ${e.message}';
        }
      } else {
        print('Login: Non-AuthException error - $e');

        // Check for certificate/SSL errors
        if (e.toString().contains('HandshakeException') ||
            e.toString().contains('CERTIFICATE_VERIFY_FAILED') ||
            e.toString().contains('unable to get local certificate')) {
          errorMessage =
              'Verbindungsfehler: Bitte überprüfen Sie Ihre Internetverbindung und stellen Sie sicher, dass Datum und Uhrzeit korrekt eingestellt sind.';
        } else {
          errorMessage = 'Ein unerwarteter Fehler ist aufgetreten: $e';
        }
      }

      print('Login: Showing error message: $errorMessage');

      // Show error using captured ScaffoldMessenger (works even if widget is unmounted)
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
                    child: Container(
                      width: double.infinity,
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Für die Nutzung ist eine Einladung durch das Thünen Institut erforderlich.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const Spacer(),
                            const Image(image: AssetImage('assets/logo/tfm.png'), height: 100),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.email),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.all(Radius.circular(50.0)),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Bitte geben Sie Ihre E-Mail-Adresse ein';
                                }
                                if (!value.contains('@')) {
                                  return 'Bitte geben Sie eine gültige E-Mail-Adresse ein';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              decoration: InputDecoration(
                                labelText: 'Passwort',
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
                                  return 'Bitte geben Sie Ihr Passwort ein';
                                }
                                if (value.length < 6) {
                                  return 'Das Passwort muss mindestens 6 Zeichen lang sein';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed:
                                  _isFormValid && !authProvider.loggingIn ? _handleLogin : null,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child:
                                  authProvider.loggingIn
                                      ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                      : const Text('Anmelden'),
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
                              child: const Text('Passwort vergessen?'),
                            ),
                            NetworkWrapper(
                              child: const SizedBox.shrink(),
                              offlineChild: Chip(
                                label: const Text(
                                  'keine Internetverbindung',
                                  style: TextStyle(color: Colors.orange),
                                ),
                                shape: StadiumBorder(
                                  side: BorderSide(color: Colors.orange.shade400, width: 1.5),
                                ),
                                backgroundColor: Colors.orange.withOpacity(0.1),
                              ),
                            ),
                            const Spacer(),
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        launchUrl(Uri.parse('https://www.thuenen.de/de/impressum'));
                                      },
                                      child: const Text(
                                        'Impressum',
                                        style: TextStyle(fontSize: 12),
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
                                      child: const Text(
                                        'Datenschutzbestimmungen',
                                        style: TextStyle(fontSize: 12),
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
                                          'App Version: ${packageInfo.version} (${packageInfo.buildNumber})',
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
