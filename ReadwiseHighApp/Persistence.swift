import CoreData

// Persistence Controller für CoreData
public class PersistenceController {
    public static let shared = PersistenceController()
    
    public let container: NSPersistentContainer
    
    public init() {
        container = NSPersistentContainer(name: "ReadwiseHighApp")
        container.loadPersistentStores { _, error in
            if let error = error {
                // In einer echten App sollte hier ein robusteres Error-Handling erfolgen
                fatalError("Fehler beim Laden der Core Data Stores: \(error)")
            }
        }
    }
} 