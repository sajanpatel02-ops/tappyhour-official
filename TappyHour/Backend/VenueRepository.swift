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
    let normal_price: Double?
    let deal_price: Double?
    let label: String?
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
            .range(from: 0, to: 99_999)
            .execute()
            .value

        // PostgREST caps responses at 1000 rows by default. Once the
        // global menu_items count crosses that line, the most recently
        // published items disappear from the response — and the venue
        // detail view renders with no menu. Bumping the range up front
        // is the simplest scaling fix; we can switch to scoped fetching
        // (where schedule_id in ...) once we're regularly past 10K rows.
        async let menuTask: [MenuRow] = Supa.client
            .from("menu_items")
            .select()
            .range(from: 0, to: 99_999)
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
                        deal: $0.deal_price,
                        label: $0.label
                    )
                }
            dict[day] = DaySchedule(
                // Postgres `time` comes back as "HH:mm:ss" — drop seconds.
                startTime: trimSeconds(s.start_time),
                endTime: trimSeconds(s.end_time),
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
            coordinate: CLLocationCoordinate2D(latitude: v.lat ?? 0, longitude: v.lng ?? 0),
            tags: v.tags ?? [],
            schedule: dict,
            scheduleUpdatedAt: parseTimestamp(v.schedule_updated_at),
            photoUrl: v.photo_url,
            dealsSourceUrl: v.deals_source_url,
            phone: v.phone
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

    // MARK: - Venue suggestions (user-submitted requests)

    struct VenueSuggestion: Decodable, Identifiable, Hashable {
        let id: String
        let name: String
        let address: String?
        let status: String?
    }

    /// Insert a new suggestion for the signed-in user. RLS requires
    /// suggested_by = auth.uid(), which Supabase fills from the JWT.
    static func submitSuggestion(name: String, address: String) async throws {
        struct Row: Encodable {
            let name: String
            let address: String
            let suggested_by: String
        }
        let session = try await Supa.client.auth.session
        let uid = session.user.id.uuidString.lowercased()
        _ = try await Supa.client
            .from("venue_suggestions")
            .insert(Row(name: name, address: address, suggested_by: uid))
            .execute()
    }

    /// Current user's past suggestions, used to show a "Requested" pill in search.
    static func fetchMySuggestions() async throws -> [VenueSuggestion] {
        try await Supa.client
            .from("venue_suggestions")
            .select("id,name,address,status")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - Venue reports (user-flagged "outdated" data)

    struct VenueReport: Decodable, Identifiable, Hashable {
        let id: String
        let venue_id: String
    }

    /// Insert a "this venue's info is outdated" report.
    static func reportOutdated(venueId: String) async throws {
        struct Row: Encodable {
            let venue_id: String
            let reported_by: String
        }
        let session = try await Supa.client.auth.session
        let uid = session.user.id.uuidString.lowercased()
        _ = try await Supa.client
            .from("venue_reports")
            .insert(Row(venue_id: venueId, reported_by: uid))
            .execute()
    }

    /// The current user's past reports (used to show a "Reported" state in UI).
    static func fetchMyReports() async throws -> [VenueReport] {
        try await Supa.client
            .from("venue_reports")
            .select("id,venue_id")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    // MARK: - User favorites

    struct UserFavoriteRow: Decodable {
        let venue_id: String
    }

    /// All venue IDs the current user has favorited. RLS auto-scopes to
    /// the signed-in user; anon callers get an empty array via RLS-block.
    static func fetchMyFavorites() async throws -> [String] {
        let rows: [UserFavoriteRow] = try await Supa.client
            .from("user_favorites")
            .select("venue_id")
            .execute()
            .value
        return rows.map(\.venue_id)
    }

    /// Add `venueId` to the current user's favorites. Idempotent — repeat
    /// inserts fail with a unique-key violation that we swallow.
    static func addFavorite(venueId: String) async throws {
        struct Row: Encodable {
            let user_id: String
            let venue_id: String
        }
        let session = try await Supa.client.auth.session
        let uid = session.user.id.uuidString.lowercased()
        do {
            _ = try await Supa.client
                .from("user_favorites")
                .insert(Row(user_id: uid, venue_id: venueId), returning: .minimal)
                .execute()
        } catch {
            // Duplicate-key on retry isn't an error from the user's POV.
            // Other errors bubble up — let the VM decide how to surface them.
            let msg = "\(error)".lowercased()
            if msg.contains("duplicate") || msg.contains("23505") { return }
            throw error
        }
    }

    /// Remove `venueId` from the current user's favorites.
    static func removeFavorite(venueId: String) async throws {
        _ = try await Supa.client
            .from("user_favorites")
            .delete()
            .eq("venue_id", value: venueId)
            .execute()
    }

    /// Publish (replace) the entire schedule for a venue.
    static func publish(venueId: String, schedule: [DayKey: DaySchedule]) async throws {
        struct ItemPayload: Encodable {
            let name: String
            let normal: Double?
            let deal: Double?
            let label: String?
        }
        struct DayPayload: Encodable {
            let day: String; let start: String; let end: String
            let headline: String; let items: [ItemPayload]
        }
        struct Args: Encodable { let p_venue_id: String; let p_payload: [DayPayload] }

        let payload: [DayPayload] = schedule.compactMap { (dayKey, ds) in
            // Skip incomplete rows rather than write garbage. Admin UI's
            // pickers always populate both fields, but defense-in-depth.
            guard !ds.startTime.isEmpty, !ds.endTime.isEmpty else { return nil }
            return DayPayload(
                day: dbDay(dayKey),
                start: ds.startTime,
                end: ds.endTime,
                headline: ds.headline,
                items: ds.menu.map { ItemPayload(name: $0.item, normal: $0.normal, deal: $0.deal, label: $0.label) }
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

    /// Postgres `time` columns serialize as "HH:mm:ss". We only ever care
    /// about minute precision; trimming keeps the in-memory format aligned
    /// with what the picker writes back.
    private static func trimSeconds(_ s: String) -> String {
        // Expected "HH:mm:ss"; if shorter (some drivers omit seconds), pass through.
        let parts = s.split(separator: ":")
        guard parts.count >= 2 else { return s }
        return "\(parts[0]):\(parts[1])"
    }
}
