import Foundation
import UIKit

/// Minimal DAU tracker. Sends one row per device per day to `daily_pings`
/// in Supabase. The table's composite primary key on (device_id, day)
/// makes repeat upserts within a day a no-op at the DB layer, so we don't
/// need to debounce client-side beyond that.
///
/// Privacy: we use `identifierForVendor` (IDFV) — Apple-provided, first
/// party, no ATT prompt required. Reflected in App Store Connect's App
/// Privacy as: Identifiers → Device ID → Analytics, not linked, not for
/// tracking.
enum AnalyticsService {
    private static let deviceId: String = {
        UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    }()

    /// Fire-and-forget; never throws and never blocks the caller. Errors
    /// (offline, Supabase hiccup) are swallowed — a missed ping is a tiny
    /// DAU undercount, not a user-visible problem.
    @MainActor
    static func recordAppOpen() {
        Task.detached(priority: .background) {
            await sendPing()
        }
    }

    private static func sendPing() async {
        struct Row: Encodable {
            let device_id: String
            let user_id: String?
        }

        // Try to associate with the signed-in user, but don't wait around
        // if auth is slow — we'd rather log an anonymous ping than miss it.
        var userId: String? = nil
        if let session = try? await Supa.client.auth.session {
            userId = session.user.id.uuidString.lowercased()
        }

        let row = Row(device_id: deviceId, user_id: userId)

        do {
            // `returning: .minimal` is critical — PostgREST defaults to
            // Prefer: return=representation, which reads the row back after
            // insert. Our RLS allows INSERT but not SELECT, so the read-back
            // would fail with 403. Minimal means "don't read it back."
            _ = try await Supa.client
                .from("daily_pings")
                .upsert(row,
                        onConflict: "device_id,day",
                        returning: .minimal,
                        ignoreDuplicates: true)
                .execute()
        } catch {
            // Intentional: analytics is best-effort.
        }
    }
}
