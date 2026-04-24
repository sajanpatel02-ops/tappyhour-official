import SwiftUI
import NukeUI

/// Nuke-backed replacement for AsyncImage. Gives us in-memory +
/// on-disk caching so a photo doesn't re-download every time the
/// user scrolls back to a row, and lets us request smaller sizes
/// from CDNs that understand `?w=`.
struct CachedImage<Placeholder: View, Failure: View>: View {
    let url: URL?
    /// Target rendered width in points. Used to rewrite supported
    /// CDN URLs (getbento, imgix-style, Cloudinary) to a size that
    /// matches the view, so we're not decoding 1200×600 images into
    /// 84pt thumbnails.
    let targetWidth: CGFloat
    let placeholder: () -> Placeholder
    let failure: () -> Failure

    init(
        url: URL?,
        targetWidth: CGFloat,
        @ViewBuilder placeholder: @escaping () -> Placeholder = { Color.clear },
        @ViewBuilder failure: @escaping () -> Failure = { Color.clear }
    ) {
        self.url = url
        self.targetWidth = targetWidth
        self.placeholder = placeholder
        self.failure = failure
    }

    var body: some View {
        LazyImage(url: resizedURL) { state in
            if let image = state.image {
                image.resizable()
            } else if state.error != nil {
                failure()
            } else {
                placeholder()
            }
        }
    }

    /// Resize on the server when the CDN supports it. Falls back to
    /// the original URL for unknown hosts.
    private var resizedURL: URL? {
        guard let url else { return nil }
        // Use 2× for retina.
        let w = Int(targetWidth * UIScreen.main.scale)
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        let host = comps.host ?? ""

        // Hosts that take a `w=` query param (getbento / imgix / Cloudinary-ish).
        let supportsQuery = host.contains("getbento.com")
            || host.contains("imgix.net")
            || host.contains("cloudinary.com")
            || host.contains("squarespace-cdn.com")
            || host.contains("squarespacecdn.com")

        guard supportsQuery else { return url }

        var items = comps.queryItems ?? []
        items.removeAll { $0.name == "w" || $0.name == "h" }
        items.append(URLQueryItem(name: "w", value: String(w)))
        items.append(URLQueryItem(name: "fit", value: "crop"))
        items.append(URLQueryItem(name: "auto", value: "compress,format"))
        comps.queryItems = items
        return comps.url ?? url
    }
}
