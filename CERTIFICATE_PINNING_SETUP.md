# Certificate Pinning Setup

Diese Anleitung beschreibt, wie die Public Key Hashes für das Certificate Pinning konfiguriert werden.

## Warum Certificate Pinning?

Certificate Pinning schützt die App gegen Man-in-the-Middle (MITM) Angriffe, indem sichergestellt wird, dass nur Verbindungen zu Servern mit bekannten Zertifikaten akzeptiert werden.

## Aktuellen Public Key Hash ermitteln

Führe folgenden Befehl im Terminal aus, um den aktuellen Public Key Hash von readwise.io zu erhalten:

```bash
openssl s_client -connect readwise.io:443 2>/dev/null | \
  openssl x509 -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64
```

**Beispiel-Output:**
```
abc123DEF456xyz789...=
```

## Hash in der App konfigurieren

1. Öffne die Datei `ReadwiseHighApp/Services/ReadwiseAPIService.swift`

2. Suche nach der `CertificatePinningDelegate` Klasse und dem `pinnedHosts` Dictionary:

```swift
private let pinnedHosts: [String: Set<String>] = [
    "readwise.io": [
        // Hier den Hash eintragen:
        "DEIN_HASH_HIER",
        // Optional: Backup-Hash (z.B. CA Public Key)
        "BACKUP_HASH_HIER"
    ]
]
```

3. Ersetze `DEIN_HASH_HIER` mit dem ermittelten Hash

## Empfohlene Konfiguration

Es wird empfohlen, mindestens zwei Hashes zu hinterlegen:

1. **Primärer Hash**: Der aktuelle Public Key des Server-Zertifikats
2. **Backup Hash**: Der Public Key der ausstellenden CA (Certificate Authority)

Der Backup-Hash ermöglicht einen reibungslosen Übergang bei Zertifikatserneuerungen.

### CA Public Key Hash ermitteln

```bash
# Vollständige Zertifikatskette abrufen
openssl s_client -connect readwise.io:443 -showcerts 2>/dev/null | \
  awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/{ print }' > chain.pem

# Hash des Intermediate/CA-Zertifikats (zweites Zertifikat in der Kette)
openssl x509 -in chain.pem -pubkey -noout | \
  openssl pkey -pubin -outform der | \
  openssl dgst -sha256 -binary | \
  base64

# Aufräumen
rm chain.pem
```

## Debug vs. Production

Die aktuelle Konfiguration:

| Modus | Pinning Status |
|-------|----------------|
| DEBUG | Deaktiviert (für einfacheres Testing) |
| RELEASE | Aktiviert (Produktionssicherheit) |

Um Pinning auch im Debug-Modus zu testen, ändere in `ReadwiseAPIService.swift`:

```swift
#if DEBUG
private let pinningEnabled = true  // Für Testing aktivieren
#else
private let pinningEnabled = true
#endif
```

## Zertifikatswechsel

Bei einem Zertifikatswechsel durch readwise.io:

1. Ermittle den neuen Hash vor dem Wechsel (wenn möglich)
2. Füge den neuen Hash zum `pinnedHosts` Set hinzu
3. Veröffentliche ein App-Update
4. Nach erfolgreicher Verteilung kann der alte Hash entfernt werden

## Troubleshooting

### Verbindung wird abgelehnt

Falls die App nach dem Hinzufügen eines Hashes keine Verbindung mehr herstellen kann:

1. Prüfe, ob der Hash korrekt ist (keine Leerzeichen, vollständig kopiert)
2. Prüfe, ob das Zertifikat zwischenzeitlich erneuert wurde
3. Führe den openssl-Befehl erneut aus und vergleiche die Hashes

### Hash im Debug-Modus ausgeben

Um den Hash des aktuell verwendeten Zertifikats in der App zu sehen, füge temporär folgenden Code in `extractPublicKeyHash` ein:

```swift
#if DEBUG
print("Server Public Key Hash: \(Data(hash).base64EncodedString())")
#endif
```

## Weiterführende Links

- [OWASP Certificate Pinning](https://owasp.org/www-community/controls/Certificate_and_Public_Key_Pinning)
- [Apple Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
