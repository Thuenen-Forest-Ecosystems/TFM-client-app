# Proxy-Unterstützung für TFM Windows-App

## ⚠️ WICHTIG: WebSocket-Einschränkung

**Die manuelle Proxy-Konfiguration funktioniert NUR für HTTP, NICHT für WebSocket!**

Die TFM-App nutzt:

- **HTTP/HTTPS** für Login und API-Anfragen ✅
- **WebSocket (wss://)** für Datensynchronisation (PowerSync) ⚠️

**Lösung:** Verwenden Sie **System-Proxy** (siehe unten) statt manueller Konfiguration!

## Überblick

Die TFM Windows-App unterstützt Proxy-Konfiguration für den Einsatz in Landesdatennetzen und anderen proxy-geschützten Netzwerken.

## Funktionen

- ✅ **Automatische System-Proxy-Erkennung** (EMPFOHLEN - unterstützt WebSocket)
- ⚠️ **Manuelle Proxy-Konfiguration** (nur HTTP, WebSocket funktioniert nicht!)
- ✅ **Proxy-Authentifizierung** über Windows Credential Manager
- ✅ **Verbindungstest** (HTTP + WebSocket)
- ✅ **Umgebungsvariablen-Support**

## Verwendung

### Für Anwender (Landesdatennetz Sachsen-Anhalt)

**EMPFOHLENE KONFIGURATION:**

1. **Konfigurieren Sie den Windows-Systemproxy** (siehe unten)
2. **Starten Sie die TFM-App**
3. **VOR dem Login:** Klicken Sie auf **"Netzwerk-Einstellungen (Proxy)"**
4. **Aktivieren Sie "Proxy aktivieren"** ✅
5. **Wählen Sie "System-Proxy verwenden"** ✅ (Standard)
6. **Testen Sie die Verbindung** - Sie sollten sehen:
   ```
   ✓ HTTP-Verbindung erfolgreich (200)
   ✓ WebSocket (PowerSync) funktioniert
   ```
7. **Speichern Sie die Einstellungen**
8. **Starten Sie die App neu** (oder klicken Sie auf "Anwendung schließen")

### System-Proxy unter Windows konfigurieren

Falls noch nicht geschehen, können Sie den System-Proxy in Windows wie folgt einrichten:

1. Öffnen Sie die **Systemsteuerung**
2. Wählen Sie **Internetoptionen**
3. Gehen Sie zum Tab **Verbindungen**
4. Klicken Sie auf **LAN-Einstellungen**
5. Aktivieren Sie **Proxyserver für LAN verwenden**
6. Geben Sie die Proxy-Adresse und den Port ein
7. Klicken Sie auf **OK**

### Manuelle Proxy-Konfiguration (⚠️ NICHT EMPFOHLEN)

**WARNUNG:** Manuelle Konfiguration funktioniert nur für HTTP-Anfragen. Die Datensynchronisation (WebSocket) wird NICHT funktionieren!

Nur verwenden für Test-Zwecke:

1. Wählen Sie **"Manuelle Konfiguration"**
2. Geben Sie **Host/IP-Adresse** des Proxys ein (z.B. `proxy.sachsen-anhalt.de`)
3. Geben Sie den **Port** ein (z.B. `8080`)
4. Falls erforderlich: Geben Sie **Benutzername** und **Passwort** ein
5. **Testen Sie die Verbindung** - WebSocket-Test wird fehlschlagen!
6. **Speichern** und **App neu starten**

### Verbindung testen

Verwenden Sie den "Verbindung testen"-Button, um zu prüfen, ob:

- Der Proxy erreichbar ist
- Die Authentifizierung funktioniert
- Eine Verbindung zu ci.thuenen.de hergestellt werden kann

## Umgebungsvariablen (Alternative)

Die App unterstützt auch Standard-Umgebungsvariablen:

```bash
HTTP_PROXY=http://proxy.example.com:8080
HTTPS_PROXY=http://proxy.example.com:8080
NO_PROXY=localhost,127.0.0.1,.local
```

Diese können in der Windows-Systemsteuerung unter "Systemumgebungsvariablen" gesetzt werden.

## Technische Details

### Implementierung

Die Proxy-Unterstützung wurde in folgenden Komponenten implementiert:

- **`lib/services/proxy_service.dart`**: Zentrale Proxy-Verwaltung
  - Liest und speichert Proxy-Konfiguration
  - Konfiguriert HttpClient
  - Testet Proxy-Verbindungen
- **`lib/screens/proxy_settings.dart`**: Benutzeroberfläche
  - Proxy aktivieren/deaktivieren
  - System-Proxy vs. manuelle Konfiguration
  - Authentifizierung
  - Verbindungstest
- **`lib/main.dart`**: HttpClient-Integration
  - Custom `MyHttpOverrides` konfiguriert Proxy bei jedem HTTP-Request
  - Unterstützt System-Proxy-Erkennung
  - Umgebungsvariablen-Support

### Proxy-Priorität

Die App verwendet folgende Reihenfolge für Proxy-Konfiguration:

1. **Manuelle Konfiguration** (falls aktiviert und konfiguriert)
2. **Umgebungsvariablen** (`HTTP_PROXY`, `HTTPS_PROXY`)
3. **Windows-System-Proxy** (Registry)
4. **Direkte Verbindung** (kein Proxy)

### Authentifizierung

- **Basic Authentication** wird unterstützt
- Credentials werden sicher in SharedPreferences gespeichert
- Automatische Authentifizierung bei jedem Request
- System-Proxy verwendet Windows Credential Manager

## Fehlerbehebung

### Problem: "Failed host lookup: 'ci.thuenen.de'"

**Lösung**:

- Aktivieren Sie die Proxy-Einstellungen
- Verwenden Sie "System-Proxy" falls Windows-Proxy konfiguriert ist
- Oder konfigurieren Sie den Proxy manuell

### Problem: Proxy-Test schlägt fehl

**Überprüfen Sie**:

- Ist die Proxy-Adresse korrekt?
- Ist der Port richtig?
- Sind Benutzername/Passwort erforderlich?
- Ist der Proxy vom Netzwerk aus erreichbar?

### Problem: Verbindung funktioniert nicht nach Neustart

**Lösung**:

- Überprüfen Sie die gespeicherten Einstellungen
- Testen Sie die Verbindung erneut
- Prüfen Sie die Log-Dateien (Einstellungen → Logs)

### Problem: Authentifizierung schlägt fehl

**Überprüfen Sie**:

- Sind die Credentials korrekt?
- Verwendet der Proxy Basic Authentication?
- Ist das Passwort abgelaufen?

## Logs

Alle Proxy-Aktivitäten werden geloggt. Zugriff über:

**Einstellungen → Logs**

Relevante Log-Einträge:

- 🌐 Proxy-Konfiguration
- 🔐 Authentifizierung
- ✅ Erfolgreiche Verbindungen
- ❌ Fehler und Warnungen

## Support

Bei Problemen wenden Sie sich an:

- **E-Mail**: ti-waldmonitoring@thuenen.de
- **Dokumentation**: https://ci.thuenen.de/TFM-Documentation

## Changelog

### Version 1.0.0+58 (Januar 2026)

- ✨ Neu: Proxy-Unterstützung hinzugefügt
- ✨ Neu: System-Proxy Auto-Detection
- ✨ Neu: Manuelle Proxy-Konfiguration
- ✨ Neu: Proxy-Authentifizierung
- ✨ Neu: Verbindungstest
- ✨ Neu: Umgebungsvariablen-Support
- 🐛 Fix: "Failed host lookup" in proxy-geschützten Netzwerken
