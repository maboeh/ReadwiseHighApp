# ReadwiseHighApp

Eine SwiftUI-App zum Lesen und Verwalten von Readwise-Highlights.

## Refactoring-Plan

Das Projekt wurde kürzlich umstrukturiert, wobei einige Komponenten aus externen Modulen in ein zentrales Modul namens `ReadwiseCore` verschoben wurden. Folgende Dateien wurden gelöscht:

- `ReadwiseHighApp/Utils/ReadwiseKitBridge.swift`
- `ReadwiseHighApp/Services/ReadwiseAPIService.swift`
- `ReadwiseHighApp/Services/ReadwiseDataManager.swift`
- `ReadwiseHighApp/Services/ReadwiseAPIServiceProtocol.swift`
- `ReadwiseHighApp/Models/ReadwiseModels.swift`
- `ReadwiseHighApp/Models/ReadwiseAPIServiceProtocol.swift`

### Refactoring-Schritte

1. **Import-Anpassungen**
   - Ersetze `import ReadwiseKit` mit `import ReadwiseCore` in allen relevanten Dateien

2. **ImageCacheManager korrigieren**
   - Fehler in der Methode `saveImageToDiskCache` wurden behoben
   - NSBitmapImageRep-Initialisierung korrigiert

3. **API-Service-Implementierung**
   - Erstelle eine neue Implementierung von `ReadwiseAPIService`, die mit `ReadwiseCore` kompatibel ist
   - Implementiere das `ReadwiseAPIServiceProtocol` auf Basis der neuen Struktur

4. **Datenmodell-Anpassungen**
   - Verwende die Typaliase `CoreBookPreview` und `CoreHighlightItem` statt direkter Referenzen

5. **Build-Fixes**
   - Führe `./fix_dependencies.sh` aus, um automatische Korrekturen durchzuführen
   - Überprüfe den Build mit `swift build`

### Bekannte Probleme

- Die `CoreBookPreview`-Referenzen in `ImageCacheManagerBridge.swift` müssen angepasst werden
- Die `ReadwiseDataManager`-Implementierung in `ReadwiseHighApp.swift` sollte auf `ReadwiseCore` umgestellt werden

## Installation

1. Clone das Repository
2. Öffne es mit Xcode 15 oder neuer
3. Führe `./fix_dependencies.sh` aus, um Abhängigkeitsprobleme zu beheben
4. Baue und starte die App

## Lizenz

Dieses Projekt ist urheberrechtlich geschützt.

## Hinweise zur Fehlerbehebung

Wenn beim Kompilieren Fehler auftreten wie "No such module 'ReadwiseKit'" oder "Cannot find type 'BookPreview' in scope":

1. Schließe Xcode vollständig und öffne es neu
2. Führe die folgenden Befehle aus, um die Abhängigkeiten zu aktualisieren:

```bash
# Bereinige das Projekt
xcodebuild clean
rm -rf ./build
rm -rf ~/Library/Developer/Xcode/DerivedData/ReadwiseHighApp-*

# Aktualisiere und baue das Swift Package
cd ReadwiseKit
swift package clean
swift package update
swift build

# Öffne das Projekt neu
cd ..
open -a Xcode ReadwiseHighApp.xcodeproj
```

3. Nach dem Öffnen des Projekts in Xcode:
   - Wähle im Projektnavigator das ReadwiseHighApp-Projekt aus
   - Gehe zu "Build Phases" > "Link Binary With Libraries"
   - Überprüfe, ob ReadwiseKit, ReadwiseModels und ReadwiseUI aufgelistet sind
   - Falls nicht, füge sie mit dem "+" hinzu und wähle sie aus der Liste aus

4. Wenn das Problem bestehen bleibt:
   - Öffne den Swift Package Manager in Xcode (File > Add Package Dependencies...)
   - Füge das lokale ReadwiseKit-Package hinzu (wähle den ReadwiseKit-Ordner)
   - Stelle sicher, dass alle drei Produkte ausgewählt sind: ReadwiseKit, ReadwiseModels und ReadwiseUI

Hinweis: Achte darauf, dass keine doppelten Definitionen von Typen wie BookPreview oder HighlightItem existieren. Diese sollten nur im ReadwiseKit-Package definiert sein. 