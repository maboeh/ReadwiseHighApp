import SwiftUI

// Suchleiste
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)

            TextField("Suchen...", text: $text)
                .disableAutocorrection(true)

            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(8)
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        #else
        .background(Color(UIColor.systemGray6))
        #endif
        .cornerRadius(10)
    }
}
