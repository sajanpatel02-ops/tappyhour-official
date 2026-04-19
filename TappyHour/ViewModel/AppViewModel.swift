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

    var selectedVenueId: String? = nil
    var openVenueId: String? = nil
    var sheetSize: SheetSize = .half

    var savedIds: Set<String> = ["v2", "v7"]
    var query: String = ""
    var isSearchActive: Bool = false

    var adminVenueId: String? = nil
    var venueOverrides: [String: [DayKey: DaySchedule]] = [:]

    var theme: AppTheme { AppTheme(isDark: isDark, accent: accent) }

    var filteredVenues: [Venue] {
        guard !query.isEmpty else { return VENUES }
        let q = query.lowercased()
        return VENUES.filter {
            $0.name.lowercased().contains(q) ||
            $0.neighborhood.lowercased().contains(q) ||
            $0.cuisine.lowercased().contains(q)
        }
    }

    func venue(_ id: String) -> Venue? { VENUES.first { $0.id == id } }

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
}
