import SwiftUI

struct VenueCard: View {
    let venue: Venue
    @Bindable var vm: AppViewModel

    private var t: AppTheme { vm.theme }
    private var today: DaySchedule? { venue.deal(for: TODAY) }
    private var timeWindow: String? {
        guard let d = today else { return nil }
        let s = d.startTime, e = d.endTime
        if !s.isEmpty, !e.isEmpty { return "\(s)–\(e)" }
        return e.isEmpty ? nil : e
    }

    var body: some View {
        Button { vm.openVenue(venue.id) } label: {
            HStack(spacing: 14) {
                venueThumbnail
                VStack(alignment: .leading, spacing: 6) {
                    headerRow
                    metaRow
                }
            }
            .padding(16)
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(t.cardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var venueThumbnail: some View {
        ZStack {
            // Fallback gradient + cuisine label (shown while photo loads or
            // if this venue has no photo URL).
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: vm.isDark
                            ? [Color(hex: "#241d30"), Color(hex: "#1c1728")]
                            : [Color(hex: "#ede6dc"), Color(hex: "#e5ddd0")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            if let s = venue.photoUrl, let url = URL(string: s) {
                CachedImage(url: url, targetWidth: 84) {
                    Color.clear
                } failure: {
                    Text(venue.cuisine)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(t.muted)
                        .multilineTextAlignment(.center)
                        .padding(4)
                }
                .scaledToFill()
            } else {
                Text(venue.cuisine)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(t.muted)
                    .multilineTextAlignment(.center)
                    .padding(4)
            }
        }
        .frame(width: 84, height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(venue.name)
                    .font(.custom("Georgia", size: 22))
                    .foregroundStyle(t.text)
                    .lineLimit(1)
                    .tracking(-0.3)
                HStack(spacing: 6) {
                    Text(venue.neighborhood)
                    dot
                    Text(venue.price)
                }
                .font(.system(size: 12))
                .foregroundStyle(t.muted)
            }
            Spacer(minLength: 4)
        }
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 11))
                    .foregroundStyle(venue.isEndingSoon ? t.accent : t.muted)
                if venue.isEndingSoon, today != nil {
                    Text("Ends in \(venue.endsIn)m")
                        .fontWeight(.semibold)
                        .foregroundStyle(t.accent)
                } else if let window = timeWindow {
                    Text(window)
                        .foregroundStyle(t.muted)
                } else {
                    Text("No happy hour today")
                        .foregroundStyle(t.muted)
                }
            }
            .font(.system(size: 11.5))

            if let mins = vm.walkMinutes(to: venue) {
                dot.foregroundStyle(t.muted.opacity(0.4))
                HStack(spacing: 3) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11))
                    Text("\(mins) min")
                }
                .font(.system(size: 11.5))
                .foregroundStyle(t.muted)
            }
        }
    }

    private var dot: some View { Text("·").foregroundStyle(t.muted.opacity(0.4)) }
}
