import 'dart:io';

import 'package:flutter/material.dart';
import 'package:terrestrial_forest_monitor/l10n/app_localizations.dart';
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
  bool _proxyEnabled = false;
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
      if (!mounted) return;
      _showSnackBar(
        AppLocalizations.of(context)!.proxySettingsLoadError(e.toString()),
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

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
      _showSnackBar(l10n.proxySettingsSaved);

      // Show restart hint
      if (mounted) {
        _showRestartDialog();
      }
    } catch (e) {
      _showSnackBar(l10n.proxySettingsSaveError(e.toString()), isError: true);
    }
  }

  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_proxyEnabled) {
      _showSnackBar(l10n.proxySettingsProxyDisabled, isError: true);
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
      final result = await _proxyService.testProxyConnection(config, l10n: l10n);

      setState(() {
        _testResult = result.message;
        _testSuccess = result.success;
      });
    } catch (e) {
      setState(() {
        _testResult = l10n.proxySettingsTestFailed(e.toString());
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.proxySettingsRestartTitle),
        content: Text(l10n.proxySettingsRestartContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.proxySettingsRestartLater),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              // Give time for dialog to close
              await Future.delayed(const Duration(milliseconds: 100));
              // Exit application - proper for desktop platforms
              exit(0);
            },
            child: Text(l10n.proxySettingsCloseApp),
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileProxySettings)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Proxy aktivieren/deaktivieren
            Card(
              child: SwitchListTile(
                title: Text(l10n.proxySettingsEnable),
                subtitle: Text(l10n.proxySettingsEnableSubtitle),
                value: _proxyEnabled,
                onChanged: (value) => setState(() => _proxyEnabled = value),
              ),
            ),

            const SizedBox(height: 16),

            // System-Proxy vs. Manuelle Konfiguration
            if (_proxyEnabled) ...[
              Card(
                child: RadioGroup<bool>(
                  groupValue: _useSystemProxy,
                  onChanged: (value) {
                    // Manuelle Konfiguration ist veraltet und nicht mehr auswählbar.
                    if (value == true) setState(() => _useSystemProxy = true);
                  },
                  child: Column(
                    children: [
                      RadioListTile<bool>(
                        title: Text(l10n.proxySettingsUseSystemProxy),
                        subtitle: Text(l10n.proxySettingsUseSystemProxySubtitle),
                        value: true,
                      ),
                      RadioListTile<bool>(
                        title: Row(
                          children: [
                            Text(l10n.proxySettingsManualConfig),
                            const SizedBox(width: 8),
                            Icon(Icons.warning_amber, size: 20, color: Colors.orange.shade700),
                          ],
                        ),
                        subtitle: Text(
                          l10n.proxySettingsManualConfigDeprecated,
                          style: const TextStyle(color: Colors.deepOrange),
                        ),
                        value: false,
                      ),
                    ],
                  ),
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
                        Text(l10n.proxySettingsProxyServer, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _hostController,
                          decoration: InputDecoration(
                            labelText: l10n.proxySettingsHostLabel,
                            hintText: l10n.proxySettingsHostHint,
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.proxySettingsHostRequired;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _portController,
                          decoration: InputDecoration(
                            labelText: l10n.proxySettingsPortLabel,
                            hintText: l10n.proxySettingsPortHint,
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.proxySettingsPortRequired;
                            }
                            final port = int.tryParse(value);
                            if (port == null || port < 1 || port > 65535) {
                              return l10n.proxySettingsPortInvalid;
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
                          l10n.proxySettingsAuthTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.proxySettingsAuthHint,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: l10n.proxySettingsUsername,
                            border: const OutlineInputBorder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: l10n.proxySettingsPassword,
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
                        label: Text(
                          _isTesting ? l10n.proxySettingsTesting : l10n.proxySettingsTestConnection,
                        ),
                      ),

                      if (_testResult != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _testSuccess == true
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1),
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
                          Text(l10n.proxySettingsNotes),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.proxySettingsNotesBody),
                      const SizedBox(height: 8),
                      Text(
                        l10n.proxySettingsNotesRestart,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
          label: Text(l10n.proxySettingsSave),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
        ),
      ),
    );
  }
}
