import SwiftUI

struct AdminView: View {
    let venue: Venue
    @Bindable var vm: AppViewModel

    @State private var schedule: [DayKey: DaySchedule]
    @State private var selectedDay: DayKey = TODAY
    @State private var hasChanges = false
    @State private var isPublishing = false
    @State private var publishError: String? = nil

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
            HStack(spacing: 12) {
                priceField("Regular", value: item.normal, accent: false) { v in updateItem(item.id) { $0.normal = v } }
                priceField("Deal price", value: item.deal, accent: true) { v in updateItem(item.id) { $0.deal = v } }
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
