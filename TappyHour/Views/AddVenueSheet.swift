import SwiftUI
import MapKit

struct AddVenueSheet: View {
    @Bindable var vm: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var completer = MKLocalSearchCompleter()
    @State private var completerDelegate = CompleterDelegate()
    @State private var results: [MKLocalSearchCompletion] = []
    @State private var isCreating = false
    @State private var errorText: String? = nil

    private var t: AppTheme { vm.theme }

    var body: some View {
        NavigationStack {
            ZStack {
                t.bg.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchField
                    if !results.isEmpty {
                        List(results, id: \.self) { r in
                            Button { Task { await pick(r) } } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.title).font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(t.text)
                                    Text(r.subtitle).font(.system(size: 12)).foregroundStyle(t.muted)
                                }
                            }
                            .listRowBackground(t.card)
                        }
                        .scrollContentBackground(.hidden)
                    } else {
                        emptyState
                    }
                    Spacer()
                }
                if isCreating {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Creating…").tint(.white).foregroundStyle(.white)
                }
            }
            .navigationTitle("Add a bar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorText != nil), actions: {
                Button("OK") { errorText = nil }
            }, message: { Text(errorText ?? "") })
        }
        .onAppear {
            completer.resultTypes = .pointOfInterest
            completer.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.8781, longitude: -87.6298),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
            completerDelegate.onUpdate = { results = $0 }
            completer.delegate = completerDelegate
        }
        .onChange(of: query) { _, new in
            completer.queryFragment = new
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(t.muted)
            TextField("Search for a bar or restaurant", text: $query)
                .font(.system(size: 15))
                .foregroundStyle(t.text)
                .tint(t.accent)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(t.muted)
                }
            }
        }
        .padding(12)
        .background(t.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(16)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "building.2").font(.system(size: 32)).foregroundStyle(t.muted)
            Text("Start typing the bar's name").font(.system(size: 14)).foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity).padding(.top, 60)
    }

    @MainActor
    private func pick(_ completion: MKLocalSearchCompletion) async {
        isCreating = true
        defer { isCreating = false }
        do {
            let req = MKLocalSearch.Request(completion: completion)
            let resp = try await MKLocalSearch(request: req).start()
            guard let item = resp.mapItems.first else {
                errorText = "Couldn't find a location for that result."
                return
            }
            let coord = item.placemark.coordinate
            let neighborhood = item.placemark.subLocality
                ?? item.placemark.locality
                ?? ""
            let nv = VenueRepository.NewVenue(
                name: item.name ?? completion.title,
                shortName: item.name ?? completion.title,
                cuisine: item.pointOfInterestCategory?.displayName ?? "",
                vibe: "",
                neighborhood: neighborhood,
                priceTier: 2,
                address: item.placemark.title ?? "",
                phone: item.phoneNumber ?? "",
                website: item.url?.absoluteString ?? "",
                lat: coord.latitude, lng: coord.longitude
            )
            let newId = try await VenueRepository.createVenue(nv)
            // Build a local Venue from the data we already have — the row is unpublished,
            // so RLS would hide it from a fetch. This lets AdminView open immediately.
            let localVenue = Venue(
                id: newId,
                name: nv.name,
                neighborhood: nv.neighborhood,
                cuisine: nv.cuisine,
                vibe: nv.vibe,
                rating: 0, reviews: 0, distance: 0, walk: 0,
                price: String(repeating: "$", count: max(1, min(4, nv.priceTier))),
                endsIn: 9999,
                coordinate: CLLocationCoordinate2D(latitude: nv.lat, longitude: nv.lng),
                tags: [],
                schedule: [:]
            )
            if !vm.venues.contains(where: { $0.id == newId }) {
                vm.venues.append(localVenue)
            }
            // Open AdminView FIRST so the map's bottom-sheet gate stays closed,
            // then dismiss AddVenueSheet. (Previously we flipped isAddingVenue
            // first, which let the list flash up during the transition.)
            vm.adminVenueId = newId
            vm.isAddingVenue = false
        } catch {
            errorText = "\(error.localizedDescription)"
        }
    }
}

// MKLocalSearchCompleter needs an NSObject delegate
final class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    var onUpdate: ([MKLocalSearchCompletion]) -> Void = { _ in }
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate(completer.results)
    }
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onUpdate([])
    }
}

private extension MKPointOfInterestCategory {
    var displayName: String {
        switch self {
        case .restaurant: "Restaurant"
        case .nightlife: "Nightlife"
        case .cafe: "Cafe"
        case .bakery: "Bakery"
        case .brewery: "Brewery"
        case .winery: "Winery"
        default: "Bar"
        }
    }
}
