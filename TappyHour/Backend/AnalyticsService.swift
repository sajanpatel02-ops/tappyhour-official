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
            // Plain INSERT (not upsert). Two reasons:
            //  1. `returning: .minimal` skips the post-insert SELECT that
            //     would otherwise fail under our INSERT-only RLS policy.
            //  2. Avoiding ON CONFLICT means no SELECT is needed to check
            //     for conflicts either — Postgres normally requires SELECT
            //     to evaluate ON CONFLICT DO NOTHING.
            // The unique PK on (device_id, day) still enforces "one row
            // per device per day"; subsequent inserts throw a duplicate-
            // key error that we silently ignore.
            _ = try await Supa.client
                .from("daily_pings")
                .insert(row, returning: .minimal)
                .execute()
        } catch {
            // Intentional: analytics is best-effort. Duplicate-key errors
            // on second-and-later launches per day are expected.
        }
    }
}
