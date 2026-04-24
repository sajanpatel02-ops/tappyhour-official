import SwiftUI

/// Dismissable banner that appears when a venue load failed. Tapping
/// Retry re-runs `loadVenues()`. Kept generic so we can drop it into
/// ListFeedView, BottomSheetContent, or anywhere else that looks
/// suspiciously "empty" after a failed load.
struct LoadErrorBanner: View {
    @Bindable var vm: AppViewModel
    private var t: AppTheme { vm.theme }

    var body: some View {
        if vm.loadError != nil {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Couldn't load bars")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(t.text)
                    Text("Check your connection and try again.")
                        .font(.system(size: 11))
                        .foregroundStyle(t.muted)
                }
                Spacer()
                Button {
                    Task { await vm.loadVenues() }
                } label: {
                    if vm.isLoading {
                        ProgressView().tint(t.accent).scaleEffect(0.8)
                            .frame(width: 60)
                    } else {
                        Text("Retry")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(vm.isDark ? Color(hex: "#0b0910") : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(t.accent)
                            .clipShape(Capsule())
                    }
                }
                .disabled(vm.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(t.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.orange.opacity(0.4), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
