# Netzwerkprobleme in Landesnetzen - Detaillierte Technische Dokumentation

## Zusammenfassung

Dieses Dokument beschreibt die Netzwerkanforderungen und -konfiguration der TFM-App (Terrestrial Forest Monitor) und beantwortet häufige Fragen zu wiederkehrenden Verbindungsproblemen (Timeouts) in Landesdatennetzen.

---

## 1. Greift das Programm über einen Proxy auf das Internet zu oder erfolgt die Verbindung direkt?

### Antwort: **Beides ist möglich - konfigurierbar durch den Benutzer**

Die TFM-App bietet flexible Proxy-Unterstützung mit drei Konfigurationsmodi:

### 1.1 Direkte Verbindung (Standard für Home-Office/Privat)

- Ohne Proxy-Konfiguration verbindet sich die App direkt mit den externen Servern
- Geeignet für: Heimnetzwerke, mobile Datenverbindungen, Hotspots

### 1.2 System-Proxy (EMPFOHLEN für Landesdatennetze)

- Die App nutzt die Windows-Systemproxy-Einstellungen
- Konfiguration über: `Windows-Einstellungen → Netzwerk & Internet → Proxy`
- **Vorteil**: Unterstützt sowohl HTTP/HTTPS als auch WebSocket-Verbindungen
- **Automatische Erkennung**: Die App liest die Proxy-Einstellungen aus der Windows-Registry

#### Beispiel System-Proxy-Konfiguration:

```
Proxy-Server: proxy.sachsen-anhalt.de
Port: 8080
```

### 1.3 Manuelle Proxy-Konfiguration (Veraltet, nicht empfohlen)

- Manuelle Eingabe von Proxy-Server, Port und optional Zugangsdaten direkt in der App
- **Einschränkung**: Funktioniert NUR für HTTP/HTTPS, NICHT für WebSocket
- **Folge**: Login funktioniert, aber Datensynchronisation schlägt fehl

### 1.4 Umgebungsvariablen (für IT-Administratoren)

System-Administratoren können Proxy-Einstellungen auch über Umgebungsvariablen zentral vorgeben:

```powershell
# PowerShell (System-weit)
[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://proxy.example.com:8080", "Machine")
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://proxy.example.com:8080", "Machine")

# Mit Authentifizierung
[System.Environment]::SetEnvironmentVariable("HTTP_PROXY", "http://username:password@proxy.example.com:8080", "Machine")
[System.Environment]::SetEnvironmentVariable("HTTPS_PROXY", "http://username:password@proxy.example.com:8080", "Machine")
```

### 1.5 Warum schlägt die manuelle Konfiguration bei der Synchronisation fehl?

**Technischer Hintergrund:**

Die TFM-App verwendet zwei verschiedene Netzwerkprotokolle:

1. **HTTP/HTTPS** - für normale API-Anfragen (Login, Datenabfrage, REST API)
2. **WebSocket (wss://)** - für Echtzeit-Datensynchronisation via PowerSync

**Das Problem:**

- Dart's WebSocket-Implementierung (Programmiersprache der App) unterstützt **KEINE manuelle Proxy-Konfiguration**
- Die manuelle Konfiguration in der App kann nur den HTTP-Client konfigurieren
- WebSocket-Verbindungen verwenden intern die Betriebssystem-Netzwerkschicht

**Lösung:**

- Nur der **System-Proxy** wird von der Betriebssystem-Netzwerkschicht automatisch für WebSocket-Verbindungen verwendet
- Daher: System-Proxy IMMER verwenden in Unternehmensnetzen

---

## 2. Welcher Netzwerkport wird vom Programm genutzt?

### Antwort: **Port 443 (HTTPS/WSS)**

Die TFM-App nutzt ausschließlich den Standard-HTTPS-Port:

### 2.1 Verwendete Ports im Detail

| Protokoll                    | Port    | Verwendung                                | Richtung  | Erforderlich |
| ---------------------------- | ------- | ----------------------------------------- | --------- | ------------ |
| **HTTPS**                    | **443** | REST API, Login, Datenabfrage             | Ausgehend | ✅ Ja        |
| **WSS (WebSocket over SSL)** | **443** | Echtzeit-Datensynchronisation (PowerSync) | Ausgehend | ✅ Ja        |
| HTTP                         | 80      | Nicht verwendet                           | -         | ❌ Nein      |

### 2.2 Wichtige Informationen für Firewall-Konfiguration

**Erforderliche ausgehende Verbindungen:**

- **Port**: 443 (HTTPS/WSS)
- **Protokoll**: TCP
- **Richtung**: Ausgehend (Client → Server)
- **Verschlüsselung**: TLS/SSL (HTTPS, WSS)

**Besonderheit WebSocket:**

- WebSocket-Verbindungen beginnen als normale HTTPS-Verbindung (Port 443)
- Anschließend erfolgt ein Protocol Upgrade von HTTP zu WebSocket über die HTTP `CONNECT`-Methode
- **Proxy-Anforderung**: Der Proxy-Server muss die HTTP CONNECT-Methode für WebSocket-Upgrades unterstützen

### 2.3 Lokale Entwicklungsports (nur relevant für Entwickler)

Für lokale Entwicklung (nicht relevant für Produktivnutzer):

| Service            | Port  | Nur lokal |
| ------------------ | ----- | --------- |
| Supabase (lokal)   | 54321 | ✅        |
| PowerSync (lokal)  | 8181  | ✅        |
| PostgreSQL (lokal) | 5432  | ✅        |

---

## 3. Welche externen Adressen werden genutzt? (URL/Servernamen)

### Antwort: **ci.thuenen.de**

Die TFM-App kommuniziert ausschließlich mit einem einzigen Server:

### 3.1 Hauptserver-Adresse

**Host**: `ci.thuenen.de`

### 3.2 Verwendete URLs im Detail

#### Hauptserver (ci.thuenen.de)

| Zweck                         | URL                                   | Protokoll | Port |
| ----------------------------- | ------------------------------------- | --------- | ---- |
| **Supabase REST API**         | `https://ci.thuenen.de/rest/v1/`      | HTTPS     | 443  |
| **Supabase Auth**             | `https://ci.thuenen.de/auth/v1/`      | HTTPS     | 443  |
| **Supabase Storage**          | `https://ci.thuenen.de/storage/v1/`   | HTTPS     | 443  |
| **Supabase Functions**        | `https://ci.thuenen.de/functions/v1/` | HTTPS     | 443  |
| **PowerSync Synchronisation** | `https://ci.thuenen.de/sync/`         | HTTPS     | 443  |
| **PowerSync WebSocket**       | `wss://ci.thuenen.de/sync/`           | WSS       | 443  |

#### Kartendienste (optional, können lokal gecacht werden)

| Zweck                            | URL                                                                   | Protokoll   | Port |
| -------------------------------- | --------------------------------------------------------------------- | ----------- | ---- |
| **DOP - Luftbilder**             | `https://sg.geodatenzentrum.de/wms_dop__*`                            | HTTPS (WMS) | 443  |
| **DTK25 - Topographische Karte** | `https://sg.geodatenzentrum.de/wms_dtk25__*`                          | HTTPS (WMS) | 443  |
| **OpenCycleMap**                 | `https://[a-c].tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png` | HTTPS       | 443  |

**Hinweis zu Kartendiensten:**

- Diese Dienste werden NUR beim initialen Download von Kartenkacheln benötigt
- Nach dem Download sind die Karten offline verfügbar
- Die App funktioniert auch ohne Kartendienste (nur mit Markierungen auf leerem Hintergrund)
- DOP/DTK25 erfordern einen API-Schlüssel vom BKG (Bundesamt für Kartographie und Geodäsie)

### 3.3 Vollständige technische Konfiguration

Aus der App-Konfiguration ([config.dart](../lib/config.dart)):

```dart
{
  'name': 'Remote',
  'supabaseUrl': 'https://ci.thuenen.de',
  'powersyncUrl': 'https://ci.thuenen.de/sync/',
  'supabaseStorageBucket': 'validation',
  'database': 'postgres',
}
```

### 3.4 Externe Dienste im Überblick

**Kerndienste** (permanent erforderlich):

- ✅ **ci.thuenen.de** - Hauptserver für alle Daten und Synchronisation

**Kartendienste** (nur für Kartendownload):

- ✅ **sg.geodatenzentrum.de** - BKG Geodatenzentrum (DOP, DTK25)
- ✅ **tile-cyclosm.openstreetmap.fr** - OpenCycleMap Tiles

**KEINE Drittanbieter-Tracking:**

- ❌ Keine Google-Dienste (Analytics, Maps, etc.)
- ❌ Keine Amazon-Services
- ❌ Keine Microsoft-Cloud-Dienste
- ❌ Keine Analytics oder Tracking-Dienste

**Wichtig**: Nach dem initialen Download der Kartenkacheln arbeitet die App vollständig offline. Die Kartendienste werden nur beim ersten Download benötigt.

### 3.5 DNS-Auflösung

**Hostname**: `ci.thuenen.de`

Für die IT-Abteilung: Der Hostname muss über DNS aufgelöst werden können. Bei DNS-Problemen in geschlossenen Netzwerken:

```
Host: ci.thuenen.de
Typ: A-Record (IPv4) oder AAAA-Record (IPv6)
```

---

## 4. Netzwerk-Anforderungen für IT-Abteilungen

### Zusammenfassung der Firewall-Regeln

Für den reibungslosen Betrieb der TFM-App in Landesdatennetzen:

#### Ausgehende Verbindungen erlauben:

**Kerndienste (permanent erforderlich):**

```
Protokoll: HTTPS (TCP)
Ziel: ci.thuenen.de
Port: 443
Verschlüsselung: TLS 1.2 oder höher

Protokoll: WebSocket Secure (WSS)
Ziel: ci.thuenen.de
Port: 443
Upgrade: HTTP CONNECT-Methode erforderlich
```

**Kartendienste (optional, nur für Karten-Download):**

```
Protokoll: HTTPS (TCP)
Ziele:
  - sg.geodatenzentrum.de
  - tile-cyclosm.openstreetmap.fr
Port: 443
Verschlüsselung: TLS 1.2 oder höher
Verwendung: Download von Kartenkacheln (einmalig)
```

#### Proxy-Anforderungen:

1. **Port 443** für HTTPS-Verkehr zu `ci.thuenen.de` freigeben
2. **HTTP CONNECT-Methode** für WebSocket-Upgrade erlauben
3. **WebSocket-Verbindungen** nicht blockieren
4. **TLS/SSL-Inspektion**: Falls aktiv, kann WebSocket-Verbindung beeinträchtigen

### 4.1 Verbindungstest

In der App ist ein integrierter Verbindungstest verfügbar:

**Navigation**: `Einstellungen → Proxy-Einstellungen → Verbindung testen`

**Erwartetes Ergebnis bei korrekter Konfiguration:**

```
✅ HTTP-Verbindung erfolgreich (200)
✅ WebSocket (PowerSync) funktioniert
```

**Bei Fehlkonfiguration:**

```
✅ HTTP-Verbindung erfolgreich (200)
✗ WebSocket: Failed host lookup: 'ci.thuenen.de'
```

### 4.2 Häufige Fehlerursachen

| Fehlermeldung          | Ursache                                          | Lösung                                                       |
| ---------------------- | ------------------------------------------------ | ------------------------------------------------------------ |
| `Failed host lookup`   | DNS-Auflösung fehlgeschlagen                     | DNS-Server konfigurieren oder Netzwerk prüfen                |
| `Connection timeout`   | Port 443 blockiert oder Proxy nicht konfiguriert | Firewall-Regel prüfen, System-Proxy einstellen               |
| `Bad Gateway (502)`    | Proxy-Konfigurationsproblem                      | Proxy-Administrator kontaktieren                             |
| `SSL Handshake failed` | SSL-Inspektion oder veraltete TLS-Version        | TLS 1.2+ erlauben, SSL-Inspektion für WebSocket deaktivieren |

---

## 5. Schritt-für-Schritt-Anleitung für Landesdatennetze

### Für Endbenutzer (z.B. Sachsen-Anhalt)

#### Schritt 1: Windows-Systemproxy konfigurieren

1. Öffnen Sie `Windows-Einstellungen`
2. Navigieren Sie zu `Netzwerk & Internet → Proxy`
3. Aktivieren Sie `Proxyserver`
4. Geben Sie die von Ihrer IT-Abteilung erhaltenen Daten ein:
   - **Adresse**: z.B. `proxy.sachsen-anhalt.de`
   - **Port**: z.B. `8080` oder `3128`
5. Optional: Konfigurieren Sie Authentifizierung im Windows Credential Manager

#### Schritt 2: TFM-App konfigurieren

1. Öffnen Sie die TFM-App
2. Navigieren Sie zu `Einstellungen → Proxy-Einstellungen`
3. Aktivieren Sie: ✅ `Proxy aktivieren`
4. Wählen Sie: ✅ `System-Proxy verwenden` **← WICHTIG!**
5. Klicken Sie auf `Verbindung testen`
6. Bei Erfolg: `Einstellungen speichern`
7. **App neu starten** (erforderlich!)

#### Schritt 3: Funktion überprüfen

- Login sollte funktionieren
- Datensynchronisation sollte aktiv sein
- Keine Fehlermeldungen zu WebSocket

### Für IT-Administratoren

#### Erforderliche Proxy-Konfiguration:

```
Zielhost: ci.thuenen.de
Port: 443
Protokoll: HTTPS, WSS
HTTP-Methoden: GET, POST, PUT, DELETE, PATCH, CONNECT
WebSocket-Upgrade: Erlauben
TLS-Version: 1.2 oder höher
```

#### Optional: Zentrale Proxy-Vorgabe via GPO

Umgebungsvariablen können über Gruppenrichtlinien gesetzt werden:

```
Variable: HTTP_PROXY
Wert: http://proxy.example.com:8080

Variable: HTTPS_PROXY
Wert: http://proxy.example.com:8080
```

---

## 6. Troubleshooting

### Problem: WebSocket-Verbindung schlägt fehl

**Symptom**: Login funktioniert, aber Synchronisation nicht

**Mögliche Ursachen:**

1. **Proxy blockiert WebSocket-Verbindungen**
   - **Lösung**: IT-Abteilung bitten, WebSocket (CONNECT-Methode) für `ci.thuenen.de:443` zu erlauben

2. **Windows-Proxy nicht korrekt konfiguriert**
   - **Lösung**: Windows-Einstellungen überprüfen, mit Browser testen: `https://ci.thuenen.de`

3. **Manuelle Proxy-Konfiguration statt System-Proxy**
   - **Lösung**: Auf `System-Proxy verwenden` umstellen

4. **Proxy-Authentifizierung erforderlich**
   - **Lösung**: Anmeldeinformationen im Windows Credential Manager hinterlegen
   - Navigation: `Systemsteuerung → Anmeldeinformationsverwaltung → Windows-Anmeldeinformationen`

5. **SSL/TLS-Inspektion des Proxys**
   - **Lösung**: WebSocket-Verbindungen von SSL-Inspektion ausnehmen

### Problem: Allgemeine Verbindungsprobleme

**Diagnose-Tools:**

1. **Windows-Terminal/PowerShell**:

   ```powershell
   # DNS-Auflösung testen (Hauptserver)
   nslookup ci.thuenen.de

   # DNS-Auflösung testen (Kartendienste)
   nslookup sg.geodatenzentrum.de
   nslookup tile-cyclosm.openstreetmap.fr

   # HTTPS-Verbindung testen
   Test-NetConnection -ComputerName ci.thuenen.de -Port 443
   Test-NetConnection -ComputerName sg.geodatenzentrum.de -Port 443

   # Proxy-Umgebungsvariablen prüfen
   Get-ChildItem Env: | Where-Object {$_.Name -like "*PROXY*"}
   ```

2. **Browser-Test**:
   - Öffnen Sie: `https://ci.thuenen.de/rest/v1/`
   - Erwartete Antwort: HTTP 200 oder 400 (nicht 404 oder Timeout)

3. **TFM-App Verbindungstest**:
   - `Einstellungen → Proxy-Einstellungen → Verbindung testen`

### Problem: Karten-Download schlägt fehl

**Symptom**: Karten können nicht heruntergeladen werden, aber Login und Synchronisation funktionieren

**Mögliche Ursachen:**

1. **Kartendienste durch Firewall blockiert**
   - **Lösung**: IT-Abteilung bitten, folgende Hosts freizugeben:
     - `sg.geodatenzentrum.de:443`
     - `tile-cyclosm.openstreetmap.fr:443`

2. **Fehlende DNS-Auflösung**
   - **Lösung**: DNS-Server überprüfen, ggf. externe DNS-Server (z.B. 8.8.8.8) erlauben

3. **Proxy blockiert WMS-Anfragen**
   - **Lösung**: Proxy-Administrator kontaktieren, WMS-Protokoll erlauben

**Workaround**: Die App funktioniert auch ohne Karten-Download (nur mit Markierungen/POIs auf leerem/einfarbigem Hintergrund)

---

**Kerndienste (permanent):**

- **Zielhost**: `ci.thuenen.de`
- **Port**: `443` (HTTPS/WSS)
- **Protokolle**: HTTPS, WebSocket Secure (WSS)
- **HTTP-Methode**: CONNECT für WebSocket-Upgrade
- **TLS-Version**: 1.2 oder höher
- **WebSocket-URL**: `wss://ci.thuenen.de/sync/`

**Kartendienste (optional, nur für Kartendownload):**

- **Zielhosts**:
  - `sg.geodatenzentrum.de` (BKG Geodatenzentrum)
  - `tile-cyclosm.openstreetmap.fr` (OpenCycleMap)
- **Port**: `443` (HTTPS)
- **Protokoll**: HTTPS
- **TLS-Version**: 1.2 oder höheran:

- **Thünen-Institut Support**: [Kontaktdaten einfügen]
- **Ihre lokale IT-Abteilung** für Proxy- und Firewall-Fragen

### Für IT-Administratoren

**Wichtige Informationen für Firewall/Proxy-Konfiguration:**

- **Zielhost**: `ci.thuenen.de`
- **Port**: `443` (HTTPS/WSS)
- **Protokolle**: HTTPS, WebSocket Secure (WSS)
- **HTTP-Methode**: CONNECT für WebSocket-Upgrade
- **TLS-Version**: 1.2 oder höher
- **WebSocket-URL**: `wss://ci.thuenen.de/sync/`

Bei technischen Fragen zur Infrastruktur:

- **Thünen-Institut IT**: [Kontaktdaten einfügen]

---

## 8. Anhang: Technische Details

### 8.1 Verwendete Technologien

- **Frontend**: Flutter/Dart
- **Backend**: Supabase (PostgreSQL, REST API, Auth)
- **Synchronisation**: PowerSync (WebSocket-basiert)
- **Verschlüsselung**: TLS 1.2+ (HTTPS/WSS)
- **Authentifizierung**: JWT (JSON Web Tokens)

### 8.2 Datenspeicherung

- **Online**: PostgreSQL-Datenbank auf `ci.thuenen.de`
- **Offline**: Lokale SQLite-Datenbank auf dem Gerät
- **Synchronisation**: Bidirektional via PowerSync (Conflict Resolution)

### 8.3 Sicherheit

- Alle Verbindungen sind verschlüsselt (HTTPS/WSS über TLS)
- Benutzer-Authentifizierung via JWT-Token
- Row-Level Security (RLS) in der Datenbank
- Kein Datenverkehr zu Drittanbietern

### 8.4 Netzwerk-Flow-Diagramm

```
┌─────────────────┐
│   TFM-App       │
│  (Windows)      │
└────────┬────────┘
         │
         │ Proxy?
         ├──────────────────┐
         │                  │
    ┌────▼────┐      ┌──────▼──────┐
    │ Direkt  │      │ System-Proxy│
    └────┬────┘      └──────┬──────┘
         │                  │
         └────────┬─────────┘
                  │
         Port 443 │ (HTTPS/WSS)
                  │
         ┌────────▼──────────────────────────────────────┐
         │                                                │
         │  Permanente Verbindungen:                      │
         │  ┌──────────────────────┐                      │
         │  │  ci.thuenen.de       │                      │
         │  │  - Supabase API      │                      │
         │  │  - PowerSync (WSS)   │                      │
         │  └──────────────────────┘                      │
         │                                                │
         │  Optionale Verbindungen (Karten-Download):    │
         │  ┌──────────────────────────────────────────┐ │
         │  │  sg.geodatenzentrum.de                   │ │
         │  │  - DOP (Luftbilder)                      │ │
         │  │  - DTK25 (Topographie)                   │ │
         │  └──────────────────────────────────────────┘ │
         │  ┌──────────────────────────────────────────┐ │
         │  │  tile-cyclosm.openstreetmap.fr           │ │
         │  │  - OpenCycleMap Kacheln                  │ │
         │  └──────────────────────────────────────────┘ │
         │                                                │
         └────────────────────────────────────────────────┘
```

**Hinweis**: Kartendienste werden nur einmalig zum Download der Kacheln benötigt. Danach arbeitet die App vollständig offline mit lokalem Kartencache.

---

## Dokumenten-Metadaten

- **Version**: 1.0
- **Erstellt**: 2026-02-10
- **Autor**: TFM-Entwicklungsteam
- **Zielgruppe**: IT-Administratoren, Endbenutzer in Landesdatennetzen

---

## Änderungshistorie

| Version | Datum      | Änderung                        |
| ------- | ---------- | ------------------------------- |
| 1.0     | 2026-02-10 | Initiale Dokumentation erstellt |
