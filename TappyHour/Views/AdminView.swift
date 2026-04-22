import SwiftUI

struct AdminView: View {
    let venue: Venue
    @Bindable var vm: AppViewModel

    @State private var schedule: [DayKey: DaySchedule]
    @State private var selectedDay: DayKey = TODAY
    @State private var hasChanges = false
    @State private var isPublishing = false
    @State private var publishError: String? = nil

    @State private var showingImportSheet = false
    @State private var importURL = ""
    @State private var isImporting = false
    @State private var importError: String? = nil
    @State private var importNotes: String? = nil

    private var t: AppTheme { vm.theme }
    private var dayData: DaySchedule? { schedule[selectedDay] }

    init(venue: Venue, vm: AppViewModel) {
        self.venue = venue
        self._vm = Bindable(vm)
        self._schedule = State(initialValue: venue.schedule)
    }

    var body: some View {
        ZStack(alignment: .top) {
            t.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                weekdayStrip.padding(.vertical, 12)
                t.separator.frame(height: 0.5)
                ScrollView {
                    VStack(spacing: 16) {
                        importBanner
                        dayToggle
                        if dayData != nil {
                            hoursAndHeadline
                            menuEditor
                            bulkActions
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 120)
                }
            }
            VStack { Spacer(); publishBar }.ignoresSafeArea(edges: .bottom)
        }
        .transition(.move(edge: .bottom))
        .sheet(isPresented: $showingImportSheet) { importSheet }
    }

    // MARK: - Import from URL

    private var importBanner: some View {
        Button {
            importURL = venue.schedule.isEmpty ? "" : importURL
            showingImportSheet = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(t.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import from website")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(t.text)
                    Text("Auto-fill the schedule from a URL, then review")
                        .font(.system(size: 11))
                        .foregroundStyle(t.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(t.muted)
            }
            .padding(14)
            .background(t.card)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(t.accent.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var importSheet: some View {
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    Text("Paste the bar's website or happy hour page. We'll extract the schedule and you can review it before saving.")
                        .font(.system(size: 14))
                        .foregroundStyle(t.muted)

                    TextField("https://example.com/happy-hour", text: $importURL)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .padding(12)
                        .background(t.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let err = importError {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await runImport() }
                    } label: {
                        HStack {
                            if isImporting { ProgressView().tint(vm.isDark ? .black : .white) }
                            Text(isImporting ? "Extracting…" : "Import")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(vm.isDark ? Color(hex: "#1a1008") : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(t.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting || importURL.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity((isImporting || importURL.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.5 : 1)

                    // Even when extraction fails, let the manager save the URL
                    // so the detail view shows a "View menu online" link.
                    Button {
                        Task { await saveLinkOnly() }
                    } label: {
                        Text("Save link only (no schedule)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(t.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(t.accent.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting || importURL.trimmingCharacters(in: .whitespaces).isEmpty)
                    .opacity((isImporting || importURL.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.5 : 1)

                    Spacer()
                }
                .padding(20)
                .padding(.top, 10)
            }
            .navigationTitle("Import schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingImportSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @MainActor
    private func runImport() async {
        importError = nil
        isImporting = true
        defer { isImporting = false }
        do {
            let (parsed, notes, _) = try await ExtractService.extract(
                url: importURL.trimmingCharacters(in: .whitespaces)
            )
            guard !parsed.isEmpty else {
                importError = "Couldn't find a happy hour schedule on that page."
                return
            }
            schedule = parsed
            hasChanges = true
            importNotes = notes
            showingImportSheet = false
            // Persist the source URL so the venue detail can link back to it.
            // Fire-and-forget: failure here shouldn't block the import.
            let src = importURL.trimmingCharacters(in: .whitespaces)
            Task { try? await VenueRepository.setDealsSourceUrl(venueId: venue.id, url: src) }
            if let first = DayKey.allCases.first(where: { parsed[$0] != nil }) {
                selectedDay = first
            }
        } catch {
            importError = error.localizedDescription
        }
    }

    /// Persist just the URL as the venue's menu link, without trying to extract
    /// a schedule. For sites we can't parse (JS-rendered, image-only, blocked).
    @MainActor
    private func saveLinkOnly() async {
        let src = importURL.trimmingCharacters(in: .whitespaces)
        guard !src.isEmpty else { return }
        importError = nil
        isImporting = true
        defer { isImporting = false }
        do {
            try await VenueRepository.setDealsSourceUrl(venueId: venue.id, url: src)
            showingImportSheet = false
        } catch {
            importError = "Couldn't save link: \(error.localizedDescription)"
        }
    }

    // MARK: - Nav Bar
    private var navBar: some View {
        HStack {
            Button { vm.adminVenueId = nil } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(t.text)
                    .frame(width: 36, height: 36)
                    .background(t.card)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text(venue.name).font(.custom("Georgia", size: 18)).foregroundStyle(t.text)
                Text("Manager Mode").font(.system(size: 11, weight: .semibold)).foregroundStyle(t.accent).kerning(0.5)
            }
            Spacer()
            Button("Preview") {}
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(t.accent)
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    // MARK: - Weekday Strip
    private var weekdayStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DayKey.allCases) { day in
                    let hasDeal = schedule[day] != nil
                    let isSelected = selectedDay == day
                    Button { selectedDay = day } label: {
                        VStack(spacing: 4) {
                            Text(day.shortName)
                                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? (vm.isDark ? Color(hex: "#0b0910") : .white) : (hasDeal ? t.text : t.muted.opacity(0.4)))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(isSelected ? t.accent : .clear)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                            Circle().fill(hasDeal ? t.accent : t.muted.opacity(0.2)).frame(width: 5, height: 5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Day Toggle
    private var dayToggle: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Happy hour on \(selectedDay.displayName)")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(t.text)
                Text(dayData != nil ? "Active" : "Off")
                    .font(.system(size: 13)).foregroundStyle(dayData != nil ? t.accent : t.muted)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { dayData != nil },
                set: { on in
                    withAnimation(.spring(duration: 0.2)) {
                        if on {
                            schedule[selectedDay] = DaySchedule(hours: "4:00 – 6:00 PM", headline: "Happy hour specials", menu: [])
                        } else {
                            schedule.removeValue(forKey: selectedDay)
                        }
                        hasChanges = true
                    }
                }
            )).tint(t.accent)
        }
        .padding(16)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Hours & Headline
    @ViewBuilder
    private var hoursAndHeadline: some View {
        if let deal = dayData {
            VStack(alignment: .leading, spacing: 16) {
                sectionLabel("Hours & Headline")
                adminTextField(label: "Hours", text: deal.hours) { newVal in
                    schedule[selectedDay]?.hours = newVal; hasChanges = true
                }
                adminTextField(label: "Headline", text: deal.headline) { newVal in
                    schedule[selectedDay]?.headline = newVal; hasChanges = true
                }
            }
            .padding(16)
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func adminTextField(label: String, text: String, onChange: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundStyle(t.muted)
            TextField(label, text: Binding(get: { text }, set: { onChange($0) }))
                .font(.system(size: 15)).foregroundStyle(t.text).tint(t.accent)
                .padding(12)
                .background(vm.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Menu Editor
    @ViewBuilder
    private var menuEditor: some View {
        if let deal = dayData {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    sectionLabel("Drinks (\(deal.menu.count))")
                    Spacer()
                    Button {
                        schedule[selectedDay]?.menu.append(HappyHourItem(item: "New Drink", normal: 12, deal: 6))
                        hasChanges = true
                    } label: {
                        Label("Add", systemImage: "plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(t.accent)
                    }
                }
                ForEach(deal.menu) { item in menuItemEditor(item) }
            }
            .padding(16)
            .background(t.card)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func menuItemEditor(_ item: HappyHourItem) -> some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Item name", text: Binding(
                    get: { item.item },
                    set: { v in updateItem(item.id) { $0.item = v } }
                ))
                .font(.system(size: 14, weight: .medium)).foregroundStyle(t.text).tint(t.accent)
                Spacer()
                Button {
                    schedule[selectedDay]?.menu.removeAll { $0.id == item.id }
                    hasChanges = true
                } label: {
                    Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(.red.opacity(0.7))
                }
            }
            // Custom label (for "50% off", "$6-$12" type deals). When filled,
            // the numeric prices are ignored by the detail view.
            TextField("Custom deal label (e.g. \"50% off\", \"$6-$12\")",
                      text: Binding(
                        get: { item.label ?? "" },
                        set: { v in updateItem(item.id) { $0.label = v.isEmpty ? nil : v } }
                      ))
                .font(.system(size: 13))
                .foregroundStyle(t.text)
                .tint(t.accent)
                .padding(10)
                .background(vm.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Hide price fields when a label is in use — avoids confusion.
            if (item.label ?? "").isEmpty {
                HStack(spacing: 12) {
                    priceField("Regular", value: item.normal ?? 0, accent: false) { v in updateItem(item.id) { $0.normal = v } }
                    priceField("Deal price", value: item.deal ?? 0, accent: true) { v in updateItem(item.id) { $0.deal = v } }
                }
            }
        }
        .padding(12)
        .background(vm.isDark ? Color.white.opacity(0.04) : Color.black.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func priceField(_ label: String, value: Double, accent: Bool, onChange: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 11)).foregroundStyle(t.muted)
            TextField("$", value: Binding(get: { value }, set: { onChange($0) }),
                      format: .currency(code: "USD").precision(.fractionLength(0)))
                .font(.system(size: 14, weight: accent ? .semibold : .regular))
                .foregroundStyle(accent ? t.accent : t.muted)
                .tint(t.accent)
                .padding(10)
                .background(accent ? t.accent.opacity(0.1) : (vm.isDark ? Color.white.opacity(0.05) : Color.black.opacity(0.04)))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func updateItem(_ id: UUID, _ update: (inout HappyHourItem) -> Void) {
        guard let idx = schedule[selectedDay]?.menu.firstIndex(where: { $0.id == id }) else { return }
        update(&schedule[selectedDay]!.menu[idx])
        hasChanges = true
    }

    // MARK: - Bulk Actions
    @ViewBuilder
    private var bulkActions: some View {
        if let current = dayData {
            HStack(spacing: 10) {
                Button {
                    for day in DayKey.allCases where day != selectedDay { schedule[day] = current }
                    hasChanges = true
                } label: {
                    Text("Copy to all days")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(t.text)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(t.card).clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(t.cardBorder, lineWidth: 0.5))
                }
                Button {
                    schedule.removeValue(forKey: selectedDay); hasChanges = true
                } label: {
                    Text("Pause day")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.red.opacity(0.8))
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.red.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Publish Bar
    private var publishBar: some View {
        HStack(spacing: 12) {
            Button { vm.adminVenueId = nil } label: {
                Text("Discard")
                    .font(.system(size: 15, weight: .medium)).foregroundStyle(t.muted)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(t.card).clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(t.cardBorder, lineWidth: 0.5))
            }
            Button {
                Task {
                    isPublishing = true; publishError = nil
                    let ok = await vm.publishAdminSchedule(venue.id, schedule)
                    isPublishing = false
                    if !ok { publishError = vm.loadError ?? "Publish failed" }
                }
            } label: {
                HStack(spacing: 8) {
                    if isPublishing { ProgressView().tint(vm.isDark ? Color(hex: "#0b0910") : .white) }
                    Text(isPublishing ? "Publishing…" : "Publish")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(vm.isDark ? Color(hex: "#0b0910") : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background((hasChanges && !isPublishing) ? t.accent : t.muted)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!hasChanges || isPublishing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 34)
        .background(t.bg)
        .overlay(alignment: .top) {
            if let publishError {
                Text(publishError)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
                    .offset(y: -40)
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold)).kerning(1.5)
            .foregroundStyle(t.muted)
    }
}