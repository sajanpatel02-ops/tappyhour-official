import SwiftUI

/// Second-axis filter chip that sits next to `DayFilterChip`. Toggles
/// `vm.showFavoritesOnly` so users can combine "Friday + only favorites"
/// instead of picking one or the other.
///
/// When signed out, tapping prompts sign-in via `vm.toggleFavoritesOnly()`
/// and the toggle flips on automatically after the auth flow completes.
struct FavoritesFilterChip: View {
    @Bindable var vm: AppViewModel
    private var t: AppTheme { vm.theme }
    private var isOn: Bool { vm.showFavoritesOnly }

    var body: some View {
        Button {
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
            vm.toggleFavoritesOnly()
        } label: {
            HStack(spacing: 6) {
                MartiniGlassIcon(
                    size: 14,
                    lineWidth: 1.4,
                    filled: isOn,
                    color: isOn ? t.accent : t.text
                )
                Text("Favorites")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? t.accent : t.text)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isOn ? t.accent.opacity(0.12) : t.card)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isOn ? t.accent.opacity(0.35) : t.cardBorder,
                    lineWidth: 0.5
                )
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)
        }
        .buttonStyle(.plain)
    }
}
