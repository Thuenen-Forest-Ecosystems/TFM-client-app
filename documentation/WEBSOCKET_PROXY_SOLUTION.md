# WebSocket Proxy-Lösung

## Problem

Dart's `WebSocket.connect()` unterstützt keine manuelle Proxy-Konfiguration. Es liest nur aus:

- System-Proxy-Einstellungen (Windows Registry)
- Umgebungsvariablen (HTTP_PROXY, HTTPS_PROXY)

PowerSync verwendet WebSockets intern, die wir nicht direkt konfigurieren können.

## Mögliche Lösungen

### Lösung 1: System-Proxy (AKTUELL EMPFOHLEN)

✅ **Funktioniert sofort ohne Code-Änderungen**

User konfiguriert Windows-Systemproxy → App nutzt diesen automatisch.

### Lösung 2: Lokaler Tunnel-Proxy (IMPLEMENTIERBAR)

Die App startet einen lokalen HTTP/WebSocket-Proxy-Server:

```
TFM App → localhost:9999 (lokaler Proxy) → Unternehmens-Proxy → ci.thuenen.de
```

**Vorteile:**

- Manuelle Proxy-Konfiguration funktioniert
- Keine System-Proxy-Konfiguration nötig
- Volle Kontrolle über Authentifizierung

**Nachteile:**

- Komplexere Implementierung
- Zusätzlicher Prozess/Thread in der App
- Erhöhter Memory-Verbrauch

### Lösung 3: Umgebungsvariablen beim App-Start

Die App setzt `HTTP_PROXY` und `HTTPS_PROXY` VOR dem ersten WebSocket-Connect.

**Problem:** `Platform.environment` ist read-only in Dart!

**Workaround:** Launcher-Script erstellen:

```powershell
# tfm_launcher.bat
@echo off
set HTTP_PROXY=http://proxy.example.com:8080
set HTTPS_PROXY=http://proxy.example.com:8080
start tfm.exe
```

Die App könnte dieses Script generieren basierend auf den manuellen Einstellungen.

## Empfohlene Implementierung: Lokaler Tunnel-Proxy

### Architektur

```dart
class LocalProxyTunnel {
  HttpServer? _server;
  ProxyConfig _config;

  Future<void> start() async {
    _server = await HttpServer.bind('127.0.0.1', 9999);
    _server!.listen((request) async {
      if (request.headers.value('Upgrade')?.toLowerCase() == 'websocket') {
        await _handleWebSocket(request);
      } else {
        await _handleHttp(request);
      }
    });
  }

  Future<void> _handleWebSocket(HttpRequest request) async {
    // 1. Establish connection to corporate proxy using HTTP CONNECT
    final socket = await Socket.connect(_config.host, _config.port);

    // 2. Send CONNECT request
    socket.write('CONNECT ${request.uri.host}:${request.uri.port ?? 443} HTTP/1.1\r\n');
    socket.write('Host: ${request.uri.host}:${request.uri.port ?? 443}\r\n');

    if (_config.username.isNotEmpty) {
      final auth = base64.encode(utf8.encode('${_config.username}:${_config.password}'));
      socket.write('Proxy-Authorization: Basic $auth\r\n');
    }

    socket.write('\r\n');
    await socket.flush();

    // 3. Read CONNECT response
    final response = await socket.first;
    // Check if 200 Connection Established

    // 4. Upgrade client request to WebSocket
    final ws = await WebSocketTransformer.upgrade(request);

    // 5. Pipe data bidirectionally
    socket.pipe(ws);
    ws.pipe(socket);
  }
}
```

### PowerSync Konfiguration

PowerSync müsste dann auf den lokalen Proxy zeigen:

```dart
PowerSyncCredentials(
  endpoint: 'http://localhost:9999/sync/', // Statt ci.thuenen.de
  token: token,
  userId: userId,
  expiresAt: expiresAt,
);
```

### Voraussetzungen

1. PowerSync muss erlauben, die Endpoint-URL zu ändern
2. Lokaler Proxy muss SSL/TLS-Verschlüsselung handhaben
3. Proxy muss HTTP CONNECT-Methode für Tunneling unterstützen

## Entscheidung

**Für Version 1.0.0+58: System-Proxy verwenden**

Begründung:

- Funktioniert sofort
- Keine zusätzliche Komplexität
- Standard in Unternehmensumgebungen

**Für zukünftige Version (optional): Lokaler Tunnel-Proxy**

Falls Sachsen-Anhalt berichtet, dass System-Proxy nicht funktioniert, können wir die lokale Proxy-Lösung implementieren.

## Test-Plan für Sachsen-Anhalt

1. **System-Proxy testen:**
   - Windows-Proxy konfigurieren
   - TFM-App starten mit "System-Proxy verwenden"
   - Verbindungstest durchführen
   - Falls erfolgreich → Fertig!

2. **Falls fehlgeschlagen:**
   - Proxy-Logs prüfen: Blockiert Proxy WebSocket (CONNECT)?
   - Falls ja: IT bitten, WebSocket zu erlauben
   - Falls nein: Lokalen Tunnel-Proxy implementieren (Version 1.1.0)
