# Windows Troubleshooting Guide

## Common Issues and Solutions

### "Das Zeitlimit für die Semaphore wurde erreicht" (Semaphore Timeout Error)

**Problem**: Die App startet nicht und zeigt einen Semaphore-Timeout-Fehler.

**Ursache**: Dieser Fehler tritt auf, wenn `flutter_libserialport` beim App-Start versucht, COM-Ports zu scannen. Dies kann durch folgende Faktoren verschlimmert werden:

- Aktive VPN-Verbindung
- Bluetooth aktiviert
- Virtuelle COM-Ports (z.B. von Arduino IDE, USB-Geräten)
- Netzwerk-basierte COM-Ports
- Antivirus-Software

**Lösung (bereits implementiert)**:

- Serial Port Scanning erfolgt nun **verzögert** (lazy loading)
- Ports werden nur gescannt, wenn der Benutzer das GPS-Menü öffnet
- Alle SerialPort-Operationen haben nun **5-Sekunden-Timeouts**
- Bessere Fehlerbehandlung mit Benutzer-Feedback

**Was wurde behoben**:

- ✅ **App-Start**: Funktioniert jetzt auch mit aktivem VPN/Bluetooth
- ✅ **App-Crash**: Kein Absturz mehr bei Semaphore-Timeout
- ⚠️ **GPS Serial Port Scan**: Kann mit aktivem VPN immer noch timeout geben
  - Nach 5 Sekunden erscheint eine **klare Fehlermeldung** (kein Crash)
  - Vorschlag: "VPN deaktivieren oder andere Apps mit COM-Ports schließen"

**Wenn Serial Port Scanning im GPS-Menü fehlschlägt**:

1. **VPN temporär deaktivieren** für GPS-Verbindung
   - App-Start: ✅ Funktioniert mit VPN
   - GPS-Menü öffnen: ✅ Funktioniert mit VPN
   - Serial Port Scan: ⚠️ VPN kurz deaktivieren, dann scannen
   - Nach erfolgreicher GPS-Verbindung kann VPN wieder aktiviert werden

2. **Bluetooth temporär deaktivieren** (nur als letzter Ausweg)
   - Settings → Bluetooth & Devices → Bluetooth OFF
   - App starten
   - Bluetooth kann danach wieder aktiviert werden

3. **Virtuelle COM-Ports entfernen**
   - Geräte-Manager öffnen (Win + X → Geräte-Manager)
   - Unter "Anschlüsse (COM & LPT)" nachsehen
   - Ungenutzte oder problematische COM-Ports deaktivieren

4. **Antivirus-Ausnahme hinzufügen**
   - TFM-Installationsordner zur Ausnahmeliste hinzufügen
   - Pfad: `C:\Program Files\Terrestrial Forest Monitor\`

5. **Clean Install**
   - App vollständig deinstallieren
   - `C:\Users\<Username>\AppData\Local\Terrestrial Forest Monitor` löschen
   - Computer neu starten
   - App neu installieren **ohne VPN**

### SSL/TLS Certificate Errors

**Problem**: PowerSync kann keine Verbindung aufbauen ("CERTIFICATE_VERIFY_FAILED")

**Lösung**:

1. Im Startmenü → "Install SSL Certificates" ausführen
2. PowerShell-Skript mit Admin-Rechten bestätigen
3. App neu starten

Alternativ: Zertifikate manuell installieren:

```powershell
cd "C:\Program Files\Terrestrial Forest Monitor\certs"
.\install-certificates.ps1
```

### GPS Connection Issues

**Serial GPS-Geräte werden nicht erkannt**:

1. Überprüfen, ob das Gerät in "Geräte-Manager" → "Anschlüsse (COM & LPT)" sichtbar ist
2. Treiber für das GPS-Gerät installieren (falls nötig)
3. App neu starten und GPS-Menü öffnen (Serial Port Scan erfolgt erst dann)
4. Falls Timeout: VPN temporär deaktivieren und erneut scannen

**Internal GPS funktioniert nicht**:

- Windows-PCs haben normalerweise kein integriertes GPS
- Externe GPS-Geräte über USB/Bluetooth verwenden

### Performance Issues

**App startet langsam**:

1. Windows Defender Ausnahme hinzufügen
2. Hintergrund-Apps schließen
3. Festplatten-Speicherplatz überprüfen (min. 2GB frei)

## Debugging

**Log-Dateien**:

- In der App: Menü → Logs
- Fehler werden mit Kontext und Zeitstempel angezeigt
- Bei Problemen: Screenshot der Logs erstellen

**Detaillierte Logs aktivieren** (für Entwickler):

1. `.env` Datei im App-Ordner bearbeiten
2. `DEBUG_MODE=true` hinzufügen
3. App neu starten

## VPN-spezifische Hinweise

**FortiClient VPN / Corporate VPN**:

- ✅ **App-Start funktioniert jetzt mit VPN** (seit Version 1.0.68)
- ⚠️ Serial Port Scanning (im GPS-Menü) kann mit VPN Timeouts verursachen
- PowerSync benötigt VPN für Verbindung zum Server

**Empfohlener Workflow (NEU seit v1.0.68)**:

1. **App mit VPN starten** - funktioniert jetzt problemlos ✅
2. Bei Bedarf GPS-Menü öffnen
3. Falls Serial Port Scan fehlschlägt:
   - VPN **kurz** deaktivieren
   - "Refresh" im GPS-Menü klicken
   - GPS-Gerät verbinden
   - VPN wieder aktivieren
4. PowerSync synchronisiert Daten über VPN ✅

**Alter Workflow (vor v1.0.68 - nicht mehr nötig)**:

~~1. VPN deaktivieren~~  
~~2. App starten~~  
~~3. GPS-Verbindung herstellen~~  
~~4. VPN aktivieren~~

## Contact

Bei anhaltenden Problemen:

- Developer: [Kontaktinformationen]
- GitHub Issues: [Repository URL]
- Include: Windows-Version, VPN-Software, GPS-Gerät, Logs
