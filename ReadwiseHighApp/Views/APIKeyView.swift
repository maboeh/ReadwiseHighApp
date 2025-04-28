import SwiftUI
import Network
import Foundation


struct APIKeyView: View {
    @State private var apiKey: String = ""
    @State private var isValidating = false
    @State private var validationMessage: String?
    @State private var isValid = false
    @Binding var isPresented: Bool
    @State private var isCheckingNetwork = false
    @State private var networkStatus: String?
    @EnvironmentObject var dataManager: ReadwiseDataManager

    var body: some View {
        #if os(iOS)
        navigationView
        #else
        VStack {
            // Titel mit Schließen-Button für macOS
            HStack {
                Text("Readwise API")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Schließen") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            // Inhalt
            formContent
                .padding(.horizontal, 10)
        }
        .frame(width: 650, height: 700)
        #endif
    }
    
    // NavigationView Wrapper für iOS
    private var navigationView: some View {
        NavigationView {
            formContent
                .navigationTitle("Readwise API")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Schließen") {
                            isPresented = false
                        }
                        #if os(macOS)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        #endif
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 500)
        #endif
    }
    
    // Gemeinsamer Formular-Inhalt
    private var formContent: some View {
        #if os(macOS)
        return Form {
            VStack(alignment: .leading, spacing: 20) {
                // API-Schlüssel Eingabe
                VStack(alignment: .leading, spacing: 8) {
                    Text("API-Schlüssel eingeben")
                        .font(.headline)
                    
                    TextField("API-Schlüssel", text: $apiKey)
                        .disableAutocorrection(true)
                        .frame(height: 36)
                        .textFieldStyle(.roundedBorder)
                        .padding(.bottom, 4)

                    Button(action: validateKey) {
                        HStack {
                            Text(isValidating ? "Überprüfe..." : "API-Schlüssel speichern")
                                .fontWeight(.medium)

                            if isValidating {
                                Spacer()
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .disabled(apiKey.isEmpty || isValidating)
                    .buttonStyle(.borderedProminent)

                    Button("API-Schlüssel löschen", role: .destructive) {
                        deleteKey()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(apiKey.isEmpty)
                }
                .padding(.vertical, 8)
                
                // Status
                if let message = validationMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Status")
                            .font(.headline)
                        Text(message)
                            .foregroundColor(isValid ? .green : .red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isValid ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isValid ? Color.green.opacity(0.2) : Color.red.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .padding(.vertical, 8)
                }

                // Netzwerkverbindung
                VStack(alignment: .leading, spacing: 8) {
                    Text("Netzwerkverbindung")
                        .font(.headline)
                    
                    if isCheckingNetwork {
                        HStack {
                            Text("Prüfe Netzwerk...")
                            Spacer()
                            ProgressView()
                        }
                        .padding(12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    } else if let status = networkStatus {
                        Text(status)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }

                    Button("Netzwerk erneut prüfen") {
                        checkNetworkConnection()
                    }
                    .disabled(isCheckingNetwork)
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
                    .padding(.top, 4)
                }
                .padding(.vertical, 8)

                // Readwise Access Token
                VStack(alignment: .leading, spacing: 8) {
                    Text("Readwise Access Token")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Den API-Schlüssel findest du unter:")
                            .font(.subheadline)
                        Link("readwise.io/access_token", destination: URL(string: "https://readwise.io/access_token")!)
                            .font(.subheadline)
                            .padding(.top, 2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                .padding(.vertical, 8)
            }
            .padding(16)
        }
        .onAppear {
            let savedKey = getApiKey()
            if !savedKey.isEmpty {
                apiKey = savedKey
                isValid = true
            }

            checkNetworkConnection()
        }
        #else
        return Form {
            Section(header: Text("API-Schlüssel eingeben")) {
                TextField("API-Schlüssel", text: $apiKey)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .frame(minHeight: 30)

                Button(action: validateKey) {
                    HStack {
                        Text(isValidating ? "Überprüfe..." : "API-Schlüssel speichern")

                        if isValidating {
                            Spacer()
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        }
                    }
                }
                .disabled(apiKey.isEmpty || isValidating)

                Button("API-Schlüssel löschen", role: .destructive) {
                    deleteKey()
                }
                .disabled(apiKey.isEmpty)
            }

            if let message = validationMessage {
                Section(header: Text("Status")) {
                    Text(message)
                        .foregroundColor(isValid ? .green : .red)
                }
            }

            Section(header: Text("Netzwerkverbindung")) {
                if isCheckingNetwork {
                    HStack {
                        Text("Prüfe Netzwerk...")
                        Spacer()
                        ProgressView()
                    }
                } else if let status = networkStatus {
                    Text(status)
                        .font(.footnote)
                }

                Button("Netzwerk erneut prüfen") {
                    checkNetworkConnection()
                }
                .disabled(isCheckingNetwork)
            }

            Section(header: Text("Readwise Access Token")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Den API-Schlüssel findest du unter:")
                        .font(.footnote)
                    Link("readwise.io/access_token", destination: URL(string: "https://readwise.io/access_token")!)
                        .font(.footnote)
                }
            }
        }
        .onAppear {
            let savedKey = getApiKey()
            if !savedKey.isEmpty {
                apiKey = savedKey
                isValid = true
            }

            checkNetworkConnection()
        }
        #endif
    }

    private func validateKey() {
        self.isValidating = true
        self.validationMessage = nil

        // Key speichern in Keychain
        do {
            try ReadwiseAPIService.shared.saveAPIKey(apiKey)
        } catch {
            self.isValidating = false
            self.validationMessage = "Fehler beim Speichern des API-Schlüssels: \(error.localizedDescription)"
            return
        }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                monitor.cancel()

                if path.status == .satisfied {
                    continueWithKeyValidation()
                } else {
                    self.isValidating = false
                    self.validationMessage = "Fehler: Keine Netzwerkverbindung. Der Schlüssel wurde trotzdem gespeichert. Du kannst das Fenster schließen."
                    self.networkStatus = "⚠️ Netzwerk nicht verfügbar."
                }
            }
        }

        monitor.start(queue: .global())
    }

    private func continueWithKeyValidation() {
        // Key wurde bereits gespeichert
        validateApiKey { result in
            DispatchQueue.main.async {
                self.isValidating = false

                switch result {
                case .success:
                    self.validationMessage = "API-Schlüssel ist gültig!"
                    self.isValid = true

                    // Nach kurzer Verzögerung: Ladezustand zurücksetzen, API-Key-Status aktualisieren, Bücher laden und Maske schließen
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        // Ladezustand zurücksetzen
                        self.dataManager.loadingState = .idle
                        // API-Key-View-Status aktualisieren
                        self.dataManager.updateAPIKeyViewState()
                        // Bücher laden
                        self.dataManager.loadBooks()
                        // Maske schließen
                        self.isPresented = false
                    }
                case .failure(let error):
                    let errorMessage: String
                    switch error {
                    case .noKey:
                        errorMessage = "Kein API-Schlüssel gefunden"
                    case .invalidKey:
                        errorMessage = "Der API-Schlüssel ist ungültig"
                    case .networkError(let err):
                        errorMessage = "Netzwerkfehler: \(err)"
                    case .invalidResponse:
                        errorMessage = "Ungültige Antwort vom Server"
                    case .serverError(let code):
                        errorMessage = "Serverfehler mit Code \(code)"
                    case .invalidURL:
                        errorMessage = "Interner Fehler: Ungültige API-URL konfiguriert."
                    case .noData:
                        errorMessage = "Keine Daten vom Server erhalten."
                    }

                    self.validationMessage = "Warnung: Der Schlüssel wurde gespeichert, aber die Prüfung ist fehlgeschlagen. Du kannst das Fenster schließen. Fehler: \(errorMessage)"
                    self.isValid = false
                }
            }
        }
    }

    private func checkNetworkConnection() {
        isCheckingNetwork = true
        networkStatus = "Prüfe Netzwerkverbindung..."

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                self.isCheckingNetwork = false
                monitor.cancel()

                if path.status == .satisfied {
                    self.testReadwiseConnection()
                } else {
                    self.networkStatus = "⚠️ Keine Internetverbindung verfügbar. Bitte überprüfe deine WLAN- oder Ethernet-Einstellungen."
                }
            }
        }

        monitor.start(queue: .global())
    }

    func testReadwiseConnection() {
        guard let url = URL(string: "https://readwise.io/api/health") else {
            networkStatus = "Interner Fehler: Ungültige URL"
            return
        }

        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    if error.domain == NSURLErrorDomain {
                        switch error.code {
                        case NSURLErrorCannotFindHost:
                            self.networkStatus = "⚠️ DNS-Fehler: readwise.io konnte nicht gefunden werden."
                        case NSURLErrorTimedOut:
                            self.networkStatus = "⚠️ Zeitüberschreitung: Die Verbindung zu readwise.io hat zu lange gedauert."
                        case NSURLErrorNetworkConnectionLost:
                            self.networkStatus = "⚠️ Verbindung verloren: Die Verbindung zu readwise.io wurde unterbrochen."
                        default:
                            self.networkStatus = "⚠️ Netzwerkfehler (\(error.code)): \(error.localizedDescription)"
                        }
                    } else {
                        self.networkStatus = "⚠️ Fehler: \(error.localizedDescription)"
                    }
                } else if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        self.networkStatus = "✅ Verbindung zu readwise.io erfolgreich hergestellt."
                    } else {
                        self.networkStatus = "⚠️ Unerwartete Antwort von readwise.io: Status \(httpResponse.statusCode)"
                    }
                } else {
                    self.networkStatus = "✅ Verbindung hergestellt, aber keine HTTP-Antwort erhalten."
                }
            }
        }

        task.resume()
    }
    
    // MARK: - API-Hilfsfunktionen
    
    private func getApiKey() -> String {
        return ReadwiseAPIService.shared.getAPIKey()
    }
    
    private func saveApiKey(_ key: String) {
        do {
            try ReadwiseAPIService.shared.saveAPIKey(key)
        } catch {
            debugPrint("Fehler beim Speichern des API-Schlüssels: \(error)")
        }
    }
    
    private func validateApiKey(completion: @escaping (Result<Void, ValidationError>) -> Void) {
        guard !getApiKey().isEmpty else {
            completion(.failure(.noKey))
            return
        }

        let url = URL(string: "https://readwise.io/api/v2/books/")!
        var request = URLRequest(url: url)
        request.addValue("Token \(getApiKey())", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(.networkError(error.localizedDescription)))
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(.invalidResponse))
                return
            }

            switch httpResponse.statusCode {
            case 200...299:
                completion(.success(()))
            case 401:
                completion(.failure(.invalidKey))
            default:
                completion(.failure(.serverError(httpResponse.statusCode)))
            }
        }.resume()
    }

    private func deleteKey() {
        do {
            try ReadwiseAPIService.shared.deleteAPIKey()
            apiKey = ""
            isValid = false
            validationMessage = nil
            networkStatus = nil
            dataManager.updateAPIKeyViewState()
        } catch {
            validationMessage = "Fehler beim Löschen des API-Schlüssels: \(error.localizedDescription)"
        }
    }
}
