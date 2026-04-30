import SwiftUI

struct ContentView: View {
    @State private var vm = AppViewModel()
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false

    var body: some View {
        let t = vm.theme
        ZStack {
            t.bg.ignoresSafeArea()

            // Kill switch — when set in Supabase `app_config`, replaces the
            // entire app with a maintenance screen. Nothing else renders.
            if vm.appConfig.isKilled {
                MaintenanceView(vm: vm)
                    .transition(.opacity)
            } else {
                if !vm.showLogin {
                    mainContent
                }

                // Login overlay
                if vm.showLogin {
                    LoginView(vm: vm)
                        .transition(.opacity)
                        .zIndex(10)
                }

                // Venue detail overlay
                if let id = vm.openVenueId, let venue = vm.resolvedVenue(id) {
                    VenueDetailView(venue: venue, vm: vm)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                        .zIndex(8)
                }

                // Admin overlay
                if let id = vm.adminVenueId, let venue = vm.resolvedVenue(id) {
                    AdminView(venue: venue, vm: vm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(9)
                }

                // Search overlay
                if vm.isSearchActive {
                    SearchOverlayView(vm: vm)
                        .transition(.opacity)
                        .zIndex(7)
                }
            }
        }
        .animation(.spring(duration: 0.3), value: vm.showLogin)
        .animation(.spring(duration: 0.3), value: vm.openVenueId)
        .animation(.spring(duration: 0.3), value: vm.adminVenueId)
        .animation(.easeInOut(duration: 0.2), value: vm.isSearchActive)
        .animation(.easeInOut(duration: 0.25), value: vm.appConfig.isKilled)
        .preferredColorScheme(vm.isDark ? .dark : .light)
        .task {
            LocationManager.shared.requestAndStart()
            // Refresh kill switch / feature flags first — if killed, we
            // skip the rest so we don't hit other endpoints under load.
            await vm.refreshAppConfig()
            guard !vm.appConfig.isKilled else { return }
            await vm.restoreSession()
            await vm.loadVenues()
            await vm.loadMySuggestions()
            await vm.loadMyReports()
        }
        .sheet(isPresented: $vm.isAddingVenue) {
            AddVenueSheet(vm: vm)
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete account", role: .destructive) {
                isDeletingAccount = true
                Task {
                    _ = await vm.deleteAccount()
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, your saved bars, suggestions, and reports. This can't be undone.")
        }
        .overlay {
            if isDeletingAccount {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Deleting account…")
                        .padding(20)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDeletingAccount)
    }

    @ViewBuilder
    private var mainContent: some View {
        let t = vm.theme
        ZStack(alignment: .top) {
            // Main view content
            switch vm.viewMode {
            case .map:
                MapDiscoveryView(vm: vm)
                    .ignoresSafeArea()
            case .list, .feed:
                ListFeedView(vm: vm)
                    .background(t.bg)
                    .safeAreaInset(edge: .top) { Color.clear.frame(height: 130) }
            }

            // Top search bar
            topBar(t: t)

            // Map/List toggle pill
            viewTogglePill(t: t)
        }
    }

    private func topBar(t: AppTheme) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Search bar
                Button { vm.isSearchActive = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 15))
                            .foregroundStyle(t.muted)

                        if vm.query.isEmpty {
                            Text("Search neighborhoods, bars, deals…")
                                .font(.system(size: 14))
                                .foregroundStyle(t.muted)
                        } else {
                            Text(vm.query)
                                .font(.system(size: 14))
                                .foregroundStyle(t.text)
                        }

                        Spacer()

                        if !vm.query.isEmpty {
                            Button { vm.query = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(t.muted)
                            }
                        } else {
                            Rectangle()
                                .fill(t.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.1))
                                .frame(width: 1, height: 18)
                            HStack(spacing: 4) {
                                Text("Chicago")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(t.text)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 11))
                                    .foregroundStyle(t.muted)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        vm.viewMode == .map
                            ? (t.isDark ? Color(hex: "#1c1b1f").opacity(0.88) : Color.white.opacity(0.95))
                            : t.card
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(t.cardBorder, lineWidth: 0.5)
                    )
                    .shadow(
                        color: vm.viewMode == .map ? .black.opacity(0.12) : .clear,
                        radius: 8, y: 3
                    )
                }
                .buttonStyle(.plain)

                // Profile menu
                Menu {
                    if vm.isLoggedIn {
                        Text("Signed in")
                        Button("Sign out") {
                            Task { await vm.signOut() }
                        }
                        Divider()
                        Button("Delete account", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } else {
                        Button("Sign in") { vm.showLogin = true }
                    }
                } label: {
                    Image(systemName: vm.isLoggedIn ? "person.crop.circle.fill" : "person.crop.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(vm.isLoggedIn ? t.accent : t.text)
                        .frame(width: 44, height: 44)
                        .background(
                            vm.viewMode == .map
                                ? (t.isDark ? Color(hex: "#1c1b1f").opacity(0.88) : Color.white.opacity(0.95))
                                : t.card
                        )
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(t.cardBorder, lineWidth: 0.5))
                        .shadow(
                            color: vm.viewMode == .map ? .black.opacity(0.12) : .clear,
                            radius: 8, y: 3
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 14)
        }
        .background(
            vm.viewMode != .map
                ? t.bg.opacity(1)
                : .clear
        )
    }

    private func viewTogglePill(t: AppTheme) -> some View {
        VStack {
            Spacer()
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    vm.viewMode = vm.viewMode == .map ? .list : .map
                    if vm.viewMode == .map { vm.sheetSize = .half }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: vm.viewMode == .map ? "list.bullet" : "map")
                        .font(.system(size: 14, weight: .semibold))
                    Text(vm.viewMode == .map ? "List" : "Map")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.1)
                }
                .foregroundStyle(vm.isDark ? Color(hex: "#1a1008") : .white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(vm.isDark ? t.accent : Color(hex: "#1a1512"))
                .clipShape(Capsule())
                .shadow(
                    color: vm.isDark ? t.accent.opacity(0.4) : Color.black.opacity(0.25),
                    radius: 12, y: 4
                )
            }
            .padding(.bottom, 30)
        }
    }

}
