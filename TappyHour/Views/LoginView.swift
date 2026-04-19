import SwiftUI

struct LoginView: View {
    @Bindable var vm: AppViewModel

    var body: some View {
        let t = vm.theme
        ZStack {
            t.bg.ignoresSafeArea()

            // Ambient glow
            RadialGradient(
                colors: [t.accent.opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: 0.35),
                startRadius: 0, endRadius: 300
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip
                HStack {
                    Spacer()
                    Button("Skip") { vm.showLogin = false }
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(t.muted)
                        .padding(.horizontal, 20)
                        .padding(.top, 56)
                }

                Spacer()

                // Wordmark
                VStack(spacing: 6) {
                    Text("tappy")
                        .font(.custom("Georgia-BoldItalic", size: 64))
                        .foregroundStyle(t.text)
                        .tracking(-1)
                    + Text("/")
                        .font(.custom("Georgia-Italic", size: 56))
                        .foregroundStyle(t.accent)
                    + Text("hour")
                        .font(.custom("Georgia-Italic", size: 64))
                        .foregroundStyle(t.text)
                        .tracking(-1)
                    Text("Find happy hour near you")
                        .font(.system(size: 15))
                        .foregroundStyle(t.muted)
                        .padding(.top, 14)
                }

                Spacer()

                // Auth buttons
                VStack(spacing: 12) {
                    AuthButton(label: "Continue with Apple", icon: "apple.logo", theme: t) {
                        vm.isLoggedIn = true
                        vm.showLogin = false
                    }
                    AuthButton(label: "Continue with Google", icon: "g.circle", theme: t) {
                        vm.isLoggedIn = true
                        vm.showLogin = false
                    }
                    AuthButton(label: "Continue with Email", icon: "envelope", theme: t) {
                        vm.isLoggedIn = true
                        vm.showLogin = false
                    }

                    // Browse without account
                    Button {
                        vm.showLogin = false
                    } label: {
                        Text("Browse without an account")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(vm.isDark ? Color(hex: "#0b0910") : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(t.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)

                // Disclaimer
                Text("Must be 21+ to use TappyHour")
                    .font(.system(size: 12))
                    .foregroundStyle(t.muted)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(vm.isDark ? .dark : .light)
    }
}

private struct AuthButton: View {
    let label: String
    let icon: String
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(theme.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(theme.cardBorder, lineWidth: 0.5)
            )
        }
    }
}
