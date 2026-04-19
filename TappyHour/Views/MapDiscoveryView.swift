import SwiftUI
import MapKit

struct MapDiscoveryView: View {
    @Bindable var vm: AppViewModel
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 41.888, longitude: -87.645),
            span: MKCoordinateSpan(latitudeDelta: 0.065, longitudeDelta: 0.065)
        )
    )
    @State private var dragOffset: CGFloat = 0

    private let peekH: CGFloat = 170
    private let halfH: CGFloat = 420
    private let fullH: CGFloat = 720

    private var sheetH: CGFloat {
        switch vm.sheetSize {
        case .peek: peekH; case .half: halfH; case .full: fullH
        }
    }

    var body: some View {
        let t = vm.theme
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
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

                // Locate FAB
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.4)) {
                            position = .region(MKCoordinateRegion(
                                center: CLLocationCoordinate2D(latitude: 41.888, longitude: -87.645),
                                span: MKCoordinateSpan(latitudeDelta: 0.065, longitudeDelta: 0.065)
                            ))
                        }
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
                    .padding(.bottom, sheetH + 16)
                    .animation(.spring(response: 0.32), value: sheetH)
                }
                .frame(maxHeight: .infinity, alignment: .bottom)

                // Bottom sheet
                bottomSheet(t: t, geo: geo)
            }
        }
    }

    @ViewBuilder
    private func bottomSheet(t: AppTheme, geo: GeometryProxy) -> some View {
        let currentH = max(peekH, min(fullH, sheetH + dragOffset))
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(vm.isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.15))
                .frame(width: 36, height: 5)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        switch vm.sheetSize {
                        case .peek: vm.sheetSize = .half
                        case .half: vm.sheetSize = .full
                        case .full: vm.sheetSize = .peek
                        }
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { dragOffset = -$0.translation.height }
                        .onEnded { val in
                            let v = val.translation.height
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                if v < -60 {
                                    vm.sheetSize = vm.sheetSize == .peek ? .half : .full
                                } else if v > 60 {
                                    vm.sheetSize = vm.sheetSize == .full ? .half : .peek
                                }
                                dragOffset = 0
                            }
                        }
                )

            if let id = vm.selectedVenueId, vm.sheetSize == .peek, let venue = vm.venue(id) {
                VenueCard(venue: venue, vm: vm)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 20)
                    .transition(.opacity)
            } else {
                sheetListContent(t: t)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentH, alignment: .top)
        .background(
            t.sheetBg
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.18), radius: 20, y: -4)
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: vm.sheetSize)
    }

    @ViewBuilder
    private func sheetListContent(t: AppTheme) -> some View {
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
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(vm.filteredVenues) { venue in
                        VenueCard(venue: venue, vm: vm).padding(.horizontal, 14)
                    }
                }
                .padding(.bottom, 100)
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

