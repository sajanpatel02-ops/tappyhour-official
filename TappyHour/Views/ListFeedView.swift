import SwiftUI

struct ListFeedView: View {
    @Bindable var vm: AppViewModel

    private var t: AppTheme { vm.theme }
    private var venues: [Venue] {
        if vm.viewMode == .feed {
            // Feed mode: "ending soon" — sort by time remaining, not distance.
            return vm.filteredVenues.sorted { $0.endsIn < $1.endsIn }
        }
        // List mode mirrors the map: only venues in the current map region,
        // sorted nearest-first from the user's location.
        return vm.venuesInView
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if vm.viewMode == .feed {
                        feedHeader
                    } else {
                        listHeader
                        if vm.viewMode == .list { dayFilterRow }
                    }
                    LoadErrorBanner(vm: vm)
                    ForEach(venues) { venue in
                        VenueCard(venue: venue, vm: vm)
                            .padding(.horizontal, 16)
                            .id(venue.id)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 120)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $vm.listScrollTargetId, anchor: .top)
        }
        .animation(.spring(duration: 0.3), value: vm.loadError)
    }

    private var dayFilterRow: some View {
        HStack {
            DayFilterChip(vm: vm)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
    }

    private var listHeaderSuffix: String {
        switch vm.listDayFilter {
        case .today:      "spots with happy hour today"
        case .all:        "spots with happy hour"
        case .day(let d): "spots with happy hour on \(d.displayName)"
        }
    }

    private var listHeader: some View {
        HStack {
            (Text("\(venues.count) ")
                .fontWeight(.semibold)
                .foregroundStyle(t.text)
            + Text(listHeaderSuffix)
                .foregroundStyle(t.muted))
                .font(.system(size: 12))
            Spacer()
            if vm.isAdmin { addChip }
            // Manager chip: non-admin venue managers only. Admins tap any bar
            // and use the pencil button on its detail view.
            if vm.canManageAny && !vm.isAdmin { managerChip }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private var feedHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ending soon")
                    .font(.custom("Georgia", size: 32))
                    .foregroundStyle(t.text)
                    .tracking(-0.5)
                Text("Happy hours wrapping in the next 2 hours")
                    .font(.system(size: 13))
                    .foregroundStyle(t.muted)
            }
            Spacer()
            if vm.isAdmin { addChip }
            // Manager chip: non-admin venue managers only. Admins tap any bar
            // and use the pencil button on its detail view.
            if vm.canManageAny && !vm.isAdmin { managerChip }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var addChip: some View {
        Button { vm.isAddingVenue = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("Add bar")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.3)
            }
            .foregroundStyle(t.text)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(t.card)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(t.cardBorder, lineWidth: 0.5))
        }
    }

    private var managerChip: some View {
        Button {
            // Pick the first venue this user can manage (admins get the first venue overall).
            let firstMine = vm.venues.first(where: { vm.managedVenueIds.contains($0.id) })?.id
            vm.adminVenueId = firstMine ?? (vm.isAdmin ? vm.venues.first?.id : nil)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "gear")
                    .font(.system(size: 11, weight: .semibold))
                Text("Manager")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.3)
            }
            .foregroundStyle(t.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(t.accent.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(t.accent.opacity(0.33), lineWidth: 0.5))
        }
    }
}
