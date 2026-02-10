# Proxy-Einschränkungen und Lösungen

## ⚠️ Wichtige Einschränkung: WebSocket-Unterstützung

Die TFM-App nutzt **zwei verschiedene Netzwerkprotokolle**:

1. **HTTP/HTTPS** - für normale API-Anfragen (Login, Datenabfrage)
2. **WebSocket (wss://)** - für Echtzeit-Datensynchronisation (PowerSync)

### Problem

**Dart's WebSocket-Implementierung unterstützt KEINE manuelle Proxy-Konfiguration!**

- ✅ **System-Proxy**: Funktioniert für HTTP UND WebSocket
- ❌ **Manuelle Proxy-Konfiguration**: Funktioniert NUR für HTTP, NICHT für WebSocket

### Auswirkung

Wenn Sie **manuelle Proxy-Konfiguration** verwenden:

- Login funktioniert (HTTP)
- Daten-Sync schlägt fehl (WebSocket)
- Fehlermeldung: `Failed host lookup: 'ci.thuenen.de'`

## ✅ Lösung für Landesdatennetze

### Empfohlene Konfiguration

**1. Windows-Systemproxy konfigurieren**

In den Windows-Systemeinstellungen:

- `Einstellungen` → `Netzwerk & Internet` → `Proxy`
- Proxy-Server aktivieren
- Adresse und Port eintragen (z.B. `proxy.sachsen-anhalt.de:8080`)
- Eventuell Authentifizierung konfigurieren

**2. In der TFM-App**

- Proxy-Einstellungen öffnen
- `Proxy aktivieren` ✅
- `System-Proxy verwenden` ✅ **← WICHTIG!**
- App neu starten

### Warum funktioniert nur System-Proxy?

Dart's WebSocket verwendet intern die Betriebssystem-Netzwerkschicht, die automatisch die Windows-Proxy-Einstellungen berücksichtigt. Die manuelle Konfiguration in der App kann nur den HTTP-Client konfigurieren, nicht aber die WebSocket-Verbindungen.

## 🧪 Test der Konfiguration

Nach der Konfiguration in der App auf "Verbindung testen" klicken:

**Erwartetes Ergebnis:**

```
✓ HTTP-Verbindung erfolgreich (200)
✓ WebSocket (PowerSync) funktioniert
```

**Bei Fehler:**

```
✓ HTTP-Verbindung erfolgreich (200)
✗ WebSocket: Failed host lookup
```

→ System-Proxy ist nicht korrekt konfiguriert

## 🔧 Troubleshooting

### WebSocket-Test schlägt fehl

**Mögliche Ursachen:**

1. **Proxy blockiert WebSocket-Verbindungen**
   - Lösung: IT-Abteilung bitten, WebSocket (CONNECT-Methode) zu erlauben
   - Host: `ci.thuenen.de`
   - Port: `443` (HTTPS/WSS)

2. **Windows-Proxy nicht korrekt konfiguriert**
   - Lösung: Überprüfen Sie die Windows-Einstellungen
   - Testen Sie mit Browser (z.B. Edge), ob `https://ci.thuenen.de` erreichbar ist

3. **Proxy-Authentifizierung erforderlich**
   - Lösung: Windows-Credential-Manager nutzen
   - `Systemsteuerung` → `Anmeldeinformationsverwaltung`
   - Windows-Anmeldeinformationen hinzufügen für Proxy-Server

### Alternative: Umgebungsvariablen (für IT-Administratoren)

Als Alternative können System-Administratoren Umgebungsvariablen setzen:

```powershell
# PowerShell (System-weit)
[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://proxy.example.com:8080", "Machine")
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://proxy.example.com:8080", "Machine")

# Mit Authentifizierung
[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://username:password@proxy.example.com:8080", "Machine")
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://username:password@proxy.example.com:8080", "Machine")
```

Dann App neu starten.

## 📧 Support für Sachsen-Anhalt

Bei Problemen kontaktieren Sie bitte:

- Thünen-Institut Support
- Oder Ihre lokale IT-Abteilung für Proxy-Konfiguration

**Wichtige Information für IT:**
Die App benötigt:

- Ausgehende HTTPS-Verbindungen zu `ci.thuenen.de:443`
- WebSocket-Upgrade-Fähigkeit (HTTP CONNECT-Methode)
- Ziel-URL: `wss://ci.thuenen.de/sync/`
