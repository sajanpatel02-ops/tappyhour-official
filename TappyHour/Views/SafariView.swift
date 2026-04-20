import SwiftUI
import SafariServices

/// In-app web browser using SFSafariViewController. Use via `.sheet`:
///
///     .sheet(item: $urlToPresent) { SafariView(url: $0.url) }
///
/// Keeps users inside the app while still giving them a full Safari-powered
/// browser (shared cookies, reader mode, etc).
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        return SFSafariViewController(url: url, configuration: config)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

/// Identifiable URL wrapper so we can drive `.sheet(item:)`.
struct PresentedURL: Identifiable {
    let id = UUID()
    let url: URL
}
