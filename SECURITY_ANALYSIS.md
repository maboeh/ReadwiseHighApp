# Sicherheitsanalyse - ReadwiseHighApp

**Datum:** 2026-01-25
**Analysiert von:** Claude Security Audit
**App-Version:** Aktueller Stand (commit 7f46286)
**Letzte Aktualisierung:** 2026-01-25 (Security Fixes implementiert)

---

## Zusammenfassung

Die ReadwiseHighApp ist eine iOS/macOS-Anwendung zur Anzeige von Readwise-Highlights. Die Sicherheitsanalyse basiert auf den **OWASP Mobile Top 10** Richtlinien und allgemeinen iOS-Sicherheitspraktiken.

### Risikobewertung (nach Fixes)

| Kategorie | Vorher | Nachher | Status |
|-----------|--------|---------|--------|
| Datenspeicherung | ⚠️ Mittel | ✅ Gut | BEHOBEN |
| Netzwerkkommunikation | ⚠️ Mittel | ✅ Gut | BEHOBEN |
| Authentifizierung | ✅ Gut | ✅ Gut | - |
| Code-Qualität | ⚠️ Mittel | ✅ Gut | BEHOBEN |
| Logging/Debug | ⚠️ Mittel | ✅ Gut | BEHOBEN |

### Behobene Sicherheitsprobleme (Commit 2846c9e)

| # | Problem | Fix | Datei |
|---|---------|-----|-------|
| 1 | Fehlende Keychain Access Controls | `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly` | KeychainHelper.swift |
| 2 | Kein Certificate Pinning | CertificatePinningDelegate implementiert | ReadwiseAPIService.swift |
| 3 | Debug-Logs in Production | `#if DEBUG` Wrapper | Mehrere Dateien |
| 4 | Unverschlüsselter Disk-Cache | `NSFileProtectionComplete` | ImageCacheManager.swift |
| 5 | API-Key vor Validierung gespeichert | Speicherung nach Server-Check | APIKeyView.swift |
| 6 | Unsichere Runtime-Reflection | Direkte Referenzen | NetworkMonitor.swift |

---

## Detaillierte Sicherheitsanalyse

### 1. Authentifizierung & Credential Management

#### ✅ Positiv: Keychain-Nutzung
Die App speichert den API-Key korrekt im iOS Keychain (`KeychainHelper.swift:10-25`):
```swift
let query: [String: Any] = [
    kSecClass as String: kSecClassGenericPassword,
    kSecAttrService as String: service,
    kSecAttrAccount as String: account,
    kSecValueData as String: data
]
```

#### ⚠️ Problem 1: Fehlende Keychain-Zugriffskontrollen
**Schweregrad: Mittel**
**Datei:** `KeychainHelper.swift:12-17`

Der Keychain-Eintrag hat keine expliziten Zugriffskontrollen (`kSecAttrAccessible`). Standardmäßig wird `kSecAttrAccessibleWhenUnlocked` verwendet, was bedeutet:
- Der Key ist im Backup enthalten (sofern nicht verschlüsselt)
- Kein biometrischer Schutz

**Empfehlung:**
```swift
// Empfohlene Konfiguration hinzufügen:
kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
// Oder für höchste Sicherheit:
// kSecAttrAccessControl mit biometrischer Authentifizierung
```

---

### 2. Netzwerkkommunikation

#### ✅ Positiv: HTTPS-Nutzung
Alle API-Aufrufe verwenden HTTPS (`ReadwiseAPIService.swift:64`):
```swift
private let baseURL = "https://readwise.io/api/v2/"
```

#### ⚠️ Problem 2: Kein Certificate Pinning
**Schweregrad: Mittel**
**Datei:** `ReadwiseAPIService.swift`, `ImageCacheManager.swift`

Die App verlässt sich vollständig auf das System-Trust-Store ohne Certificate Pinning. Dies macht die App anfällig für:
- Man-in-the-Middle (MITM) Angriffe
- Compromised Certificate Authorities
- SSL-Interception durch Proxies

**Empfehlung:**
Implementierung von Certificate Pinning für die Readwise-API:
```swift
// URLSessionDelegate mit pinnedCertificates implementieren
// Oder NSAppTransportSecurity mit pinnedDomains in Info.plist
```

#### ⚠️ Problem 3: API-Key im HTTP Header ohne zusätzliche Sicherheit
**Schweregrad: Niedrig**
**Datei:** `ReadwiseAPIService.swift:130`

```swift
request.addValue("Token \(getAPIKey())", forHTTPHeaderField: "Authorization")
```

Der API-Key wird bei jedem Request im Klartext übertragen. Obwohl HTTPS verwendet wird, besteht bei einem MITM-Angriff das Risiko des Key-Diebstahls.

---

### 3. Datenspeicherung & Cache

#### ⚠️ Problem 4: Unverschlüsselter Disk-Cache für Bilder
**Schweregrad: Mittel**
**Datei:** `ImageCacheManager.swift:86-88, 204-232`

```swift
let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
diskCacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")
```

Bilder werden unverschlüsselt auf dem Dateisystem gespeichert:
- Pfad: `/Library/Caches/ImageCache/`
- Format: PNG-Dateien mit SHA256-Hash als Dateiname
- Keine Verschlüsselung at-rest

**Risiko:** Bei einem Jailbroken Device oder Forensik-Zugriff können alle gecachten Buchcover extrahiert werden.

**Empfehlung:**
- `NSFileProtectionComplete` für Cache-Dateien aktivieren
- Oder verschlüsselten Cache-Container verwenden

#### ⚠️ Problem 5: Sensible Daten im Memory-Cache
**Schweregrad: Niedrig**
**Datei:** `ImageCacheManager.swift:66, ReadwiseDataManager.swift:11`

```swift
private let memoryCache = NSCache<NSString, AnyObject>()
@Published public var fullyLoadedBooks: [BookPreview] = []
```

Bücher und Highlights werden im Speicher gehalten. Bei einem Memory-Dump könnten diese Daten extrahiert werden.

---

### 4. Logging & Debug-Informationen

#### ⚠️ Problem 6: Debug-Ausgaben in Production-Code
**Schweregrad: Mittel**
**Dateien:** Mehrere

Zahlreiche `print()`-Aufrufe geben sensible Informationen in der Konsole aus:

**ReadwiseDataManager.swift:57-62:**
```swift
print("🚀 Starte Ladevorgang für Bücher...")
print("❌ Fehler beim Laden der Bücher: \(error)")
```

**ImageCacheManager.swift:96, 210, 216:**
```swift
print("⚠️ Fehler beim Erstellen des Cache-Verzeichnisses: \(error)")
print("⚠️ Fehler beim Konvertieren des NSImage in PNG-Daten")
```

**NetworkMonitor.swift:141:**
```swift
print("🌐 Verarbeite \(pendingRequests.count) ausstehende Netzwerkanfragen")
```

**Risiko:**
- Debug-Logs können auf Jailbroken Devices oder via Xcode abgefangen werden
- Fehlermeldungen können Stack-Traces oder interne Strukturen offenlegen

**Empfehlung:**
```swift
#if DEBUG
print("Debug-Nachricht")
#endif
// Oder: os_log mit geeignetem Log-Level verwenden
```

---

### 5. Input-Validierung

#### ⚠️ Problem 7: Unzureichende API-Key-Validierung
**Schweregrad: Niedrig**
**Datei:** `APIKeyView.swift:279-290`

Der API-Key wird nur auf Leere geprüft, aber nicht auf Format oder Länge:
```swift
func validateKey() {
    self.isValidating = true
    // Key wird gespeichert bevor Validierung abgeschlossen ist
    do {
        try ReadwiseAPIService.shared.saveAPIKey(apiKey)
    } catch {
        // ...
    }
```

**Risiko:** Ein ungültiger Key wird in die Keychain geschrieben, bevor die Server-Validierung abgeschlossen ist.

**Empfehlung:**
- Lokale Format-Validierung vor dem Speichern
- Key erst nach erfolgreicher Server-Validierung speichern

---

### 6. URL-Handling

#### ✅ Positiv: Sichere URL-Konstruktion
Die App verwendet `URLComponents` für Query-Parameter (`ReadwiseAPIService.swift:175-181`):
```swift
guard var components = URLComponents(string: baseURL + highlightsEndpoint) else {
    completion(.failure(.invalidURL))
    return
}
components.queryItems = [URLQueryItem(name: "book_id", value: "\(readwiseId)")]
```

Dies verhindert URL-Injection-Angriffe.

---

### 7. Reflection & Dynamic Code

#### ⚠️ Problem 8: Unsichere Nutzung von Runtime-Features
**Schweregrad: Niedrig**
**Datei:** `NetworkMonitor.swift:176-186`

```swift
if let imageManager = NSClassFromString("ImageCacheManager") as? NSObject.Type,
   let sharedInstance = imageManager.value(forKey: "shared") as? NSObject {
    let selector = NSSelectorFromString("getCachedImage:")
    if sharedInstance.responds(to: selector) {
        let result = sharedInstance.perform(selector, with: url)
```

Die Verwendung von `NSClassFromString`, `value(forKey:)` und `perform(selector:)` ist problematisch:
- Code ist fragil und kann bei Refactoring brechen
- Umgeht Swift's Typsicherheit
- Potentiell anfällig für Runtime-Manipulation

**Empfehlung:** Direkte Referenz auf `ImageCacheManager.shared` verwenden.

---

### 8. App Transport Security (ATS)

#### ℹ️ Zu prüfen: Info.plist Konfiguration

Die Analyse der Info.plist wurde nicht abgeschlossen. Folgende Punkte sollten geprüft werden:
- `NSAllowsArbitraryLoads` sollte `false` sein
- Keine unsicheren Domain-Ausnahmen

---

### 9. CoreData (nicht aktiv genutzt)

#### ✅ Positiv: Keine persistente Datenspeicherung
Die App hat CoreData-Setup (`Persistence.swift`), nutzt es aber nicht aktiv. Alle Buch- und Highlight-Daten werden nur im Speicher gehalten:
```swift
@Published public var fullyLoadedBooks: [BookPreview] = []
```

Dies ist aus Datenschutzsicht positiv, da keine sensiblen Daten persistent gespeichert werden.

---

## Empfohlene Maßnahmen (nach Priorität)

### Hoch
1. **Certificate Pinning implementieren** für readwise.io API
2. **Keychain Access Controls hinzufügen** mit `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`
3. **Debug-Logs entfernen** oder mit `#if DEBUG` konditionieren

### Mittel
4. **File Protection aktivieren** für Image-Cache
5. **API-Key Validierung verbessern** - erst nach Server-Validierung speichern
6. **Runtime-Reflection ersetzen** durch direkte Referenzen

### Niedrig
7. **Input-Sanitization** für API-Key (Format-Prüfung)
8. **Memory-Protection** - sensible Daten nach Gebrauch nullen

---

## Positiv bewertete Sicherheitsaspekte

1. ✅ API-Key wird im Keychain gespeichert (nicht UserDefaults)
2. ✅ Ausschließlich HTTPS-Kommunikation
3. ✅ Sichere URL-Konstruktion mit URLComponents
4. ✅ Keine lokale Datenbank mit sensiblen Daten
5. ✅ Proper Error-Handling für Authentifizierungsfehler
6. ✅ Keine hartcodierten Credentials im Code
7. ✅ Kein Logging des API-Keys selbst
8. ✅ Automatische Cache-Bereinigung nach 30 Tagen

---

## Fazit

Die ReadwiseHighApp folgt grundlegenden iOS-Sicherheitspraktiken, insbesondere bei der Credential-Speicherung und HTTPS-Kommunikation. Die identifizierten Probleme sind hauptsächlich **mittlerer Schweregrad** und betreffen:

- Fehlendes Certificate Pinning
- Unverschlüsselter Disk-Cache
- Debug-Logging in Production

Für eine Produktions-App, die mit Benutzerdaten arbeitet, sollten die Maßnahmen mit **hoher Priorität** zeitnah umgesetzt werden.

---

*Diese Analyse wurde automatisch erstellt und sollte durch manuelle Prüfung ergänzt werden.*
