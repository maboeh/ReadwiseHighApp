# Fabric.so Integration Plan

## Fabric.so API Analyse

### Was ist Fabric.so?

[Fabric.so](https://fabric.so/) ist ein AI-gesteuertes Wissensmanagement-Tool, das als "Second Brain" fungiert. Es bietet:

- **AI-gestützte Suche**: Versteht Bedeutung, nicht nur Keywords
- **Automatische Organisation**: "Death to organizing" - AI übernimmt die Strukturierung
- **Universal Capture**: Voice Notes, Text, Bilder, Videos, PDFs, Links
- **Smart Linking**: Automatische Verknüpfung verwandter Inhalte

### Verfügbare Integrationsoptionen

| Option | Beschreibung | Komplexität | Empfehlung |
|--------|--------------|-------------|------------|
| **Native Readwise-Integration** | Fabric hat bereits eine Readwise-Verbindung | Keine | ✅ Einfachste Lösung |
| **Zapier-Integration** | Über Zapier mit 7,000+ Apps verbinden | Mittel | ✅ Für Custom-Flows |
| **Direkte API** | Keine öffentliche REST API dokumentiert | - | ❌ Nicht verfügbar |

### Native Readwise → Fabric Integration

Laut [Fabric.so/connections/readwise](https://fabric.so/connections/readwise):

> "When you connect your Readwise account to Fabric, it will automatically sync any content from your Readwise account, indexing and understanding any key themes. Every time you save anything to Readwise, Fabric will automatically save and index it for you."

**Das bedeutet:** Die Highlights aus Readwise werden bereits automatisch nach Fabric synchronisiert, wenn der Benutzer die Integration aktiviert hat.

### Zapier-Integration

Laut [Zapier Fabric Integrations](https://zapier.com/apps/fabric/integrations):

**Verfügbare Triggers:**
- `New Item Saved` - Triggert wenn ein neues Item gespeichert wird

**Verfügbare Actions:**
- `Create Note` - Erstellt eine Notiz in Fabric
- `Save Bookmark` - Speichert ein Lesezeichen
- `Upload File` - Lädt eine Datei hoch

---

## Implementierungsplan

### Option A: Native Integration nutzen (Empfohlen)

Da die Daten bereits in Readwise vorhanden sind und Fabric eine native Readwise-Integration hat, ist keine Code-Änderung in der App nötig.

**Benutzer-Setup:**
1. In Fabric.so einloggen
2. Zu Settings → Connections navigieren
3. Readwise verbinden (OAuth)
4. Automatische Synchronisation aktivieren

**Vorteile:**
- Keine Entwicklung erforderlich
- Offiziell unterstützt
- Bidirektionale Sync möglich

---

### Option B: Zapier-Integration (Für Custom-Workflows)

Falls Custom-Funktionalität benötigt wird (z.B. nur bestimmte Highlights pushen):

```
┌─────────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  ReadwiseHighApp    │────▶│     Zapier      │────▶│    Fabric.so    │
│  (Webhook Trigger)  │     │  (Automation)   │     │  (Create Note)  │
└─────────────────────┘     └─────────────────┘     └─────────────────┘
```

#### Implementierungsschritte

**Phase 1: Webhook-Service in der App**

```swift
// Neue Datei: Services/WebhookService.swift

import Foundation

/// Service zum Senden von Highlights an externe Webhooks (z.B. Zapier)
class WebhookService {
    static let shared = WebhookService()

    private let webhookURLKey = "fabricWebhookURL"

    /// Sendet ein Highlight an den konfigurierten Webhook
    func sendHighlight(_ highlight: HighlightItem, book: BookPreview, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let webhookURL = getWebhookURL() else {
            completion(.failure(WebhookError.noWebhookConfigured))
            return
        }

        let payload = HighlightPayload(
            text: highlight.text,
            bookTitle: book.title,
            author: book.author,
            page: highlight.page,
            highlightedAt: highlight.date,
            source: "ReadwiseHighApp"
        )

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(payload)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(WebhookError.requestFailed))
                return
            }

            completion(.success(()))
        }.resume()
    }

    // MARK: - Configuration

    func setWebhookURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: webhookURLKey)
    }

    func getWebhookURL() -> URL? {
        guard let urlString = UserDefaults.standard.string(forKey: webhookURLKey) else {
            return nil
        }
        return URL(string: urlString)
    }
}

// MARK: - Models

struct HighlightPayload: Codable {
    let text: String
    let bookTitle: String
    let author: String
    let page: Int
    let highlightedAt: Date
    let source: String
}

enum WebhookError: Error {
    case noWebhookConfigured
    case requestFailed
}
```

**Phase 2: UI für Webhook-Konfiguration**

```swift
// In Settings-View hinzufügen

struct FabricIntegrationView: View {
    @State private var webhookURL: String = ""
    @State private var isTesting = false
    @State private var testResult: String?

    var body: some View {
        Form {
            Section(header: Text("Zapier Webhook URL")) {
                TextField("https://hooks.zapier.com/...", text: $webhookURL)
                    .autocapitalization(.none)

                Button("Webhook speichern") {
                    if let url = URL(string: webhookURL) {
                        WebhookService.shared.setWebhookURL(url)
                    }
                }

                Button("Test senden") {
                    testWebhook()
                }
                .disabled(webhookURL.isEmpty || isTesting)
            }

            if let result = testResult {
                Section(header: Text("Test-Ergebnis")) {
                    Text(result)
                }
            }

            Section(header: Text("Anleitung")) {
                Text("1. Erstelle einen Zap in Zapier")
                Text("2. Wähle 'Webhooks by Zapier' als Trigger")
                Text("3. Wähle 'Fabric' als Action → 'Create Note'")
                Text("4. Kopiere die Webhook-URL hierher")
            }
        }
    }

    private func testWebhook() {
        // Test-Implementation
    }
}
```

**Phase 3: Share-Button erweitern**

```swift
// In BookDetailView.swift - Share-Funktionalität erweitern

Button("Nach Fabric senden") {
    sendToFabric(highlight: selectedHighlight, book: book)
}

private func sendToFabric(highlight: HighlightItem, book: BookPreview) {
    WebhookService.shared.sendHighlight(highlight, book: book) { result in
        switch result {
        case .success:
            // Erfolgs-Feedback anzeigen
            showSuccessMessage = true
        case .failure(let error):
            // Fehler-Handling
            errorMessage = error.localizedDescription
        }
    }
}
```

---

### Option C: Direkte Fabric API (Zukunft)

Falls Fabric.so in Zukunft eine öffentliche REST API veröffentlicht:

```swift
// Placeholder für zukünftige direkte API-Integration
class FabricAPIService {
    private let baseURL = "https://api.fabric.so/v1/"
    private var apiKey: String?

    func createNote(content: String, metadata: [String: Any]) async throws {
        // Implementation wenn API verfügbar
    }
}
```

---

## Empfohlene Implementierungsreihenfolge

### Sofort umsetzbar (Keine Code-Änderung)

| Schritt | Aktion | Zuständig |
|---------|--------|-----------|
| 1 | Benutzer informieren über native Readwise→Fabric Integration | Dokumentation |
| 2 | In-App Hinweis auf Integration in Settings | UI-Update |

### Phase 1: Zapier-Integration (1-2 Tage Entwicklung)

| Schritt | Beschreibung | Datei |
|---------|--------------|-------|
| 1 | WebhookService erstellen | `Services/WebhookService.swift` |
| 2 | HighlightPayload Model | `Models/WebhookModels.swift` |
| 3 | Settings-View für Webhook-URL | `Views/FabricIntegrationView.swift` |
| 4 | Share-Button in BookDetailView | `Views/BookDetailView.swift` |
| 5 | Keychain-Speicherung für Webhook-URL | `Utils/KeychainHelper.swift` |

### Phase 2: Batch-Export (Optional)

| Feature | Beschreibung |
|---------|--------------|
| Alle Highlights exportieren | Button um alle Highlights eines Buchs zu senden |
| Automatischer Sync | Background-Sync bei neuen Highlights |
| Offline-Queue | Highlights speichern und senden wenn online |

---

## Zapier-Zap Konfiguration

### Trigger: Webhooks by Zapier
- **Event**: Catch Hook
- **URL**: Wird von Zapier generiert

### Action: Fabric → Create Note

**Mapping:**

| Zapier Field | Payload Field |
|--------------|---------------|
| Note Title | `{{bookTitle}} - Highlight` |
| Note Content | `{{text}}` |
| Tags | `readwise, {{author}}` |

### Beispiel Payload

```json
{
  "text": "Der wichtigste Aspekt des Lernens ist die Wiederholung.",
  "bookTitle": "Atomic Habits",
  "author": "James Clear",
  "page": 42,
  "highlightedAt": "2026-01-25T10:30:00Z",
  "source": "ReadwiseHighApp"
}
```

---

## Sicherheitsüberlegungen

| Aspekt | Empfehlung |
|--------|------------|
| Webhook-URL | In Keychain speichern (nicht UserDefaults) |
| Datenübertragung | HTTPS erzwingen |
| Rate Limiting | Max 10 Requests/Minute implementieren |
| Fehlerbehandlung | Retry-Logik mit Exponential Backoff |

---

## Fazit

**Für die meisten Benutzer ist Option A (Native Integration) ausreichend**, da Fabric bereits eine Readwise-Integration hat.

**Option B (Zapier)** ist sinnvoll für:
- Benutzer die nur bestimmte Highlights exportieren wollen
- Custom-Workflows (z.B. mit Tagging, Filterung)
- Echtzeit-Benachrichtigungen

**Geschätzter Entwicklungsaufwand:**
- Option A: 0 Stunden (nur Dokumentation)
- Option B: 8-12 Stunden (vollständige Zapier-Integration)
- Option C: Abhängig von zukünftiger Fabric API

---

## Quellen

- [Fabric.so](https://fabric.so/)
- [Fabric Readwise Integration](https://fabric.so/connections/readwise)
- [Fabric Zapier Integration](https://zapier.com/apps/fabric/integrations)
- [Fabric.so Review](https://aiblogfirst.com/fabric-so-review/)
