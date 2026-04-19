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
            Text("\(venues.count) ")
                .fontWeight(.semibold)
                .foregroundStyle(t.text)
            + Text("spots with happy hour now")
                .foregroundStyle(t.muted)
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 4)
    }

    private var feedHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Ending soon")
                .font(.custom("Georgia", size: 32))
                .foregroundStyle(t.text)
                .tracking(-0.5)
            Text("Happy hours wrapping in the next 2 hours")
                .font(.system(size: 13))
                .foregroundStyle(t.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}
