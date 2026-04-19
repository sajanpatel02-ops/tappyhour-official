import SwiftUI

struct ListFeedView: View {
    @Bindable var vm: AppViewModel

    private var t: AppTheme { vm.theme }
    private var venues: [Venue] {
        if vm.viewMode == .feed {
            return vm.filteredVenues.sorted { $0.endsIn < $1.endsIn }
        }
        return vm.filteredVenues
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if vm.viewMode == .feed {
                        feedHeader
                    } else {
                        listHeader
                    }
                    ForEach(venues) { venue in
                        VenueCard(venue: venue, vm: vm)
                            .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 120)
            }

        }
    }

    private var listHeader: some View {
        HStack {
            (Text("\(venues.count) ")
                .fontWeight(.semibold)
                .foregroundStyle(t.text)
            + Text("spots with happy hour now")
                .foregroundStyle(t.muted))
                .font(.system(size: 12))
            Spacer()
            managerChip
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
            managerChip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var managerChip: some View {
        Button { vm.adminVenueId = "v1" } label: {
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
