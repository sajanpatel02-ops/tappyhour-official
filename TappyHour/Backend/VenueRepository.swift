import Foundation
import CoreLocation
import Supabase

private extension ISO8601DateFormatter {
    static let withFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// Wire DTOs (match column names exactly)
private struct VenueRow: Decodable {
    let id: String
    let name: String
    let short_name: String
    let cuisine: String?
    let vibe: String?
    let neighborhood: String?
    let price_tier: Int?
    let rating: Double?
    let reviews_count: Int?
    let tags: [String]?
    let address: String?
    let phone: String?
    let website: String?
    let photo_url: String?
    // location is geography(point); we read lng/lat via the helpers below
    let lat: Double?
    let lng: Double?
    let schedule_updated_at: String?
    let deals_source_url: String?
}

private struct ScheduleRow: Decodable {
    let id: String
    let venue_id: String
    let day: String        // "mon".."sun"
    let start_time: String // "15:00:00"
    let end_time: String
    let headline: String?
}

private struct MenuRow: Decodable {
    let id: String
    let schedule_id: String
    let name: String
    let normal_price: Double
    let deal_price: Double
    let sort_order: Int?
}

enum VenueRepository {
    /// Fetch one venue by id regardless of published state (used right after create).
    static func fetchOne(id: String) async throws -> Venue? {
        let rows: [VenueRow] = try await Supa.client
            .from("venues_with_latlng")
            .select()
            .eq("id", value: id)
            .execute()
            .value
        guard let v = rows.first else { return nil }

        let schedules: [ScheduleRow] = try await Supa.client
            .from("venue_schedules")
            .select()
            .eq("venue_id", value: id)
            .execute()
            .value

        let scheduleIds = schedules.map(\.id)
        let menu: [MenuRow] = scheduleIds.isEmpty ? [] : (try await Supa.client
            .from("menu_items")
            .select()
            .in("schedule_id", values: scheduleIds)
            .execute()
            .value)

        return assemble(row: v, schedules: schedules, menu: menu)
    }

    /// Fetch all published venues + their schedules + menu items, assembled into Venue models.
    static func fetchAll() async throws -> [Venue] {
        async let venuesTask: [VenueRow] = Supa.client
            .from("venues_with_latlng")            // SQL view that exposes lat/lng
            .select()
            .eq("is_published", value: true)
            .execute()
            .value

        async let schedulesTask: [ScheduleRow] = Supa.client
            .from("venue_schedules")
            .select()
            .execute()
            .value

        async let menuTask: [MenuRow] = Supa.client
            .from("menu_items")
            .select()
            .execute()
            .value

        let (rows, schedules, menu) = try await (venuesTask, schedulesTask, menuTask)
        let menuByScheduleId = Dictionary(grouping: menu, by: \.schedule_id)
        let schedulesByVenue = Dictionary(grouping: schedules, by: \.venue_id)

        return rows.map { v in
            assemble(row: v,
                     schedules: schedulesByVenue[v.id] ?? [],
                     menu: (schedulesByVenue[v.id] ?? []).flatMap { menuByScheduleId[$0.id] ?? [] })
        }
    }

    private static func assemble(row v: VenueRow, schedules: [ScheduleRow], menu: [MenuRow]) -> Venue {
        let menuByScheduleId = Dictionary(grouping: menu, by: \.schedule_id)
        var dict: [DayKey: DaySchedule] = [:]
        for s in schedules {
            guard let day = mapDay(s.day) else { continue }
            let items = (menuByScheduleId[s.id] ?? [])
                .sorted(by: { ($0.sort_order ?? 0) < ($1.sort_order ?? 0) })
                .map {
                    HappyHourItem(
                        id: UUID(uuidString: $0.id) ?? UUID(),
                        item: $0.name,
                        normal: $0.normal_price,
                        deal: $0.deal_price
                    )
                }
            dict[day] = DaySchedule(
                hours: formatHours(start: s.start_time, end: s.end_time),
                headline: s.headline ?? "",
                menu: items
            )
        }
        return Venue(
            id: v.id,
            name: v.name,
            neighborhood: v.neighborhood ?? "",
            cuisine: v.cuisine ?? "",
            vibe: v.vibe ?? "",
            rating: v.rating ?? 0,
            reviews: v.reviews_count ?? 0,
            distance: 0,
            walk: 0,
            price: priceString(v.price_tier ?? 2),
            endsIn: 9999,
            coordinate: CLLocationCoordinate2D(latitude: v.lat ?? 0, longitude: v.lng ?? 0),
            tags: v.tags ?? [],
            schedule: dict,
            scheduleUpdatedAt: parseTimestamp(v.schedule_updated_at),
            photoUrl: v.photo_url,
            dealsSourceUrl: v.deals_source_url
        )
    }

    private static let iso8601 = ISO8601DateFormatter.withFractional
    private static func parseTimestamp(_ s: String?) -> Date? {
        guard let s else { return nil }
        return iso8601.date(from: s) ?? ISO8601DateFormatter().date(from: s)
    }

    struct NewVenue {
        var name: String
        var shortName: String = ""
        var cuisine: String = ""
        var vibe: String = ""
        var neighborhood: String = ""
        var priceTier: Int = 2
        var address: String = ""
        var phone: String = ""
        var website: String = ""
        var lat: Double
        var lng: Double
    }

    /// Create a new (unpublished) venue and return its id.
    static func createVenue(_ v: NewVenue) async throws -> String {
        struct Args: Encodable {
            let p_name: String; let p_short_name: String
            let p_cuisine: String; let p_vibe: String; let p_neighborhood: String
            let p_price_tier: Int
            let p_address: String; let p_phone: String; let p_website: String
            let p_lat: Double; let p_lng: Double
        }
        let args = Args(
            p_name: v.name, p_short_name: v.shortName,
            p_cuisine: v.cuisine, p_vibe: v.vibe, p_neighborhood: v.neighborhood,
            p_price_tier: v.priceTier,
            p_address: v.address, p_phone: v.phone, p_website: v.website,
            p_lat: v.lat, p_lng: v.lng
        )
        let id: String = try await Supa.client
            .rpc("create_venue", params: args)
            .execute()
            .value
        return id
    }

    /// Save the URL that was used to extract this venue's happy hour info.
    /// Shown as a "View menu online" link on the detail view.
    static func setDealsSourceUrl(venueId: String, url: String) async throws {
        struct Args: Encodable { let p_venue_id: String; let p_url: String }
        _ = try await Supa.client
            .rpc("set_deals_source_url", params: Args(p_venue_id: venueId, p_url: url))
            .execute()
    }

    /// Publish (replace) the entire schedule for a venue.
    static func publish(venueId: String, schedule: [DayKey: DaySchedule]) async throws {
        struct ItemPayload: Encodable { let name: String; let normal: Double; let deal: Double }
        struct DayPayload: Encodable {
            let day: String; let start: String; let end: String
            let headline: String; let items: [ItemPayload]
        }
        struct Args: Encodable { let p_venue_id: String; let p_payload: [DayPayload] }

        let payload: [DayPayload] = schedule.compactMap { (dayKey, ds) in
            guard let (startHHmm, endHHmm) = parseHours(ds.hours) else { return nil }
            return DayPayload(
                day: dbDay(dayKey),
                start: startHHmm,
                end: endHHmm,
                headline: ds.headline,
                items: ds.menu.map { ItemPayload(name: $0.item, normal: $0.normal, deal: $0.deal) }
            )
        }

        _ = try await Supa.client
            .rpc("publish_schedule", params: Args(p_venue_id: venueId, p_payload: payload))
            .execute()
    }

    // MARK: helpers
    private static func mapDay(_ s: String) -> DayKey? {
        switch s {
        case "mon": .mo; case "tue": .tu; case "wed": .we; case "thu": .th
        case "fri": .fr; case "sat": .sa; case "sun": .su
        default: nil
        }
    }

    private static func priceString(_ tier: Int) -> String {
        String(repeating: "$", count: max(1, min(4, tier)))
    }

    private static func dbDay(_ d: DayKey) -> String {
        switch d {
        case .mo: "mon"; case .tu: "tue"; case .we: "wed"; case .th: "thu"
        case .fr: "fri"; case .sa: "sat"; case .su: "sun"
        }
    }

    /// "3:00 – 6:00 PM" -> ("15:00", "18:00"). Assumes start shares the end's am/pm.
    static func parseHours(_ s: String) -> (String, String)? {
        let parts = s.components(separatedBy: "–").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2 else { return nil }
        let rawStart = parts[0], rawEnd = parts[1]

        let withPeriod = DateFormatter(); withPeriod.dateFormat = "h:mm a"
        let noPeriod   = DateFormatter(); noPeriod.dateFormat   = "h:mm"
        let out        = DateFormatter(); out.dateFormat        = "HH:mm"

        guard let endDate = withPeriod.date(from: rawEnd) else { return nil }
        let period: String = rawEnd.uppercased().contains("PM") ? "PM" : "AM"

        let startDate: Date? = withPeriod.date(from: rawStart)
            ?? withPeriod.date(from: "\(rawStart) \(period)")
            ?? noPeriod.date(from: rawStart).flatMap { _ in
                withPeriod.date(from: "\(rawStart) \(period)")
            }

        guard let startDate else { return nil }
        return (out.string(from: startDate), out.string(from: endDate))
    }

    /// "15:00:00" + "18:00:00" -> "3:00 – 6:00 PM"
    private static func formatHours(start: String, end: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        let out = DateFormatter()
        out.dateFormat = "h:mm"
        let outAmPm = DateFormatter()
        outAmPm.dateFormat = "h:mm a"
        guard let s = f.date(from: start), let e = f.date(from: end) else {
            return "\(start) – \(end)"
        }
        return "\(out.string(from: s)) – \(outAmPm.string(from: e))"
    }
}
