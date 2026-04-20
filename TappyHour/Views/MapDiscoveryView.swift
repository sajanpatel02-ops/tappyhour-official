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
                ForEach(vm.filteredVenues) { venue in
                    Annotation("", coordinate: venue.coordinate, anchor: .bottom) {
                        VenuePinView(
                            venue: venue,
                            isSelected: vm.selectedVenueId == venue.id,
                            accent: t.accent,
                            isDark: vm.isDark
                        ) {
                            withAnimation(.spring(duration: 0.25)) {
                                if vm.selectedVenueId == venue.id {
                                    vm.openVenue(venue.id)
                                } else {
                                    vm.selectPin(venue.id)
                                }
                            }
                        }
                    }
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat))
            .onTapGesture { withAnimation { vm.selectPin(nil) } }
            .ignoresSafeArea()

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
                            Text("\(vm.filteredVenues.count) spots · sorted by distance")
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

                    // Role-gated chips — same as ListFeedView
                    if vm.isAdmin || vm.canManageAny {
                        HStack(spacing: 8) {
                            if vm.isAdmin {
                                Button { vm.isAddingVenue = true } label: {
                                    chipLabel(icon: "plus", text: "Add bar",
                                              fg: t.text, bg: t.card, stroke: t.cardBorder)
                                }
                            }
                            if vm.canManageAny {
                                Button {
                                    let firstMine = vm.venues.first(where: { vm.managedVenueIds.contains($0.id) })?.id
                                    vm.adminVenueId = firstMine ?? (vm.isAdmin ? vm.venues.first?.id : nil)
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
                    }

                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(vm.filteredVenues) { venue in
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
    let isSelected: Bool
    let accent: Color
    let isDark: Bool
    let onTap: () -> Void

    private var bg: Color {
        isSelected || venue.isEndingSoon ? accent : (isDark ? Color(hex: "#1f1a2a") : .white)
    }
    private var fg: Color {
        isSelected || venue.isEndingSoon ? Color(hex: "#1a1008") : (isDark ? Color(hex: "#f5ead6") : Color(hex: "#1a1512"))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                if venue.isEndingSoon && !isSelected {
                    Circle().fill(.white).frame(width: 6, height: 6).shadow(color: .white.opacity(0.3), radius: 3)
                }
                Text(venue.price).font(.system(size: 12, weight: .semibold)).monospacedDigit()
                Text("·").font(.system(size: 12)).opacity(0.4)
                Text(venue.shortName).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(isSelected ? 0.25 : 0.18), radius: isSelected ? 10 : 4, y: 2)
            .scaleEffect(isSelected ? 1.12 : 1)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isSelected)

            PinTail(color: bg)
        }
        .onTapGesture(perform: onTap)
    }
}

private struct PinTail: View {
    let color: Color
    var body: some View {
        color.frame(width: 10, height: 6)
            .clipShape(Triangle())
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
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

