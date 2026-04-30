import SwiftUI

/// Shown in place of the entire app when `appConfig.isKilled` is true.
/// Lets us take the app offline (for outages, security incidents, etc.)
/// without shipping an update. The Retry button re-fetches the config so
/// users can come back online the moment we flip the switch.
struct MaintenanceView: View {
    @Bindable var vm: AppViewModel
    @State private var isRetrying = false

    var body: some View {
        let t = vm.theme
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "wrench.and.screwdriver")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(t.accent)
                    .padding(.bottom, 4)

                Text("We'll be right back")
                    .font(.custom("Georgia", size: 28))
                    .foregroundStyle(t.text)
                    .tracking(-0.4)

                Text(vm.appConfig.killMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(t.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                Button {
                    isRetrying = true
                    Task {
                        await vm.refreshAppConfig()
                        isRetrying = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isRetrying {
                            ProgressView().tint(t.text)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(isRetrying ? "Checking…" : "Try again")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(t.text)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(t.card)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(t.cardBorder, lineWidth: 0.5))
                }
                .disabled(isRetrying)
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
        }
    }
}
