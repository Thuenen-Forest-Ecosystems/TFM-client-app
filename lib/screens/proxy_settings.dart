import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrestrial_forest_monitor/services/proxy_service.dart';

class ProxySettingsScreen extends StatefulWidget {
  const ProxySettingsScreen({super.key});

  @override
  State<ProxySettingsScreen> createState() => _ProxySettingsScreenState();
}

class _ProxySettingsScreenState extends State<ProxySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _proxyService = ProxyService();

  bool _isLoading = true;
  bool _isTesting = false;
  bool _proxyEnabled = true;
  bool _useSystemProxy = true;

  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _showPassword = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);

    try {
      final config = await _proxyService.getProxyConfig();

      setState(() {
        _proxyEnabled = config.enabled;
        _useSystemProxy = config.useSystemProxy;
        _hostController.text = config.host;
        _portController.text = config.port.toString();
        _usernameController.text = config.username;
        _passwordController.text = config.password;
      });
    } catch (e) {
      _showSnackBar('Fehler beim Laden der Einstellungen: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;

    final config = ProxyConfig(
      enabled: _proxyEnabled,
      useSystemProxy: _useSystemProxy,
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text) ?? 8080,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    try {
      await _proxyService.saveProxyConfig(config);
      _showSnackBar('Proxy-Einstellungen gespeichert');

      // Show restart hint
      if (mounted) {
        _showRestartDialog();
      }
    } catch (e) {
      _showSnackBar('Fehler beim Speichern: $e', isError: true);
    }
  }

  Future<void> _testConnection() async {
    if (!_proxyEnabled) {
      _showSnackBar('Proxy ist deaktiviert', isError: true);
      return;
    }

    if (!_useSystemProxy && !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    final config = ProxyConfig(
      enabled: _proxyEnabled,
      useSystemProxy: _useSystemProxy,
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text) ?? 8080,
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    try {
      final result = await _proxyService.testProxyConnection(config);

      setState(() {
        _testResult = result.message;
        _testSuccess = result.success;
      });
    } catch (e) {
      setState(() {
        _testResult = 'Test fehlgeschlagen: $e';
        _testSuccess = false;
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neustart erforderlich'),
        content: const Text(
          'Die Proxy-Einstellungen werden beim nächsten Start der Anwendung wirksam.\n\n'
          'Möchten Sie die Anwendung jetzt beenden?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Später')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Give time for dialog to close
              await Future.delayed(const Duration(milliseconds: 100));
              // Exit application - proper for desktop platforms
              exit(0);
            },
            child: const Text('Anwendung schließen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Proxy-Einstellungen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Proxy aktivieren/deaktivieren
            Card(
              child: SwitchListTile(
                title: const Text('Proxy aktivieren'),
                subtitle: const Text('Verbindung über Proxy-Server herstellen'),
                value: _proxyEnabled,
                onChanged: (value) => setState(() => _proxyEnabled = value),
              ),
            ),

            const SizedBox(height: 16),

            // System-Proxy vs. Manuelle Konfiguration
            if (_proxyEnabled) ...[
              Card(
                child: Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('System-Proxy verwenden'),
                      subtitle: const Text(
                        'Nutzt die Windows-Proxy-Einstellungen (EMPFOHLEN - unterstützt WebSocket)',
                      ),
                      value: true,
                      groupValue: _useSystemProxy,
                      onChanged: (value) => setState(() => _useSystemProxy = value!),
                    ),
                    RadioListTile<bool>(
                      title: Row(
                        children: [
                          const Text('Manuelle Konfiguration'),
                          const SizedBox(width: 8),
                          Icon(Icons.warning_amber, size: 20, color: Colors.orange.shade700),
                        ],
                      ),
                      subtitle: const Text(
                        'Veraltet: sollte nicht mehr genutzt werden.',
                        style: TextStyle(color: Colors.deepOrange),
                      ),
                      value: false,
                      groupValue: _useSystemProxy,
                      onChanged: (value) => null, //setState(() => _useSystemProxy = value!),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Manuelle Proxy-Konfiguration
              if (!_useSystemProxy) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Proxy-Server', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: 'Host/IP-Adresse',
                            hintText: 'z.B. proxy.example.com oder 192.168.1.1',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Bitte Host-Adresse eingeben';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: 'z.B. 8080, 3128',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Bitte Port eingeben';
                            }
                            final port = int.tryParse(value);
                            if (port == null || port < 1 || port > 65535) {
                              return 'Ungültiger Port (1-65535)';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Proxy-Authentifizierung
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Authentifizierung (optional)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nur erforderlich, wenn der Proxy-Server Benutzername und Passwort verlangt.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Benutzername',
                            border: OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Passwort',
                            border: const OutlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _showPassword = !_showPassword),
                            ),
                          ),
                          obscureText: !_showPassword,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Verbindung testen
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check),
                        label: Text(_isTesting ? 'Teste Verbindung...' : 'Verbindung testen'),
                      ),

                      if (_testResult != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _testSuccess == true
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _testSuccess == true ? Colors.green : Colors.red,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _testSuccess == true ? Icons.check_circle : Icons.error,
                                color: _testSuccess == true ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _testResult!,
                                  style: TextStyle(
                                    color: _testSuccess == true ? Colors.green : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Hilfe-Karte
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text('Hinweise'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Für Landesdatennetze: "System-Proxy verwenden" aktivieren\n'
                        '• Die Windows-Proxy-Einstellungen werden automatisch erkannt\n'
                        '• Umgebungsvariablen (HTTP_PROXY, HTTPS_PROXY) werden unterstützt',
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Nach dem Speichern ist ein Neustart der Anwendung erforderlich',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: _saveConfig,
          icon: const Icon(Icons.save),
          label: const Text('Einstellungen speichern'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),
      ),
    );
  }
}
