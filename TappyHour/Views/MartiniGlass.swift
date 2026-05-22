import SwiftUI

/// Custom SF-Symbols-style martini glass icon. SF Symbols doesn't ship a
/// martini glass — `wineglass` is the closest stock symbol but it reads as
/// "wine," not "cocktails." This Shape draws the same iconic V-on-a-stem
/// shape as the app icon: open V at top, vertical stem, horizontal base.
///
/// Used by the "favorite" toggle on VenueCard and VenueDetailView.
///
/// Render with `.stroke()` and pick a line width — the rest of the metrics
/// are normalized so the icon scales cleanly inside any frame.
struct MartiniGlass: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width
            let h = rect.height

            // Top rim — a flat line across the top of the V. Mirrors the
            // way the app icon depicts the glass opening. Stem is now
            // ~half the icon's height for a longer, more elegant silhouette.
            let topY = 0.10 * h
            let leftRim = CGPoint(x: 0.10 * w, y: topY)
            let rightRim = CGPoint(x: 0.90 * w, y: topY)
            let apex = CGPoint(x: 0.50 * w, y: 0.48 * h)
            let stemBottom = CGPoint(x: 0.50 * w, y: 0.92 * h)
            let baseLeft = CGPoint(x: 0.30 * w, y: 0.92 * h)
            let baseRight = CGPoint(x: 0.70 * w, y: 0.92 * h)

            // Outline the bowl: top rim → down to apex on the right → up to
            // left rim. One continuous path so the stroke joins look clean.
            p.move(to: leftRim)
            p.addLine(to: rightRim)
            p.addLine(to: apex)
            p.closeSubpath()

            // Stem
            p.move(to: apex)
            p.addLine(to: stemBottom)

            // Base
            p.move(to: baseLeft)
            p.addLine(to: baseRight)
        }
    }
}

/// View wrapper that renders a martini glass icon at a target size, with
/// optional filled-bowl state for "favorited." Uses stroke for the stem
/// and base lines; the bowl is either stroked (unfavorited) or filled
/// (favorited) to give a clear on/off read.
struct MartiniGlassIcon: View {
    var size: CGFloat = 18
    var lineWidth: CGFloat = 1.4
    var filled: Bool = false
    var color: Color

    var body: some View {
        MartiniGlass()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .background(
                // Only the bowl portion fills when favorited. We re-render
                // the same shape closed-path with `.fill` and let the stem
                // line stay as a stroke — visually this reads as "the glass
                // has liquid in it" without obscuring the silhouette.
                filled
                    ? AnyView(MartiniBowl().fill(color))
                    : AnyView(Color.clear)
            )
            .frame(width: size, height: size)
    }
}

/// Just the closed V-shaped bowl (no stem or base). Used to fill the
/// triangle portion when the venue is favorited.
private struct MartiniBowl: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            let w = rect.width
            let h = rect.height
            // Match the bowl proportions in MartiniGlass.path so the fill
            // sits exactly inside the stroke outline.
            p.move(to: CGPoint(x: 0.10 * w, y: 0.10 * h))
            p.addLine(to: CGPoint(x: 0.90 * w, y: 0.10 * h))
            p.addLine(to: CGPoint(x: 0.50 * w, y: 0.48 * h))
            p.closeSubpath()
        }
    }
}

#Preview {
    HStack(spacing: 24) {
        MartiniGlassIcon(size: 24, color: .gray)
        MartiniGlassIcon(size: 24, filled: true, color: .orange)
        MartiniGlassIcon(size: 40, lineWidth: 2.5, color: .gray)
        MartiniGlassIcon(size: 40, lineWidth: 2.5, filled: true, color: .orange)
    }
    .padding()
}
