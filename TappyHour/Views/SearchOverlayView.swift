import SwiftUI
import MapKit

struct SearchOverlayView: View {
    @Bindable var vm: AppViewModel
    @FocusState private var focused: Bool

    // MapKit autocomplete — same pattern as AddVenueSheet. Finds Chicago bars
    // that aren't in our DB so users can request them.
    @State private var completer = MKLocalSearchCompleter()
    @State private var completerDelegate = CompleterDelegate()
    @State private var mapResults: [MKLocalSearchCompletion] = []

    /// The currently-open external bar preview sheet, if any.
    @State private var previewing: ExternalBar? = nil

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

    /// MapKit results that don't match any DB venue by name — these are the
    /// "not on TappyHour yet" rows. We match loosely on lowercased substring.
    private var externalResults: [MKLocalSearchCompletion] {
        let dbNames = Set(vm.venues.map { $0.name.lowercased() })
        return mapResults.filter { !dbNames.contains($0.title.lowercased()) }
    }

    var body: some View {
        t.bg.ignoresSafeArea()
            .overlay(content)
            .transition(.opacity)
            .sheet(item: $previewing) { bar in
                ExternalVenueSheet(name: bar.name, address: bar.address, vm: vm)
            }
            .onAppear {
                focused = true
                completer.resultTypes = .pointOfInterest
                completer.region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),
                    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
                )
                completerDelegate.onUpdate = { mapResults = $0 }
                completer.delegate = completerDelegate
            }
            .onChange(of: vm.query) { _, new in
                completer.queryFragment = new
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                    if !matchingVenues.isEmpty {
                        sectionHeader("On TappyHour")
                        ForEach(matchingVenues) { v in
                            searchRow(icon: "wineglass", label: v.name,
                                      sub: "\(v.neighborhood) · \(v.cuisine)") {
                                vm.query = v.name
                                vm.isSearchActive = false
                                vm.selectPin(v.id)
                            }
                        }
                    }

                    // MapKit bars that aren't in our DB — requestable.
                    if !vm.query.isEmpty && !externalResults.isEmpty {
                        sectionHeader("Other Chicago bars")
                        ForEach(externalResults, id: \.self) { r in
                            externalRow(r)
                        }
                    }

                    if !vm.query.isEmpty
                        && matchingVenues.isEmpty
                        && externalResults.isEmpty
                        && filteredNeighborhoods.isEmpty {
                        Text("No matches for \"\(vm.query)\"")
                            .font(.system(size: 14))
                            .foregroundStyle(t.muted)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                    }

                    if vm.query.isEmpty {
                        sectionHeader("Recent")
                        ForEach(RECENT_SEARCHES, id: \.self) { r in
                            searchRow(icon: "clock", label: r) {
                                vm.query = r
                                vm.isSearchActive = false
                            }
                        }
                    }

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
    }

    /// Row for a MapKit POI that isn't on TappyHour yet. Shows a "Requested"
    /// pill when the user has already submitted a suggestion for it.
    private func externalRow(_ r: MKLocalSearchCompletion) -> some View {
        let requested = vm.hasRequested(name: r.title, address: r.subtitle)
        return Button {
            previewing = ExternalBar(name: r.title, address: r.subtitle)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14))
                    .foregroundStyle(t.muted)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.title)
                        .font(.system(size: 15))
                        .foregroundStyle(t.text)
                    if !r.subtitle.isEmpty {
                        Text(r.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(t.muted)
                    }
                }
                Spacer()
                if requested {
                    Text("Requested")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(t.muted)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(t.card)
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(t.accent)
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.5)
            .foregroundStyle(t.muted)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
    }

    private func searchRow(icon: String, label: String, sub: String? = nil,
                           showChevron: Bool = false,
                           action: @escaping () -> Void) -> some View {
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

/// Wrapper so we can drive `.sheet(item:)` with a plain name/address tuple.
private struct ExternalBar: Identifiable {
    let id = UUID()
    let name: String
    let address: String
}
