import SwiftUI

/// Shown when a user taps a bar from search that isn't in our database.
/// Offers a one-tap "Request to be added" action. If the user has already
/// requested this bar, shows a muted "Requested" pill instead.
struct ExternalVenueSheet: View {
    let name: String
    let address: String
    @Bindable var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var submitting = false
    @State private var errorText: String? = nil
    @State private var justSubmitted = false

    private var t: AppTheme { vm.theme }
    private var alreadyRequested: Bool {
        justSubmitted || vm.hasRequested(name: name, address: address)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    header
                    notAvailableBanner
                    Spacer()
                    actionButton
                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
                .padding(.top, 10)
            }
            .navigationTitle("Bar details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wineglass")
                .font(.system(size: 22))
                .foregroundStyle(t.accent)
                .frame(width: 44, height: 44)
                .background(t.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(t.text)
                if !address.isEmpty {
                    Text(address)
                        .font(.system(size: 13))
                        .foregroundStyle(t.muted)
                }
            }
            Spacer()
        }
    }

    private var notAvailableBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 16))
                .foregroundStyle(t.muted)
            Text("No happy hour info on TappyHour yet.")
                .font(.system(size: 14))
                .foregroundStyle(t.muted)
            Spacer()
        }
        .padding(14)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var actionButton: some View {
        if !vm.isLoggedIn {
            // Logged-out users get a sign-in prompt instead of the request
            // form. Gates abuse and matches Apple's expectation that any
            // user-generated content endpoint is tied to an account.
            Button {
                vm.showLogin = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                    Text("Sign in to request this bar")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(vm.isDark ? Color(hex: "#1a1008") : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(vm.theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        } else if !vm.appConfig.allowSuggestions {
            // Gated by remote config — `allow_suggestions = false` in
            // Supabase `app_config` hides the request flow without an
            // app update (e.g. if we're being spammed).
            HStack(spacing: 8) {
                Image(systemName: "moon.zzz")
                Text("Requests are paused")
            }
            .font(.system(size: 14))
            .foregroundStyle(vm.theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(vm.theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if alreadyRequested {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Requested")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(t.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    if submitting { ProgressView().tint(vm.isDark ? .black : .white) }
                    Text(submitting ? "Submitting…" : "Request to be added")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(vm.isDark ? Color(hex: "#1a1008") : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(t.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(submitting)
        }
    }

    @MainActor
    private func submit() async {
        errorText = nil
        submitting = true
        defer { submitting = false }
        do {
            try await vm.submitSuggestion(name: name, address: address)
            justSubmitted = true
        } catch {
            errorText = error.localizedDescription
        }
    }
}
