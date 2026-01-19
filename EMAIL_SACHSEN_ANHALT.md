# E-Mail-Antwort an Sachsen-Anhalt

**Betreff:** Re: Terrestrial Forest Monitor - Proxy-Unterstützung implementiert

---

Sehr geehrte Damen und Herren,

vielen Dank für Ihre Anfrage bezüglich der Proxy-Unterstützung im Terrestrial Forest Monitor.

Wir freuen uns, Ihnen mitteilen zu können, dass wir **vollständige Proxy-Unterstützung** in die Windows-Software implementiert haben. Die Anwendung kann nun problemlos in proxy-geschützten Netzwerken wie dem Landesdatennetz Sachsen-Anhalt verwendet werden.

## Was wurde umgesetzt?

✅ **Automatische System-Proxy-Erkennung**

- Die Software nutzt automatisch die in Windows konfigurierten Proxy-Einstellungen
- Keine manuelle Konfiguration in der App notwendig

✅ **Manuelle Proxy-Konfiguration** (optional)

- Falls gewünscht, kann der Proxy auch manuell in der App konfiguriert werden
- Unterstützt Authentifizierung mit Benutzername/Passwort

✅ **Verbindungstest**

- Integrierter Test zur Überprüfung der Proxy-Konfiguration

## Wie verwenden Sie die Proxy-Funktion?

### Schnellstart (empfohlen):

1. Installieren Sie das **nächste Update** der TFM-Software (Version 1.0.0+58)
2. Starten Sie die Anwendung
3. Navigieren Sie zu **Einstellungen** (Profil-Symbol)
4. Klicken Sie auf **"Proxy-Einstellungen"**
5. Aktivieren Sie **"Proxy aktivieren"**
6. Wählen Sie **"System-Proxy verwenden"**
7. **Speichern** und **App neu starten**

Die Software verwendet dann automatisch die in Windows konfigurierten Proxy-Einstellungen Ihres Landesdatennetzes.

### Alternative: Manuelle Konfiguration

Falls die automatische Erkennung nicht funktioniert, können Sie den Proxy auch manuell konfigurieren:

1. Wählen Sie "Manuelle Konfiguration"
2. Geben Sie Proxy-Host und Port ein
3. Optional: Benutzername und Passwort
4. Testen Sie die Verbindung
5. Speichern und neu starten

## Wann ist das Update verfügbar?

Das Update mit Proxy-Unterstützung wird in den nächsten Tagen als **Version 1.0.0+58** veröffentlicht:

- **Download**: https://github.com/Thuenen-Forest-Ecosystems/TFM-client-app/releases/latest

## Dokumentation

Eine ausführliche Anleitung zur Proxy-Konfiguration finden Sie in:

- **PROXY_SUPPORT.md** (im App-Verzeichnis nach Installation)
- Online-Dokumentation: https://ci.thuenen.de/TFM-Documentation

## Support

Bei Fragen oder Problemen stehen wir Ihnen gerne zur Verfügung:

- **E-Mail**: ti-waldmonitoring@thuenen.de
- **Dokumentation**: https://ci.thuenen.de/TFM-Documentation

Wir hoffen, dass Sie den Terrestrial Forest Monitor nun erfolgreich im Landesdatennetz Sachsen-Anhalt einsetzen können.

Mit freundlichen Grüßen

---

## Technische Details (für IT-Abteilung)

Die Implementierung unterstützt:

- Windows-System-Proxy (Registry)
- Umgebungsvariablen (HTTP_PROXY, HTTPS_PROXY, NO_PROXY)
- Basic Authentication
- Proxy Auto-Configuration (PAC) über System-Einstellungen
- HTTPS-Verbindungen über Proxy
- WebSocket-Verbindungen über Proxy (für PowerSync)

Die Software verwendet Dart's `HttpClient` mit:

- `HttpClient.findProxyFromEnvironment()` für System-Proxy
- `HttpClient.addProxyCredentials()` für Authentifizierung
- Zertifikat-Validierung bleibt aktiv (kein Security-Downgrade)

Logs aller Proxy-Aktivitäten sind in der App unter "Einstellungen → Logs" einsehbar.
