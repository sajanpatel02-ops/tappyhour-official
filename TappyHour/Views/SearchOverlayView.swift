import SwiftUI

struct SearchOverlayView: View {
    @Bindable var vm: AppViewModel
    @FocusState private var focused: Bool

    private var t: AppTheme { vm.theme }
    private var filteredNeighborhoods: [String] {
        if vm.query.isEmpty { return NEIGHBORHOODS }
        return NEIGHBORHOODS.filter { $0.lowercased().contains(vm.query.lowercased()) }
    }

    var body: some View {
        t.bg.ignoresSafeArea()
            .overlay(content)
            .transition(.opacity)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search bar row
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
                    // Recents
                    sectionHeader("Recent")
                    ForEach(RECENT_SEARCHES, id: \.self) { r in
                        searchRow(icon: "clock", label: r) {
                            vm.query = r
                            vm.isSearchActive = false
                        }
                    }

                    // Neighborhoods
                    sectionHeader("Neighborhoods in Chicago")
                        .padding(.top, 12)
                    ForEach(filteredNeighborhoods, id: \.self) { n in
                        searchRow(icon: "mappin", label: n, showChevron: true) {
                            vm.query = n
                            vm.isSearchActive = false
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { focused = true }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.5)
            .foregroundStyle(t.muted)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
    }

    private func searchRow(icon: String, label: String, showChevron: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(t.muted)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(t.text)
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
