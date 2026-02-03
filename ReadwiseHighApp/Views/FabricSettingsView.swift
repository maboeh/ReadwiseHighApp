import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Fabric Settings View

/// Einstellungen für die Fabric.so Integration
struct FabricSettingsView: View {
    @State private var exportPath: String = ""
    @State private var showFolderPicker = false
    @State private var showSuccessMessage = false
    @State private var errorMessage: String?

    var body: some View {
        #if os(iOS)
        iOSContent
        #else
        macOSContent
        #endif
    }

    // MARK: - iOS Content

    #if os(iOS)
    private var iOSContent: some View {
        Form {
            exportSection
            infoSection
            setupGuideSection
        }
        .navigationTitle("Fabric Integration")
        .onAppear {
            loadCurrentPath()
        }
        .sheet(isPresented: $showFolderPicker) {
            DocumentPickerView { url in
                handleFolderSelection(url)
            }
        }
        .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    #endif

    // MARK: - macOS Content

    #if os(macOS)
    private var macOSContent: some View {
        Form {
            exportSection
            infoSection
            setupGuideSection
        }
        .padding()
        .frame(minWidth: 500)
        .onAppear {
            loadCurrentPath()
        }
        .alert("Fehler", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    #endif

    // MARK: - Sections

    private var exportSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Export-Verzeichnis")
                    .font(.headline)

                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.accentColor)

                    if exportPath.isEmpty {
                        Text("Nicht konfiguriert")
                            .foregroundColor(.secondary)
                    } else {
                        Text(exportPath)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(2)
                            .truncationMode(.middle)
                    }

                    Spacer()
                }
                .padding(12)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                HStack(spacing: 12) {
                    Button(action: selectFolder) {
                        Label("Ordner wählen", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)

                    if !exportPath.isEmpty {
                        Button(action: resetFolder) {
                            Label("Zurücksetzen", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Export-Einstellungen")
        } footer: {
            Text("Wähle einen Ordner, der mit Fabric synchronisiert wird (z.B. iCloud Drive, Dropbox, Google Drive).")
        }
    }

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                InfoRow(icon: "checkmark.circle.fill",
                       color: .green,
                       title: "Ein Dokument pro Buch",
                       description: "Alle Highlights eines Buches werden in einer Markdown-Datei gespeichert.")

                InfoRow(icon: "arrow.triangle.2.circlepath",
                       color: .blue,
                       title: "Automatische Updates",
                       description: "Bei erneutem Export wird die Datei aktualisiert – keine Duplikate.")

                InfoRow(icon: "icloud.fill",
                       color: .cyan,
                       title: "Cloud-Sync",
                       description: "Fabric synchronisiert den Ordner automatisch.")
            }
        } header: {
            Text("Funktionsweise")
        }
    }

    private var setupGuideSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                SetupStep(number: 1,
                         title: "Ordner erstellen",
                         description: "Erstelle einen Ordner 'ReadwiseHighlights' in deinem Cloud-Speicher (iCloud, Dropbox, etc.).")

                SetupStep(number: 2,
                         title: "Mit Fabric verbinden",
                         description: "Verbinde diesen Cloud-Speicher in Fabric unter Settings → Connections.")

                SetupStep(number: 3,
                         title: "Ordner hier auswählen",
                         description: "Wähle denselben Ordner oben als Export-Verzeichnis aus.")

                SetupStep(number: 4,
                         title: "Highlights exportieren",
                         description: "Nutze den 'Nach Fabric exportieren' Button in der Buch-Detailansicht.")
            }
        } header: {
            Text("Einrichtung")
        }
    }

    // MARK: - Actions

    private func loadCurrentPath() {
        exportPath = FabricExportService.shared.exportPath ?? ""
    }

    private func selectFolder() {
        #if os(iOS)
        showFolderPicker = true
        #else
        selectFolderMacOS()
        #endif
    }

    #if os(macOS)
    private func selectFolderMacOS() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Auswählen"
        panel.message = "Wähle den Ordner für Fabric-Exporte"

        if panel.runModal() == .OK, let url = panel.url {
            handleFolderSelection(url)
        }
    }
    #endif

    private func handleFolderSelection(_ url: URL) {
        do {
            try FabricExportService.shared.setExportDirectory(url)
            exportPath = url.path
            showSuccessMessage = true
        } catch {
            errorMessage = "Ordner konnte nicht gespeichert werden: \(error.localizedDescription)"
        }
    }

    private func resetFolder() {
        FabricExportService.shared.resetExportDirectory()
        loadCurrentPath()
    }
}

// MARK: - Helper Views

private struct InfoRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SetupStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 24, height: 24)

                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Document Picker (iOS)

#if os(iOS)
struct DocumentPickerView: UIViewControllerRepresentable {
    let onSelect: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: (URL) -> Void

        init(onSelect: @escaping (URL) -> Void) {
            self.onSelect = onSelect
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Security-scoped access starten
            guard url.startAccessingSecurityScopedResource() else { return }

            onSelect(url)

            // Hinweis: stopAccessingSecurityScopedResource wird im Service aufgerufen
        }
    }
}
#endif

// MARK: - Preview

#if DEBUG
struct FabricSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            FabricSettingsView()
        }
    }
}
#endif
