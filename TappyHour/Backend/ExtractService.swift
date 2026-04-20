import Foundation
import Supabase

/// Calls the `extract-happy-hour` Edge Function and maps its response
/// into our app's DaySchedule model.
enum ExtractService {
    struct ExtractedItem: Decodable {
        let name: String
        let normal: Double
        let deal: Double
    }

    struct ExtractedDay: Decodable {
        let day: String        // "mon".."sun"
        let start: String      // "HH:MM"
        let end: String
        let headline: String
        let items: [ExtractedItem]
    }

    struct ExtractionResult: Decodable {
        let found: Bool
        let confidence: String?
        let notes: String?
        let days: [ExtractedDay]?
        let error: String?
    }

    struct ExtractError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    /// Invokes the edge function and returns a populated [DayKey: DaySchedule]
    /// plus the confidence + notes so the UI can surface them to the admin.
    static func extract(url: String) async throws -> (schedule: [DayKey: DaySchedule], notes: String, confidence: String) {
        struct Body: Encodable { let url: String }

        let result: ExtractionResult = try await Supa.client.functions
            .invoke("extract-happy-hour", options: .init(body: Body(url: url)))

        if let err = result.error {
            throw ExtractError(message: err)
        }
        guard result.found else {
            throw ExtractError(message: result.notes ?? "No happy hour found on that page.")
        }

        var out: [DayKey: DaySchedule] = [:]
        for d in result.days ?? [] {
            guard let key = mapDay(d.day) else { continue }
            out[key] = DaySchedule(
                hours: formatHours(start: d.start, end: d.end),
                headline: trimHeadline(d.headline),
                menu: d.items.map {
                    HappyHourItem(item: trimItemName($0.name), normal: $0.normal, deal: $0.deal)
                }
            )
        }
        return (out, result.notes ?? "", result.confidence ?? "medium")
    }

    // MARK: - helpers

    private static func mapDay(_ s: String) -> DayKey? {
        switch s.lowercased() {
        case "mon": .mo; case "tue": .tu; case "wed": .we; case "thu": .th
        case "fri": .fr; case "sat": .sa; case "sun": .su
        default: nil
        }
    }

    /// Trim long LLM-dumped item names. Cuts parenthetical brand lists first,
    /// then hard-caps at 28 chars so menu rows stay on one line.
    private static func trimItemName(_ s: String) -> String {
        var out = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Drop "(...)" suffix like "Bottles (Miller Lite, Bud Light)"
        if let paren = out.firstIndex(of: "(") {
            out = String(out[..<paren]).trimmingCharacters(in: .whitespaces)
        }
        if out.count > 28 {
            out = String(out.prefix(27)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return out
    }

    /// Trim long LLM-dumped headlines down to ~50 chars for readable display.
    private static func trimHeadline(_ s: String) -> String {
        let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 60 { return trimmed }
        // Cut at first ";" or "." or " · " so we don't slice mid-word
        for sep in [";", ".", " · ", ","] {
            if let range = trimmed.range(of: sep), range.lowerBound < trimmed.index(trimmed.startIndex, offsetBy: 60) {
                return String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        return String(trimmed.prefix(57)) + "…"
    }

    /// "15:00" + "18:00" → "3:00 – 6:00 PM"
    private static func formatHours(start: String, end: String) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        let out = DateFormatter(); out.dateFormat = "h:mm"
        let outAmPm = DateFormatter(); outAmPm.dateFormat = "h:mm a"
        guard let s = f.date(from: start), let e = f.date(from: end) else {
            return "\(start) – \(end)"
        }
        return "\(out.string(from: s)) – \(outAmPm.string(from: e))"
    }
}
