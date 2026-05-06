import SwiftUI

/// Dropdown chip for picking which day's happy hours to show. Drives
/// `vm.listDayFilter`, which feeds both the list and the map's
/// annotations so the two views always agree.
struct DayFilterChip: View {
    @Bindable var vm: AppViewModel
    private var t: AppTheme { vm.theme }

    var body: some View {
        Menu {
            menuItem("Live now", filter: .liveNow)
            menuItem("Today",    filter: .today)
            menuItem("All days", filter: .all)
            Divider()
            ForEach(DayKey.allCases) { d in
                menuItem(d.displayName, filter: .day(d))
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

    /// Renders a menu row with a checkmark only when selected. Avoids the
    /// "No symbol named '' found" runtime warning that comes from passing
    /// an empty `systemImage` to `Label`.
    @ViewBuilder
    private func menuItem(_ title: String, filter: ListDayFilter) -> some View {
        Button { vm.listDayFilter = filter } label: {
            if vm.listDayFilter == filter {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private var label: String {
        switch vm.listDayFilter {
        case .liveNow:    "Live now"
        case .today:      "Today"
        case .all:        "All days"
        case .day(let d): d.displayName
        }
    }
}
