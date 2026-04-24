import SwiftUI

struct VenueDetailView: View {
    let venue: Venue
    @Bindable var vm: AppViewModel
    @State private var selectedDay: DayKey = TODAY
    @State private var presentedURL: PresentedURL? = nil
    @State private var reportSubmitting = false
    @State private var reportError: String? = nil
    @State private var reportJustSubmitted = false
    @Environment(\.openURL) private var openURL

    private var t: AppTheme { vm.theme }
    private var isSaved: Bool { vm.savedIds.contains(venue.id) }
    private var dayData: DaySchedule? { venue.deal(for: selectedDay) }
    private var activeDays: [DayKey] { venue.activeDays }

    var body: some View {
        ZStack(alignment: .top) {
            t.bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                    detailContent
                }
                .padding(.bottom, 60)
            }
            .ignoresSafeArea(edges: .top)

            // Back + save buttons overlay
            HStack {
                Button { vm.openVenueId = nil } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(t.text)
                        .frame(width: 40, height: 40)
                        .background(t.card.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }
                Spacer()
                HStack(spacing: 8) {
                    // Admin/manager shortcut: edit this specific bar's schedule.
                    // Avoids the Manager-chip-only-opens-first-bar footgun.
                    if vm.isAdmin || vm.managedVenueIds.contains(venue.id) {
                        Button {
                            vm.openVenueId = nil
                            vm.adminVenueId = venue.id
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(t.accent)
                                .frame(width: 40, height: 40)
                                .background(t.card.opacity(0.9))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                        }
                    }
                    Button {
                        // Share action
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(t.text)
                            .frame(width: 40, height: 40)
                            .background(t.card.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    }
                    Button { vm.toggleSave(venue.id) } label: {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(isSaved ? t.accent : t.text)
                            .frame(width: 40, height: 40)
                            .background(t.card.opacity(0.9))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 56)
        }
        .ignoresSafeArea(edges: .top)
        .transition(.move(edge: .trailing))
        .sheet(item: $presentedURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        ZStack {
            // Fallback gradient (shown while photo loads or if there's no URL)
            LinearGradient(
                colors: vm.isDark
                    ? [Color(hex: "#2a1f3a"), Color(hex: "#130d1c")]
                    : [Color(hex: "#e8ddc9"), Color(hex: "#d9caa8")],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [t.accent.opacity(0.18), .clear],
                center: UnitPoint(x: 0.3, y: 0.2),
                startRadius: 0, endRadius: 200
            )

            if let urlString = venue.photoUrl, let url = URL(string: urlString) {
                // GeometryReader + fixed-size frame prevents a wide source
                // image (e.g. 1200×600) from propagating its intrinsic
                // width up through ZStack → ScrollView and blowing out
                // the whole page layout.
                GeometryReader { geo in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                               .scaledToFill()
                               .frame(width: geo.size.width, height: geo.size.height)
                               .clipped()
                        case .empty:
                            ProgressView().tint(t.muted)
                        case .failure:
                            Text("[ \(venue.cuisine) — interior photo ]")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(t.muted)
                                .kerning(1)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                // Dark gradient at top so back/share/heart icons stay readable
                LinearGradient(
                    colors: [.black.opacity(0.35), .clear],
                    startPoint: .top, endPoint: .center
                )
            } else {
                // No URL: show the subtle texture + placeholder label
                Canvas { ctx, size in
                    for row in stride(from: 0, to: size.height, by: 20) {
                        for col in stride(from: 0, to: size.width, by: 20) {
                            let rect = CGRect(x: col, y: row, width: 10, height: 10)
                            ctx.opacity = 0.03
                            ctx.fill(Path(rect), with: .color(vm.isDark ? .white : .black))
                        }
                    }
                }
                Text("[ \(venue.cuisine) — interior photo ]")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(t.muted)
                    .kerning(1)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .clipped()
    }

    // MARK: - Detail Content
    private var detailContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 0).frame(maxWidth: .infinity)
            // Venue name + meta
            VStack(alignment: .leading, spacing: 6) {
                Text(venue.name)
                    .font(.custom("Georgia", size: 34))
                    .foregroundStyle(t.text)
                    .tracking(-0.5)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#f2a03d"))
                        Text(String(format: "%.1f", venue.rating))
                    }
                    Text("(\(venue.reviews))")
                    Text("·")
                    Text(venue.neighborhood)
                    Text("·")
                    Text(venue.price)
                }
                .font(.system(size: 14))
                .foregroundStyle(t.muted)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            divider

            // Last-updated stamp + "View menu online" link sit right above the
            // weekday picker so users can gauge freshness and jump to the source.
            if venue.scheduleUpdatedAt != nil || venue.dealsSourceUrl != nil {
                HStack(spacing: 10) {
                    if let updated = venue.scheduleUpdatedAt {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10))
                            Text("Updated \(relativeUpdated(updated))")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(t.muted)
                    }
                    Spacer()
                    if let src = venue.dealsSourceUrl,
                       let url = URL(string: src) {
                        Button {
                            presentedURL = PresentedURL(url: url)
                        } label: {
                            HStack(spacing: 4) {
                                Text("View menu online")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(t.accent)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
            }

            // Weekday picker
            weekdayPicker
                .padding(.vertical, 16)

            divider

            // Deal for selected day
            if let deal = dayData {
                dealSection(deal: deal)
            } else {
                noHappyHourSection
            }

            divider

            // Action buttons
            actionButtons
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

            divider

            // About
            aboutSection
                .padding(.horizontal, 20)
                .padding(.vertical, 20)

            reportOutdatedRow
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
    }

    // MARK: - Report outdated

    @ViewBuilder
    private var reportOutdatedRow: some View {
        let reported = reportJustSubmitted || vm.hasReported(venue.id)
        if reported {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text("Thanks — we'll review this venue")
            }
            .font(.system(size: 13))
            .foregroundStyle(t.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        } else {
            Button {
                Task { await submitOutdatedReport() }
            } label: {
                HStack(spacing: 6) {
                    if reportSubmitting {
                        ProgressView().tint(t.muted).scaleEffect(0.8)
                    } else {
                        Image(systemName: "exclamationmark.bubble")
                    }
                    Text(reportSubmitting ? "Sending…" : "Deals look outdated? Let us know")
                }
                .font(.system(size: 13))
                .foregroundStyle(t.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(t.cardBorder, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .disabled(reportSubmitting)
            if let reportError {
                Text(reportError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
    }

    @MainActor
    private func submitOutdatedReport() async {
        reportError = nil
        reportSubmitting = true
        defer { reportSubmitting = false }
        do {
            try await vm.reportOutdated(venueId: venue.id)
            reportJustSubmitted = true
        } catch {
            reportError = error.localizedDescription
        }
    }

    // MARK: - Weekday Picker
    private var weekdayPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DayKey.allCases) { day in
                    let hasDeals = activeDays.contains(day)
                    let isSelected = selectedDay == day
                    let isToday = day == TODAY
                    Button { if hasDeals { selectedDay = day } } label: {
                        VStack(spacing: 5) {
                            ZStack(alignment: .bottom) {
                                Text(day.shortName)
                                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                    .foregroundStyle(
                                        isSelected ? (vm.isDark ? Color(hex: "#0b0910") : .white)
                                            : (hasDeals ? t.text : t.muted.opacity(0.5))
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        isSelected ? t.accent : .clear
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                if isToday && !isSelected {
                                    Circle()
                                        .fill(t.accent)
                                        .frame(width: 4, height: 4)
                                        .offset(y: 4)
                                }
                            }

                            if !hasDeals {
                                Text("—")
                                    .font(.system(size: 10))
                                    .foregroundStyle(t.muted.opacity(0.4))
                            } else {
                                Text("·")
                                    .font(.system(size: 10))
                                    .foregroundStyle(t.accent.opacity(0.6))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasDeals)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Deal Section
    private func dealSection(deal: DaySchedule) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Countdown / hours
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deal.hours)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(t.text)
                    Text(deal.headline)
                        .font(.system(size: 13))
                        .foregroundStyle(t.muted)
                }
                Spacer()
                if venue.isEndingSoon && selectedDay == TODAY {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Ends in")
                            .font(.system(size: 11))
                            .foregroundStyle(t.accent)
                        Text("\(venue.endsIn)m")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(t.accent)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Menu items
            VStack(spacing: 0) {
                HStack {
                    Text("Happy Hour Menu")
                        .font(.system(size: 11, weight: .semibold))
                        .kerning(1.5)
                        .foregroundStyle(t.muted)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                ForEach(deal.menu) { item in
                    menuItemRow(item)
                }
            }
            .padding(.bottom, 16)

        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()
    private func relativeUpdated(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func menuItemRow(_ item: HappyHourItem) -> some View {
        HStack {
            Text(item.item)
                .font(.system(size: 15))
                .foregroundStyle(t.text)
            Spacer()
            // Three display modes:
            //   1. Label present → show just the label ("50% off", "$6-$12")
            //   2. Numeric normal+deal → strikethrough normal + accent deal
            //   3. Neither → blank (shouldn't happen; defensive)
            if let label = item.label, !label.isEmpty {
                Text(label)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(t.accent)
            } else if let normal = item.normal, let deal = item.deal,
                      normal > 0, deal > 0 {
                HStack(spacing: 8) {
                    Text("$\(Int(normal))")
                        .font(.system(size: 14))
                        .foregroundStyle(t.muted)
                        .strikethrough(true, color: t.muted)
                    Text("$\(Int(deal))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(t.accent)
                        .monospacedDigit()
                }
            } else if let single = [item.deal, item.normal].compactMap({ $0 }).first(where: { $0 > 0 }) {
                // Only one side populated — show just that price.
                Text("$\(Int(single))")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(t.accent)
                    .monospacedDigit()
            } else {
                // No label and no real prices — direct users to the source.
                Text("See menu")
                    .font(.system(size: 12))
                    .foregroundStyle(t.muted)
                    .italic()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            t.separator.frame(height: 0.5).padding(.horizontal, 20)
        }
    }

    private var noHappyHourSection: some View {
        VStack(spacing: 8) {
            Text("No happy hour on \(selectedDay.displayName)")
                .font(.system(size: 15))
                .foregroundStyle(t.muted)
            let alts = venue.activeDays.filter { $0 != selectedDay }.prefix(3)
            if !alts.isEmpty {
                HStack(spacing: 6) {
                    Text("Try:")
                        .font(.system(size: 13))
                        .foregroundStyle(t.muted)
                    ForEach(Array(alts)) { day in
                        Button(day.shortName) { selectedDay = day }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(t.accent)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    // MARK: - Actions
    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button {
                if let url = URL(string: "maps://?daddr=\(venue.coordinate.latitude),\(venue.coordinate.longitude)") {
                    openURL(url)
                }
            } label: {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(vm.isDark ? Color(hex: "#0b0910") : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(t.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Button {
                // Call action
            } label: {
                Label("Call", systemImage: "phone")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(t.text)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(t.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(t.cardBorder, lineWidth: 0.5)
                    )
            }
        }
    }

    // MARK: - About
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.5)
                .foregroundStyle(t.muted)
                .textCase(.uppercase)
            VStack(spacing: 10) {
                aboutRow(icon: "fork.knife", label: venue.cuisine)
                aboutRow(icon: "face.smiling", label: venue.vibe)
                aboutRow(icon: "mappin", label: venue.neighborhood)
                aboutRow(icon: "figure.walk", label: "\(venue.walk) min walk · \(String(format: "%.1f", venue.distance)) mi")
                aboutRow(icon: "calendar", label: "Happy hour: \(venue.summarizeDays())")
                aboutRow(icon: "tag", label: venue.tags.joined(separator: ", "))
            }
        }
    }

    private func aboutRow(icon: String, label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(t.muted)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(t.text)
            Spacer()
        }
    }

    private var divider: some View {
        t.separator.frame(height: 0.5)
    }
}
