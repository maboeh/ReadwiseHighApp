import SwiftUI


// Filter-Button
public struct CategoryFilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    public init(title: String, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                #if os(macOS)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                #else
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                #endif
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
} 