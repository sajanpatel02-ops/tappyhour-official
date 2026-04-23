import SwiftUI
import Observation

enum ViewMode { case map, list, feed }
enum SheetSize { case peek, half, full }

@Observable
class AppViewModel {
    var isDark: Bool = true
    var accent: Color = AccentOption.tungsten.color

    var viewMode: ViewMode = .map
    var showLogin: Bool = true
    var isLoggedIn: Bool = false
    var isAuthenticating: Bool = false
    var authError: String? = nil

    var isAdmin: Bool = false
    var managedVenueIds: Set<String> = []
    var canManageAny: Bool { isAdmin || !managedVenueIds.isEmpty }

    var selectedVenueId: String? = nil
    var openVenueId: String? = nil
    var sheetSize: SheetSize = .half

    var savedIds: Set<String> = []
    var query: String = ""
    var isSearchActive: Bool = false

    var adminVenueId: String? = nil
    var isAddingVenue: Bool = false
    var venueOverrides: [String: [DayKey: DaySchedule]] = [:]

    var venues: [Venue] = []
    var isLoading: Bool = false
    var loadError: String? = nil

    /// The signed-in user's past venue requests. Loaded on start so we can
    /// mark already-requested bars with a "Requested" pill in search.
    var mySuggestions: [VenueRepository.VenueSuggestion] = []

    /// Venue IDs the user has already flagged as outdated. Drives the
    /// "Reported" pill on VenueDetailView so they can't spam-tap it.
    var myReportedVenueIds: Set<String> = []

    var theme: AppTheme { AppTheme(isDark: isDark, accent: accent) }

    var filteredVenues: [Venue] {
        guard !query.isEmpty else { return venues }
        let q = query.lowercased()
        return venues.filter {
            $0.name.lowercased().contains(q) ||
            $0.neighborhood.lowercased().contains(q) ||
            $0.cuisine.lowercased().contains(q)
        }
    }

    func venue(_ id: String) -> Venue? { venues.first { $0.id == id } }

    @MainActor
    func signInApple() async {
        isAuthenticating = true; authError = nil
        do {
            try await AuthService.shared.signInWithApple()
            isLoggedIn = true; showLogin = false
            await refreshRole()
        } catch {
            authError = "Apple sign-in failed: \(error.localizedDescription)"
        }
        isAuthenticating = false
    }

    @MainActor
    func signInGoogle() async {
        isAuthenticating = true; authError = nil
        do {
            try await AuthService.shared.signInWithGoogle()
            isLoggedIn = true; showLogin = false
            await refreshRole()
        } catch {
            authError = "Google sign-in failed: \(error.localizedDescription)"
        }
        isAuthenticating = false
    }

    @MainActor
    func signOut() async {
        try? await AuthService.shared.signOut()
        isLoggedIn = false; showLogin = true
        isAdmin = false; managedVenueIds = []
        savedIds = []
        query = ""
    }

    @MainActor
    func restoreSession() async {
        if AuthService.shared.currentUser() != nil {
            isLoggedIn = true; showLogin = false
            await refreshRole()
        }
    }

    @MainActor
    func refreshRole() async {
        async let admin  = AuthService.shared.fetchIsAdmin()
        async let mine   = AuthService.shared.fetchManagedVenueIds()
        let (a, m) = await (admin, mine)
        isAdmin = a
        managedVenueIds = m
    }

    @MainActor
    func loadVenues() async {
        isLoading = true; loadError = nil
        do {
            // Server is source of truth — always overwrite, even if empty.
            // The old `if !remote.isEmpty` guard kept stale/deleted venues
            // and sample data alive when the DB was cleared.
            venues = try await VenueRepository.fetchAll()
        } catch {
            loadError = "\(error)"
            print("VenueRepository.fetchAll failed:", error)
        }
        isLoading = false
    }

    @MainActor
    func loadMySuggestions() async {
        guard isLoggedIn else { mySuggestions = []; return }
        do { mySuggestions = try await VenueRepository.fetchMySuggestions() }
        catch { print("fetchMySuggestions failed:", error) }
    }

    /// True if the signed-in user already requested a bar matching this
    /// name+address (case-insensitive). Used for the "Requested" pill.
    func hasRequested(name: String, address: String?) -> Bool {
        let n = name.lowercased()
        let a = (address ?? "").lowercased()
        return mySuggestions.contains {
            $0.name.lowercased() == n && ($0.address ?? "").lowercased() == a
        }
    }

    @MainActor
    func submitSuggestion(name: String, address: String) async throws {
        try await VenueRepository.submitSuggestion(name: name, address: address)
        await loadMySuggestions()
    }

    @MainActor
    func loadMyReports() async {
        guard isLoggedIn else { myReportedVenueIds = []; return }
        do {
            let reports = try await VenueRepository.fetchMyReports()
            myReportedVenueIds = Set(reports.map(\.venue_id))
        } catch { print("fetchMyReports failed:", error) }
    }

    func hasReported(_ venueId: String) -> Bool {
        myReportedVenueIds.contains(venueId)
    }

    @MainActor
    func reportOutdated(venueId: String) async throws {
        try await VenueRepository.reportOutdated(venueId: venueId)
        myReportedVenueIds.insert(venueId)
    }

    func resolvedVenue(_ id: String) -> Venue? {
        guard var v = venue(id) else { return nil }
        if let override = venueOverrides[id] { v.schedule = override }
        return v
    }

    func toggleSave(_ id: String) {
        if savedIds.contains(id) { savedIds.remove(id) } else { savedIds.insert(id) }
    }

    func selectPin(_ id: String?) {
        selectedVenueId = id
        if id != nil { sheetSize = .peek }
    }

    func openVenue(_ id: String) { openVenueId = id }

    func saveAdminSchedule(_ venueId: String, _ schedule: [DayKey: DaySchedule]) {
        venueOverrides[venueId] = schedule
        adminVenueId = nil
    }

    @MainActor
    func publishAdminSchedule(_ venueId: String, _ schedule: [DayKey: DaySchedule]) async -> Bool {
        do {
            try await VenueRepository.publish(venueId: venueId, schedule: schedule)
            // Refresh from server so all clients see the truth
            await loadVenues()
            adminVenueId = nil
            return true
        } catch {
            loadError = "Publish failed: \(error)"
            print("publish failed:", error)
            return false
        }
    }
}
