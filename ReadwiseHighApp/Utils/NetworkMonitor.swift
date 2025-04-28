import Foundation
import Network
import SwiftUI
import Combine

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Ein Singleton zur Überwachung und Verwaltung des Netzwerkstatus
public class NetworkMonitor: ObservableObject {
    // Singleton-Instanz
    public static let shared = NetworkMonitor()

    // Der aktuelle Verbindungsstatus
    @Published public private(set) var isConnected = true

    // Details zur Verbindung
    @Published public private(set) var connectionType: ConnectionType = .unknown

    // Der Monitor des Network-Frameworks
    private let monitor = NWPathMonitor()

    // Die Dispatch-Queue für den Monitor
    private let queue = DispatchQueue(label: "NetworkMonitor")

    // Ein Timer für verzögerte Benachrichtigungen über Wiederherstellung
    private var delayedRestoreTimer: Timer?

    // Subject für die Publisher-Schnittstelle
    private let connectionRestoredSubject = PassthroughSubject<Void, Never>()

    // Öffentlicher Publisher für Verbindungswiederherstellungen
    public var connectionRestoredPublisher: AnyPublisher<Void, Never> {
        connectionRestoredSubject.eraseToAnyPublisher()
    }

    // Liste der ausstehenden Netzwerkanfragen bei Verbindungsunterbrechung
    private var pendingRequests: [() -> Void] = []

    // Private Initialisierung für Singleton-Muster
    private init() {
        startMonitoring()

        // Registriere Notification für hintergründige Verbindungswiederherstellung
        #if os(iOS)
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                              object: nil,
                                              queue: .main) { [weak self] _ in
            self?.checkConnectionOnForeground()
        }
        #elseif os(macOS)
        NotificationCenter.default.addObserver(forName: NSApplication.willBecomeActiveNotification,
                                              object: nil,
                                              queue: .main) { [weak self] _ in
            self?.checkConnectionOnForeground()
        }
        #endif
    }

    /// Startet die Netzwerküberwachung
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            // Der tatsächliche Status basierend auf dem Pfad
            let isConnected = path.status == .satisfied

            // Bestimme den Verbindungstyp
            let connectionType = self.determineConnectionType(from: path)

            // Aktualisiere die Werte auf der Hauptthread-Queue
            DispatchQueue.main.async {
                // Prüfe, ob sich der Verbindungsstatus geändert hat
                let wasConnected = self.isConnected

                // Aktualisiere die Statusvariablen
                self.isConnected = isConnected
                self.connectionType = connectionType

                // Wenn die Verbindung wiederhergestellt wurde, warte kurz, um die Stabilität zu bestätigen
                if !wasConnected && isConnected {
                    self.handleConnectionRestored()
                }
            }
        }

        // Starte den Monitor auf einer Hintergrund-Queue
        monitor.start(queue: queue)
    }

    /// Prüft bei Rückkehr in den Vordergrund die Verbindung erneut
    private func checkConnectionOnForeground() {
        // Starten Sie den Monitoring-Prozess neu, um den neuesten Status zu erhalten
        monitor.cancel()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.startMonitoring()
        }
    }

    /// Bestimmt den Typ der Netzwerkverbindung
    private func determineConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }

    /// Behandelt die Wiederherstellung der Verbindung
    private func handleConnectionRestored() {
        // Timer abbrechen, falls einer läuft
        delayedRestoreTimer?.invalidate()

        // Neuen Timer für verzögerte Benachrichtigung starten (500ms)
        // Dies vermeidet mehrfache schnelle Benachrichtigungen bei kurzen Verbindungsproblemen
        delayedRestoreTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Benachrichtige die Abonnenten über den Publisher
            self.connectionRestoredSubject.send()

            // Benachrichtige über das Notification Center für ältere Code-Teile
            NotificationCenter.default.post(name: Notification.Name("NetworkConnectionRestored"), object: nil)

            // Verarbeite ausstehende Anfragen
            self.processPendingRequests()
        }
    }

    /// Verarbeitet ausstehende Anfragen, die während eines Offline-Zustands in die Warteschlange gestellt wurden
    private func processPendingRequests() {
        guard !pendingRequests.isEmpty else { return }

        print("🌐 Verarbeite \(pendingRequests.count) ausstehende Netzwerkanfragen")

        // Kopiere die Anfragen und leere die Liste
        let requests = pendingRequests
        pendingRequests = []

        // Führe jede gespeicherte Anfrage aus
        for request in requests {
            request()
        }
    }

    /// Fügt eine ausstehende Anfrage zur Warteschlange hinzu, wenn offline
    /// - Parameter requestBlock: Der auszuführende Code, wenn wieder online
    public func enqueueRequestIfOffline(_ requestBlock: @escaping () -> Void) -> Bool {
        if !isConnected {
            pendingRequests.append(requestBlock)
            return true
        }
        return false
    }

    /// Prüft, ob eine Ressource im Offline-Modus nicht verfügbar ist
    /// - Parameters:
    ///   - url: Die URL der Ressource
    ///   - cacheCheckBlock: Eine Closure, die prüft, ob die Ressource im Cache ist
    /// - Returns: True, wenn offline und die Ressource nicht im Cache ist
    public func isOfflineAndNotCached(for url: URL, cacheCheck: (() -> Bool)? = nil) -> Bool {
        if !isConnected {
            // Wenn eine Cache-Prüfung bereitgestellt wurde, verwende diese
            if let cacheCheck = cacheCheck {
                return !cacheCheck()
            }

            // Fallback zum ImageCacheManager (wenn verfügbar)
            if let imageManager = NSClassFromString("ImageCacheManager") as? NSObject.Type,
               let sharedInstance = imageManager.value(forKey: "shared") as? NSObject {
                let selector = NSSelectorFromString("getCachedImage:")
                if sharedInstance.responds(to: selector) {
                    let result = sharedInstance.perform(selector, with: url)
                    return result?.takeUnretainedValue() == nil
                }
            }

            // Wenn keine speziellen Prüfungen möglich sind, gehen wir davon aus, 
            // dass im Offline-Modus kein Zugriff möglich ist
            return true
        }
        return false
    }

    /// Stellt fest, ob ein bestimmter Fehler ein Netzwerkfehler ist
    /// - Parameter error: Der zu prüfende Fehler
    /// - Returns: True, wenn es sich um einen Netzwerkfehler handelt
    public func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotConnectToHost,
                 .cannotFindHost,
                 .timedOut:
                return true
            default:
                break
            }
        }
        return false
    }
}

// Erweiterung zum Anzeigen eines Netzwerkstatus-Banners
extension View {
    /// Fügt einen Netzwerkstatus-Banner zur View hinzu
    public func withNetworkStatusBanner() -> some View {
        self.modifier(NetworkStatusBannerModifier())
    }
}

/// Ein ViewModifier für das Netzwerkstatus-Banner
struct NetworkStatusBannerModifier: ViewModifier {
    // Verwende den shared singleton direkt statt @EnvironmentObject
    // Dies vermeidet den Fehler "No ObservableObject of type NetworkMonitor found"
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var showBanner = false

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if !networkMonitor.isConnected {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                        Text("Keine Internetverbindung")
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    Spacer()
                }
                .zIndex(1)
                .animation(.easeInOut, value: networkMonitor.isConnected)
            }
        }
        .onReceive(networkMonitor.$isConnected) { isConnected in
            if isConnected {
                // Kurz warten, dann Banner ausblenden
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showBanner = false
                }
            } else {
                showBanner = true
            }
        }
    }
}

/// Enumeration für den Verbindungstyp
public enum ConnectionType: String {
    case wifi = "WLAN"
    case cellular = "Mobilfunk"
    case ethernet = "Ethernet"
    case unknown = "Unbekannt"
}

// Erweiterung für den ImageCacheManager zur Prüfung des Cache-Status
extension NetworkMonitor {
    /// Prüft, ob das Gerät im Offline-Modus ist und ob gecachte Bilder verfügbar sind
    /// - Parameter url: Die URL des zu überprüfenden Bildes
    /// - Returns: True, wenn wir im Offline-Modus sind und das Bild nicht im Cache ist
    public func isOfflineAndNotCached(for url: URL) -> Bool {
        if !isConnected {
            // Direkt auf ImageCacheManager zugreifen, da er in dieser App verfügbar ist
            if let imageManager = NSClassFromString("ImageCacheManager") as? NSObject.Type,
               let sharedInstance = imageManager.value(forKey: "shared") as? NSObject {
                let selector = NSSelectorFromString("getCachedImage:")
                if sharedInstance.responds(to: selector) {
                    let result = sharedInstance.perform(selector, with: url)
                    return result?.takeUnretainedValue() == nil
                }
            }
            return true
        }
        return false
    }
}
