import Foundation
import CoreLocation

enum DayKey: String, CaseIterable, Identifiable, Hashable {
    case mo = "Mo", tu = "Tu", we = "We", th = "Th", fr = "Fr", sa = "Sa", su = "Su"
    var id: String { rawValue }
    var shortName: String { rawValue }
    var displayName: String {
        switch self {
        case .mo: "Monday"; case .tu: "Tuesday"; case .we: "Wednesday"
        case .th: "Thursday"; case .fr: "Friday"; case .sa: "Saturday"; case .su: "Sunday"
        }
    }
}

struct HappyHourItem: Identifiable {
    let id: UUID
    var item: String
    /// Normal (pre-discount) price. Nil when only a label is provided
    /// (e.g. "50% off wine" or "$6-$12 small bites").
    var normal: Double?
    /// Deal price. Nil when only a label is provided.
    var deal: Double?
    /// Free-form label for deals that don't map to a single number
    /// (e.g. "50% off", "$6-$12"). Mutually exclusive with normal/deal.
    var label: String?
    init(id: UUID = UUID(), item: String,
         normal: Double? = nil, deal: Double? = nil, label: String? = nil) {
        self.id = id; self.item = item
        self.normal = normal; self.deal = deal; self.label = label
    }
}

struct DaySchedule {
    var hours: String
    var headline: String
    var menu: [HappyHourItem]
    var endTime: String { hours.components(separatedBy: "–").last?.trimmingCharacters(in: .whitespaces) ?? "" }
    var startTime: String { hours.components(separatedBy: "–").first?.trimmingCharacters(in: .whitespaces) ?? "" }
}

struct Venue: Identifiable {
    let id: String
    let name: String
    let neighborhood: String
    let cuisine: String
    let vibe: String
    let rating: Double
    let reviews: Int
    let distance: Double
    let walk: Int
    let price: String
    let coordinate: CLLocationCoordinate2D
    let tags: [String]
    // Keys present = has happy hour that day; missing key = no happy hour
    var schedule: [DayKey: DaySchedule]
    var scheduleUpdatedAt: Date? = nil
    var photoUrl: String? = nil
    var dealsSourceUrl: String? = nil
    var phone: String? = nil

    // MARK: - Live time-based status (computed against `Date.now`)

    /// Minutes until today's happy hour ends, or nil if there's no happy
    /// hour today / it's already over / we couldn't parse the time.
    /// Negative values are clamped to nil (already ended).
    var minutesUntilEnd: Int? {
        guard let end = todayEndDate() else { return nil }
        let mins = Int(end.timeIntervalSince(Date()) / 60)
        return mins >= 0 ? mins : nil
    }

    /// Minutes until today's happy hour starts, or nil if there's no
    /// happy hour today, it's already started, or we couldn't parse.
    var minutesUntilStart: Int? {
        guard let start = todayStartDate() else { return nil }
        let mins = Int(start.timeIntervalSince(Date()) / 60)
        return mins > 0 ? mins : nil
    }

    /// Currently inside today's happy hour window.
    var isLiveNow: Bool {
        guard let start = todayStartDate(), let end = todayEndDate() else { return false }
        let now = Date()
        return now >= start && now < end
    }

    /// Live AND ≤30 min remaining — drives the accent badge / pin glow.
    var isEndingSoon: Bool {
        guard isLiveNow, let m = minutesUntilEnd else { return false }
        return m <= 30
    }

    /// Not started yet, but kicks off within 30 min.
    var isStartingSoon: Bool {
        guard let m = minutesUntilStart else { return false }
        return m <= 30
    }

    /// Sort key for "ending soonest" feed mode. Live-now venues sort by
    /// minutes-until-end (ascending). Everything else sinks to the bottom.
    var endsInSortKey: Int {
        if let m = minutesUntilEnd, isLiveNow { return m }
        return Int.max
    }

    /// Back-compat read-only alias used in a couple of detail views.
    var endsIn: Int { minutesUntilEnd ?? 0 }

    var shortName: String { name.components(separatedBy: " ").last ?? name }

    // MARK: - Internal date helpers

    /// Combines today's date with the schedule's start time string.
    /// Returns nil if no schedule today or the string isn't parseable.
    private func todayStartDate() -> Date? { dateForTodayTime(deal(for: TODAY)?.startTime) }
    private func todayEndDate()   -> Date? { dateForTodayTime(deal(for: TODAY)?.endTime) }

    private func dateForTodayTime(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        // Normalize "16:00", "4:00 PM", "4 PM", etc.
        let formats = ["HH:mm", "H:mm", "h:mm a", "h a", "ha", "h:mma"]
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        for f in formats {
            fmt.dateFormat = f
            if let parsed = fmt.date(from: raw.uppercased()) ?? fmt.date(from: raw) {
                let comps = cal.dateComponents([.hour, .minute], from: parsed)
                return cal.date(byAdding: comps, to: today)
            }
        }
        return nil
    }

    func deal(for day: DayKey) -> DaySchedule? { schedule[day] }
    var activeDays: [DayKey] { DayKey.allCases.filter { schedule[$0] != nil } }

    func summarizeDays() -> String {
        let active = activeDays
        if active.count == 7 { return "Daily" }
        if active.isEmpty { return "No happy hour" }
        let keys = DayKey.allCases
        let indices = active.compactMap { keys.firstIndex(of: $0) }
        guard !indices.isEmpty else { return active.map(\.shortName).joined(separator: " · ") }
        let contiguous = indices.enumerated().allSatisfy { i, idx in i == 0 || idx == indices[i-1] + 1 }
        if contiguous && active.count > 1 {
            return "\(keys[indices.first!].shortName) – \(keys[indices.last!].shortName)"
        }
        return active.map(\.shortName).joined(separator: " · ")
    }
}
