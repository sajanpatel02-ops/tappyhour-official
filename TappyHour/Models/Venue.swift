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
    var normal: Double
    var deal: Double
    init(id: UUID = UUID(), item: String, normal: Double, deal: Double) {
        self.id = id; self.item = item; self.normal = normal; self.deal = deal
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
    let endsIn: Int
    let coordinate: CLLocationCoordinate2D
    let tags: [String]
    // Keys present = has happy hour that day; missing key = no happy hour
    var schedule: [DayKey: DaySchedule]

    var isEndingSoon: Bool { endsIn <= 30 }
    var shortName: String { name.components(separatedBy: " ").last ?? name }

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
