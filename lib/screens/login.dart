import 'package:flutter/material.dart';
//import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:beamer/beamer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:terrestrial_forest_monitor/providers/auth.dart';
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
    final isValid = _emailController.text.isNotEmpty && _emailController.text.contains('@') && _passwordController.text.length >= 6;

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

    try {
      await _authProvider.login(email, password);
      print('Login: Login successful');

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
            errorMessage = 'E-Mail-Adresse wurde noch nicht bestätigt. Bitte überprüfen Sie Ihr Postfach.';
          default:
            errorMessage = 'Anmeldefehler: ${e.message}';
        }
      } else {
        print('Login: Non-AuthException error - $e');
        errorMessage = 'Ein unerwarteter Fehler ist aufgetreten: $e';
      }

      print('Login: Showing error message: $errorMessage');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
      } else {
        print('Login: Widget not mounted, cannot show error');
      }
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
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: IntrinsicHeight(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),

                        // Login assets/logo/tfm.png form content (centered)
                        const Image(image: AssetImage('assets/logo/tfm.png'), height: 100),

                        const SizedBox(height: 10),

                        // Email Field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(50.0)))),
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

                        // Password Field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Passwort',
                            prefixIcon: const Icon(Icons.lock),
                            border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(50.0))),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
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

                        // Login Button
                        ElevatedButton(
                          onPressed: _isFormValid && !authProvider.loggingIn ? _handleLogin : null,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: authProvider.loggingIn ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Anmelden'),
                        ),

                        const Spacer(),

                        // Meta information at bottom
                        Column(
                          children: [
                            //SvgPicture.asset('assets/logo/THUENEN_SCREEN_Black.svg', height: 50),
                            //const SizedBox(height: 8),
                            // Links to Impressum and Datenschutz
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    launchUrl(Uri.parse('https://www.thuenen.de/de/impressum'));
                                  },
                                  child: const Text('Impressum', style: TextStyle(fontSize: 12)),
                                ),
                                const Text('|', style: TextStyle(color: Colors.grey)),
                                TextButton(
                                  onPressed: () {
                                    launchUrl(Uri.parse('https://www.thuenen.de/de/datenschutzerklaerung'));
                                  },
                                  child: const Text('Datenschutzbestimmungen', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            // Show App version and build number using package_info_plus
                            FutureBuilder<PackageInfo>(
                              future: PackageInfo.fromPlatform(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                  final packageInfo = snapshot.data!;
                                  return Center(child: Text('App Version: ${packageInfo.version} (${packageInfo.buildNumber})', style: const TextStyle(fontSize: 12, color: Colors.grey)));
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
