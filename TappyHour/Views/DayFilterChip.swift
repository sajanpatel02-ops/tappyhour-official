import SwiftUI

/// Dropdown chip for picking which day's happy hours to show. Drives
/// `vm.listDayFilter`, which feeds both the list and the map's
/// annotations so the two views always agree.
struct DayFilterChip: View {
    @Bindable var vm: AppViewModel
    private var t: AppTheme { vm.theme }

    var body: some View {
        Menu {
            Button { vm.listDayFilter = .today } label: {
                Label("Today", systemImage: vm.listDayFilter == .today ? "checkmark" : "")
            }
            Button { vm.listDayFilter = .all } label: {
                Label("All days", systemImage: vm.listDayFilter == .all ? "checkmark" : "")
            }
            Divider()
            ForEach(DayKey.allCases) { d in
                Button { vm.listDayFilter = .day(d) } label: {
                    Label(d.displayName,
                          systemImage: vm.listDayFilter == .day(d) ? "checkmark" : "")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .opacity(0.7)
            }
            .foregroundStyle(t.text)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(t.card)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(t.cardBorder, lineWidth: 0.5))
        }
    }

    private var label: String {
        switch vm.listDayFilter {
        case .today:      "Today"
        case .all:        "All days"
        case .day(let d): d.displayName
        }
    }
}
