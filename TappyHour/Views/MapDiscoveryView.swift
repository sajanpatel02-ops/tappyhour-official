import SwiftUI
import MapKit

struct MapDiscoveryView: View {
    @Bindable var vm: AppViewModel
    @State private var location = LocationManager.shared
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.888, longitude: -87.645),
            span: MKCoordinateSpan(latitudeDelta: 0.065, longitudeDelta: 0.065)
        )
    )
    /// Track whether we've already snapped the map to the user's first
    /// fix. Prevents re-centering every time lastLocation updates while
    /// they're panning around.
    @State private var didCenterOnUser = false
    // Hide the sheet whenever a higher-level overlay (venue detail, admin,
    // search, login) takes over — otherwise the system sheet would sit on top.
    private var sheetPresented: Binding<Bool> {
        Binding(
            get: {
                vm.openVenueId == nil
                    && vm.adminVenueId == nil
                    && !vm.isSearchActive
                    && !vm.showLogin
                    && !vm.isAddingVenue
            },
            set: { _ in }
        )
    }

    // Detent identifiers (value-based so we can bind a selection)
    private let peekID = PresentationDetent.height(170)
    private let halfID = PresentationDetent.fraction(0.5)
    private let fullID = PresentationDetent.large

    private var detentBinding: Binding<PresentationDetent> {
        Binding(
            get: {
                switch vm.sheetSize {
                case .peek: peekID
                case .half: halfID
                case .full: fullID
                }
            },
            set: { newValue in
                if newValue == peekID { vm.sheetSize = .peek }
                else if newValue == halfID { vm.sheetSize = .half }
                else { vm.sheetSize = .full }
            }
        )
    }

    var body: some View {
        let t = vm.theme
        ZStack(alignment: .bottomTrailing) {
            // Map
            Map(position: $position) {
                ForEach(vm.filteredVenues.filter(vm.matchesDayFilter)) { venue in
                    Annotation("", coordinate: venue.coordinate, anchor: .bottom) {
                        VenuePinView(venue: venue, vm: vm)
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat))
            // Tap empty map area to deselect. The handler guards against
            // the gesture race: pin taps also bubble up here, so it
            // ignores the deselect if a pin was just tapped.
            .onTapGesture { withAnimation { vm.mapBackgroundTapped() } }
            .onMapCameraChange(frequency: .onEnd) { ctx in
                vm.visibleRegion = ctx.region
            }
            .ignoresSafeArea()

            // Day filter chip floats below the search bar so users can
             // switch which day the pins reflect without leaving the map.
            if vm.sheetSize != .full {
                VStack {
                    HStack {
                        DayFilterChip(vm: vm)
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                        Spacer()
                    }
                    .padding(.leading, 16)
                    .padding(.top, 120)
                    Spacer()
                }
                .transition(.opacity)
            }

            // Locate FAB (top-right corner, below search bar). Simple fixed position.
            if vm.sheetSize != .full {
                Button {
                    withAnimation(.spring(duration: 0.4)) {
                        // Prefer the user's actual location; fall back to Chicago.
                        let center = location.lastLocation?.coordinate
                            ?? CLLocationCoordinate2D(latitude: 41.888, longitude: -87.645)
                        position = .region(MKCoordinateRegion(
                            center: center,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        ))
                    }
                    // If permission wasn't granted yet, request it on first tap.
                    location.requestAndStart()
                } label: {
                    Image(systemName: "location")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(t.text)
                        .frame(width: 44, height: 44)
                        .background(t.card)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                }
                .padding(.trailing, 14)
                .padding(.bottom, 200)   // sits above the peek detent
                .transition(.opacity)
            }
        }
        .onChange(of: vm.query) { _, _ in recenterToFilter() }
        .onChange(of: location.lastLocation) { _, new in
            guard !didCenterOnUser, let coord = new?.coordinate else { return }
            didCenterOnUser = true
            withAnimation(.spring(response: 0.4)) {
                position = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
        .onAppear { location.requestAndStart() }
        .sheet(isPresented: sheetPresented) {
            BottomSheetContent(vm: vm)
                .presentationDetents([peekID, halfID, fullID], selection: detentBinding)
                .presentationBackgroundInteraction(.enabled(upThrough: halfID))
                .presentationCornerRadius(22)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(true)
        }
    }

    private func recenterToFilter() {
        let venues = vm.filteredVenues
        guard !venues.isEmpty else { return }

        if venues.count == 1, let v = venues.first {
            withAnimation(.spring(response: 0.4)) {
                position = .region(MKCoordinateRegion(
                    center: v.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                ))
            }
            return
        }

        let lats = venues.map(\.coordinate.latitude)
        let lngs = venues.map(\.coordinate.longitude)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLng = lngs.min()!, maxLng = lngs.max()!
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLng + maxLng) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.02),
            longitudeDelta: max((maxLng - minLng) * 1.5, 0.02)
        )
        withAnimation(.spring(response: 0.4)) {
            position = .region(MKCoordinateRegion(center: center, span: span))
        }
    }

}

// MARK: - Bottom sheet content (hosted inside Apple's native .sheet)
// The drag, scroll interception, velocity physics, and 1:1 finger tracking
// are all handled by the OS — we just provide the content.
private struct BottomSheetContent: View {
    @Bindable var vm: AppViewModel

    private func chipLabel(icon: String, text: String, fg: Color, bg: Color, stroke: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(text).font(.system(size: 11, weight: .semibold)).tracking(0.3)
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(bg)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(stroke, lineWidth: 0.5))
    }

    var body: some View {
        let t = vm.theme
        ZStack {
            t.sheetBg.ignoresSafeArea()

            if let id = vm.selectedVenueId, vm.sheetSize == .peek, let venue = vm.venue(id) {
                VStack(spacing: 0) {
                    VenueCard(venue: venue, vm: vm)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Happy hour nearby")
                                .font(.custom("Georgia", size: 26))
                                .foregroundStyle(t.text)
                                .tracking(-0.4)
                            Text("\(vm.venuesInView.count) spots · sorted by distance")
                                .font(.system(size: 12))
                                .foregroundStyle(t.muted)
                        }
                        Spacer()
                        Button("See all") {
                            withAnimation(.spring(duration: 0.3)) { vm.viewMode = .list }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.accent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    HStack(spacing: 8) {
                        DayFilterChip(vm: vm)
                        if vm.isAdmin {
                            Button { vm.isAddingVenue = true } label: {
                                chipLabel(icon: "plus", text: "Add bar",
                                          fg: t.text, bg: t.card, stroke: t.cardBorder)
                            }
                        }
                        // Manager chip: only for non-admin managers (jumps
                        // straight to their one bar). Admins use the pencil
                        // on each venue detail to edit whichever bar they
                        // want — no need for a "pick first" shortcut.
                        if vm.canManageAny && !vm.isAdmin {
                            Button {
                                vm.adminVenueId = vm.venues.first(where: { vm.managedVenueIds.contains($0.id) })?.id
                            } label: {
                                chipLabel(icon: "gear", text: "Manager",
                                          fg: t.accent, bg: t.accent.opacity(0.12),
                                          stroke: t.accent.opacity(0.33))
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            LoadErrorBanner(vm: vm)
                            ForEach(vm.venuesInView) { venue in
                                VenueCard(venue: venue, vm: vm).padding(.horizontal, 14)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}


// MARK: - Venue Pin
struct VenuePinView: View {
    let venue: Venue
    @Bindable var vm: AppViewModel

    private var isSelected: Bool { vm.selectedVenueId == venue.id }
    private var accent: Color { vm.theme.accent }
    private var bg: Color { accent }
    private var fg: Color { Color(hex: "#1a1008") }

    private func onTap() {
        if isSelected {
            vm.openVenue(venue.id)
        } else {
            vm.selectPin(venue.id)
        }
    }

    var body: some View {
        // Selected pin just scales up and gets a halo — the venue name and
        // details are already shown in the bottom sheet, so a floating label
        // would be redundant. Default and live-soon pins keep their styles.
        let highlighted = venue.isEndingSoon || venue.isStartingSoon
        let baseSize: CGFloat = highlighted ? 18 : 15
        let size: CGFloat = isSelected ? 26 : baseSize
        let ring: CGFloat = isSelected ? 3 : 2
        let shadowColor: Color = (isSelected || highlighted) ? accent.opacity(0.6) : .black.opacity(0.3)
        let shadowRadius: CGFloat = isSelected ? 10 : (highlighted ? 6 : 3)

        return Circle()
            .fill(accent)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white, lineWidth: ring))
            .shadow(color: shadowColor, radius: shadowRadius, y: 1)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
            .onTapGesture(perform: onTap)
    }
}

// MARK: - Location Pulse
struct LocationPulseView: View {
    let accent: Color
    @State private var pulsing = false
    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.25))
                .scaleEffect(pulsing ? 2.4 : 0.6)
                .opacity(pulsing ? 0 : 0.8)
                .animation(.easeOut(duration: 2.5).repeatForever(autoreverses: false), value: pulsing)
            Circle()
                .fill(Color(hex: "#3478f6"))
                .frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        }
        .onAppear { pulsing = true }
    }
}

