import SwiftUI

struct SearchOverlayView: View {
    @Bindable var vm: AppViewModel
    @FocusState private var focused: Bool

    private var t: AppTheme { vm.theme }
    private var filteredNeighborhoods: [String] {
        if vm.query.isEmpty { return NEIGHBORHOODS }
        return NEIGHBORHOODS.filter { $0.lowercased().contains(vm.query.lowercased()) }
    }

    private var matchingVenues: [Venue] {
        guard !vm.query.isEmpty else { return [] }
        let q = vm.query.lowercased()
        return vm.venues.filter {
            $0.name.lowercased().contains(q) ||
            $0.neighborhood.lowercased().contains(q) ||
            $0.cuisine.lowercased().contains(q) ||
            $0.tags.contains(where: { $0.lowercased().contains(q) })
        }
    }

    var body: some View {
        t.bg.ignoresSafeArea()
            .overlay(content)
            .transition(.opacity)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar row
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundStyle(t.muted)
                    TextField("Neighborhood, bar, or deal", text: $vm.query)
                        .font(.system(size: 14))
                        .foregroundStyle(t.text)
                        .tint(t.accent)
                        .focused($focused)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(t.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(t.cardBorder, lineWidth: 0.5)
                )

                Button("Cancel") {
                    vm.query = ""
                    vm.isSearchActive = false
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(t.accent)
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .padding(.bottom, 20)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Venue matches (shown as you type)
                    if !matchingVenues.isEmpty {
                        sectionHeader("Venues")
                        ForEach(matchingVenues) { v in
                            searchRow(icon: "wineglass", label: v.name, sub: "\(v.neighborhood) · \(v.cuisine)") {
                                // Commit the venue name as the query so the map/list filter to this pin,
                                // but don't open the detail — user wants to see it in context first.
                                vm.query = v.name
                                vm.isSearchActive = false
                                vm.selectPin(v.id)
                            }
                        }
                    } else if !vm.query.isEmpty && filteredNeighborhoods.isEmpty {
                        Text("No matches for \"\(vm.query)\"")
                            .font(.system(size: 14))
                            .foregroundStyle(t.muted)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }

                    // Recents
                    if vm.query.isEmpty {
                        sectionHeader("Recent")
                        ForEach(RECENT_SEARCHES, id: \.self) { r in
                            searchRow(icon: "clock", label: r) {
                                vm.query = r
                                vm.isSearchActive = false
                            }
                        }
                    }

                    // Neighborhoods
                    if !filteredNeighborhoods.isEmpty {
                        sectionHeader("Neighborhoods in Chicago")
                            .padding(.top, 12)
                        ForEach(filteredNeighborhoods, id: \.self) { n in
                            searchRow(icon: "mappin", label: n, showChevron: true) {
                                vm.query = n
                                vm.isSearchActive = false
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { focused = true }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.5)
            .foregroundStyle(t.muted)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
    }

    private func searchRow(icon: String, label: String, sub: String? = nil, showChevron: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(t.muted)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 15))
                        .foregroundStyle(t.text)
                    if let sub, !sub.isEmpty {
                        Text(sub)
                            .font(.system(size: 12))
                            .foregroundStyle(t.muted)
                    }
                }
                Spacer()
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(t.muted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(alignment: .bottom) {
                t.separator.frame(height: 0.5).padding(.leading, 52)
            }
        }
        .buttonStyle(.plain)
    }
}
