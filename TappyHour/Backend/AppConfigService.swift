import Foundation

/// Remote config / kill switch. Read from `app_config` (single row) on
/// launch. Cached in UserDefaults so a Supabase outage can't brick the app
/// — if we can't reach the server, last-known-good wins, falling back to
/// "everything allowed" on first launch.
struct AppConfig: Codable, Equatable {
    var isKilled: Bool
    var killMessage: String
    var allowSuggestions: Bool
    var allowReports: Bool

    static let `default` = AppConfig(
        isKilled: false,
        killMessage: "TappyHour is temporarily unavailable. Please try again soon.",
        allowSuggestions: true,
        allowReports: true
    )

    enum CodingKeys: String, CodingKey {
        case isKilled         = "is_killed"
        case killMessage      = "kill_message"
        case allowSuggestions = "allow_suggestions"
        case allowReports     = "allow_reports"
    }
}

enum AppConfigService {
    private static let cacheKey = "AppConfigService.cache.v1"

    /// Fetch the live config. On failure returns the cached copy if any,
    /// otherwise `AppConfig.default`. Never throws — a config fetch
    /// failure should not block app startup.
    static func fetch() async -> AppConfig {
        do {
            let rows: [AppConfig] = try await Supa.client
                .from("app_config")
                .select("is_killed,kill_message,allow_suggestions,allow_reports")
                .limit(1)
                .execute()
                .value
            if let live = rows.first {
                cache(live)
                return live
            }
        } catch {
            print("AppConfigService.fetch failed:", error)
        }
        return cached() ?? .default
    }

    static func cached() -> AppConfig? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(AppConfig.self, from: data)
    }

    private static func cache(_ config: AppConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
