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
        guard !startTime.isEmpty, !endTime.isEmpty,
              let s = DaySchedule.hhmmParser.date(from: startTime),
              let e = DaySchedule.hhmmParser.date(from: endTime) else {
            return [DaySchedule.displayTime(startTime), DaySchedule.displayTime(endTime)]
                .filter { !$0.isEmpty }.joined(separator: " – ")
        }

        if DaySchedule.uses12h {
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

    // MARK: - Cached formatters
    //
    // These are shared rather than allocated per call: every venue card and
    // detail row formats a time window, and DateFormatter construction is
    // orders of magnitude more expensive than the formatting itself. They're
    // configured once and never mutated, which is safe to share.

    fileprivate static let hhmmParser: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let localeTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .current
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private static func fixedFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = format
        return f
    }

    private static let hourOnly12h  = fixedFormatter("h")
    private static let hourMinute12h = fixedFormatter("h:mm")
    private static let periodOnly    = fixedFormatter("a")
    private static let hourOnly24h   = fixedFormatter("H")
    private static let hourMinute24h = fixedFormatter("H:mm")

    /// Whether the user's locale renders times in 12-hour form.
    fileprivate static let uses12h: Bool = {
        let template = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
        return template.contains("a")
    }()

    /// "HH:mm" → user-locale time string. Returns the input unchanged if
    /// it can't be parsed (e.g. empty, malformed).
    static func displayTime(_ hhmm: String) -> String {
        guard !hhmm.isEmpty else { return "" }
        guard let d = hhmmParser.date(from: hhmm) else { return hhmm }
        return localeTimeFormatter.string(from: d)
    }

    private static func hasZeroMinutes(_ d: Date) -> Bool {
        Calendar.current.component(.minute, from: d) == 0
    }

    /// "4" or "4:30" — 12h hour, minutes only when non-zero.
    fileprivate static func bare12h(_ d: Date) -> String {
        (hasZeroMinutes(d) ? hourOnly12h : hourMinute12h).string(from: d)
    }

    /// "AM" or "PM".
    fileprivate static func period(_ d: Date) -> String {
        periodOnly.string(from: d)
    }

    /// 24h: "16" or "16:30".
    fileprivate static func bare24h(_ d: Date) -> String {
        (hasZeroMinutes(d) ? hourOnly24h : hourMinute24h).string(from: d)
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
        guard let end = todayEndMinutes else { return nil }
        let mins = end - Venue.nowMinutes
        return mins >= 0 ? mins : nil
    }

    /// Minutes until today's happy hour starts, or nil if there's no
    /// happy hour today, it's already started, or we couldn't parse.
    var minutesUntilStart: Int? {
        guard let start = todayStartMinutes else { return nil }
        let mins = start - Venue.nowMinutes
        return mins > 0 ? mins : nil
    }

    /// Currently inside today's happy hour window.
    var isLiveNow: Bool {
        guard let start = todayStartMinutes, let end = todayEndMinutes else { return false }
        let now = Venue.nowMinutes
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

    /// Today's happy hour window expressed as minutes since local midnight.
    private var todayStartMinutes: Int? { Venue.minutesSinceMidnight(deal(for: TODAY)?.startTime) }
    private var todayEndMinutes:   Int? { Venue.minutesSinceMidnight(deal(for: TODAY)?.endTime) }

    /// "HH:mm" → minutes since midnight. Hand-parsed rather than run
    /// through a DateFormatter on purpose: live-status is evaluated for
    /// every venue on every map/list render (and previously once per
    /// comparison inside a sort), and allocating a fresh DateFormatter
    /// each time was the dominant cost in map pan/zoom.
    ///
    /// Internal format is always "HH:mm" — admin uses a picker and the
    /// repo trims Postgres's "HH:mm:ss" down to "HH:mm" on read.
    /// Tolerates surrounding whitespace (the DateFormatter it replaced did)
    /// and a trailing ":ss" (Postgres `time` shape, in case a payload ever
    /// reaches here untrimmed — the old parser returned nil for those, which
    /// silently made the venue never read as live).
    static func minutesSinceMidnight(_ raw: String?) -> Int? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ":")
        guard parts.count >= 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return h * 60 + m
    }

    /// Current wall-clock time as minutes since local midnight.
    private static var nowMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
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
