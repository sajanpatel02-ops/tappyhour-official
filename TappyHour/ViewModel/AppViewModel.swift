import SwiftUI
import Observation
import CoreLocation
import MapKit

enum ViewMode { case map, list, feed }
enum SheetSize { case peek, half, full }

enum ListDayFilter: Hashable {
    case today
    case all
    case day(DayKey)

    var shortLabel: String {
        switch self {
        case .today: "Today"
        case .all:   "All"
        case .day(let d): d.shortName
        }
    }
}

extension MKCoordinateRegion {
    /// True if this region's lat/lng bounding box contains the coordinate.
    /// Good enough for filtering venues to "what's visible on the map" —
    /// we don't need great-circle precision at neighborhood scale.
    func contains(_ coord: CLLocationCoordinate2D) -> Bool {
        let minLat = center.latitude - span.latitudeDelta / 2
        let maxLat = center.latitude + span.latitudeDelta / 2
        let minLng = center.longitude - span.longitudeDelta / 2
        let maxLng = center.longitude + span.longitudeDelta / 2
        return coord.latitude >= minLat && coord.latitude <= maxLat
            && coord.longitude >= minLng && coord.longitude <= maxLng
    }
}

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

    var query: String = ""
    var isSearchActive: Bool = false

    /// ID of the venue currently at the top of the list/feed. Persisted so
    /// tapping into a venue detail and returning lands you back in the
    /// same spot instead of at the top of the list.
    var listScrollTargetId: String? = nil

    /// Filter for the list view: today, a specific weekday, or all (no
    /// day filter — every bar with any happy hour at all).
    var listDayFilter: ListDayFilter = .today

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

    /// The map's current camera region. Updated by MapDiscoveryView as
    /// the user pans/zooms. Drives `venuesInView` so the list reflects
    /// "what's on the map right now".
    var visibleRegion: MKCoordinateRegion? = nil

    var filteredVenues: [Venue] {
        guard !query.isEmpty else { return venues }
        let q = query.lowercased()
        return venues.filter {
            $0.name.lowercased().contains(q) ||
            $0.neighborhood.lowercased().contains(q) ||
            $0.cuisine.lowercased().contains(q)
        }
    }

    /// Returns true if a venue matches the current list day filter.
    ///   - .today: has a schedule for today's weekday
    ///   - .all:   has any happy hour at all
    ///   - .day(d): has a schedule for that specific weekday
    func matchesDayFilter(_ v: Venue) -> Bool {
        switch listDayFilter {
        case .today:      return v.schedule[TODAY] != nil
        case .all:        return !v.schedule.isEmpty
        case .day(let d): return v.schedule[d] != nil
        }
    }

    /// Venues visible in the current map region, sorted by distance from
    /// the user (or map center if we don't have a location yet). This is
    /// what the list view shows so "the list matches what's on the map".
    ///
    /// Falls back to all venues when we don't have a region yet (first
    /// launch, before the map appears). Also applies the search query.
    var venuesInView: [Venue] {
        let base = filteredVenues.filter(matchesDayFilter)
        let filtered: [Venue]
        if let region = visibleRegion {
            filtered = base.filter { region.contains($0.coordinate) }
        } else {
            filtered = base
        }
        let anchor = LocationManager.shared.lastLocation?.coordinate
            ?? visibleRegion?.center
        guard let anchor else { return filtered }
        let ref = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
        return filtered.sorted {
            let a = CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)
            let b = CLLocation(latitude: $1.coordinate.latitude, longitude: $1.coordinate.longitude)
            return ref.distance(from: a) < ref.distance(from: b)
        }
    }

    func venue(_ id: String) -> Venue? { venues.first { $0.id == id } }

    // MARK: - Distance / walk time from user's location

    /// Miles from the user's current location to a venue, or nil if we
    /// don't have a location fix yet (permission denied, simulator
    /// without a set location, etc).
    func distanceMiles(to venue: Venue) -> Double? {
        guard let user = LocationManager.shared.lastLocation else { return nil }
        let v = CLLocation(latitude: venue.coordinate.latitude,
                           longitude: venue.coordinate.longitude)
        return user.distance(from: v) / 1609.344
    }

    /// Rough walk time, assuming ~3 mph (~20 min/mile). Good enough for
    /// a bar-hopping UI where "13 min walk" is a vibe check, not turn-
    /// by-turn nav.
    func walkMinutes(to venue: Venue) -> Int? {
        guard let miles = distanceMiles(to: venue) else { return nil }
        return max(1, Int((miles * 20).rounded()))
    }

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
