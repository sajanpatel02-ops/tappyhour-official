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
    /// 24-hour "HH:mm" — matches Postgres `time` column so we can round-trip
    /// without parsing. Empty string means "unset" (kept simple instead of
    /// optional to avoid threading `?` through every call site).
    var startTime: String
    var endTime: String
    var headline: String
    var menu: [HappyHourItem]

    /// Locale-aware display string. Compact on US 12-hour locales:
    ///   "4 – 6 PM" when start and end share a period
    ///   "11 AM – 2 PM" when they don't
    /// On 24h locales: "16 – 18" (or "16:30 – 18:30" with non-zero minutes).
    /// Falls back to raw values if either side is unparseable.
    var displayWindow: String {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "HH:mm"
        guard !startTime.isEmpty, !endTime.isEmpty,
              let s = parser.date(from: startTime),
              let e = parser.date(from: endTime) else {
            return [DaySchedule.displayTime(startTime), DaySchedule.displayTime(endTime)]
                .filter { !$0.isEmpty }.joined(separator: " – ")
        }

        let uses12h: Bool = {
            let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
            return template.contains("a")
        }()

        if uses12h {
            let sPeriod = DaySchedule.period(s), ePeriod = DaySchedule.period(e)
            let sBare = DaySchedule.bare12h(s)
            let eBare = DaySchedule.bare12h(e)
            // Same period → drop the start's AM/PM. Different → keep both.
            if sPeriod == ePeriod {
                return "\(sBare) – \(eBare) \(ePeriod)"
            } else {
                return "\(sBare) \(sPeriod) – \(eBare) \(ePeriod)"
            }
        } else {
            return "\(DaySchedule.bare24h(s)) – \(DaySchedule.bare24h(e))"
        }
    }

    /// "HH:mm" → user-locale time string. Returns the input unchanged if
    /// it can't be parsed (e.g. empty, malformed).
    static func displayTime(_ hhmm: String) -> String {
        guard !hhmm.isEmpty else { return "" }
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "HH:mm"
        guard let d = parser.date(from: hhmm) else { return hhmm }
        let out = DateFormatter()
        out.locale = .current
        out.timeStyle = .short
        out.dateStyle = .none
        return out.string(from: d)
    }

    /// "4" or "4:30" — 12h hour, minutes only when non-zero.
    fileprivate static func bare12h(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = (Calendar.current.component(.minute, from: d) == 0) ? "h" : "h:mm"
        return f.string(from: d)
    }

    /// "AM" or "PM".
    fileprivate static func period(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "a"
        return f.string(from: d)
    }

    /// 24h: "16" or "16:30".
    fileprivate static func bare24h(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = (Calendar.current.component(.minute, from: d) == 0) ? "H" : "H:mm"
        return f.string(from: d)
    }
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
        // Internal format is always "HH:mm" since admin uses a picker and
        // the repo trims Postgres's "HH:mm:ss" down to "HH:mm" on read.
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = .current
        fmt.dateFormat = "HH:mm"
        guard let parsed = fmt.date(from: raw) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let comps = cal.dateComponents([.hour, .minute], from: parsed)
        return cal.date(byAdding: comps, to: today)
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
