import Foundation

class AppearanceTestable {
    /// How wide should the TilesPanel be, for comfortable viewing?
    /// * a comfortable field-of-view is 50-60 degrees
    /// * people sit at various distances from the screen. We can't know how far they sit
    /// * most people will seat far enough so that they can view the whole width of the screen
    /// * some people use wide-screen or TV monitors. Those people tend to be too close to the screen, since they need to use keyboard and mouse on their desk
    /// Let's use this heuristic: let's assume that people can view 60cm comfortably. Bigger screens can only show parts of AltTab
    /// Let's clamp at 90% like Windows 11
    /// Let's clamp at 45% (value for the biggest, 60" screens)
    static func comfortableWidth(_ physicalWidth: Double?) -> Double {
        if let physicalWidth {
            return min(0.9, max(0.45, 600.0 / physicalWidth))
        }
        return 0.9
    }

    // calculate windowMinWidthInRow and windowMaxWidthInRow such that:
    // * fullscreen windows fill their tile vertically
    // * narrow windows have enough width that a few words can be read from their title
    static func goodValuesForThumbnailsWidthMinMax(_ aspectRatio: CGFloat, _ rowsCount: CGFloat) -> (CGFloat, CGFloat) {
        let minRatio: CGFloat
        let maxRatio: CGFloat
        if aspectRatio >= 1 {
            minRatio = 0.7 / (aspectRatio * rowsCount)
            maxRatio = 1.5 / (aspectRatio * rowsCount)
        } else {
            minRatio = 1.3 / rowsCount
            maxRatio = 2.1 / rowsCount
        }
        // Make sure the values are clamped between some reasonable bounds
        return (max(0.09, minRatio), min(0.30, maxRatio))
    }

    enum ThumbnailsPreset { case small, medium, large }

    /// The Thumbnails style's fine-tune values. Rows are stored doubled so a slider can step by half a row.
    struct ThumbnailsSizing: Equatable {
        let halfRows: Int
        let iconSize: Int
        let fontSize: Int
    }

    static let halfRowsRange = 2...16
    static let screenPercentRange = 40...100

    /// The values Small, Medium and Large set; choosing one of them resets the fine-tune sliders to these.
    static func thumbnailsSizing(_ preset: ThumbnailsPreset) -> ThumbnailsSizing {
        switch preset {
            case .small: return ThumbnailsSizing(halfRows: 10, iconSize: 16, fontSize: 13)
            case .medium: return ThumbnailsSizing(halfRows: 8, iconSize: 26, fontSize: 14)
            case .large: return ThumbnailsSizing(halfRows: 6, iconSize: 28, fontSize: 16)
        }
    }

    static func thumbnailRows(halfRows: Int, isHorizontalScreen: Bool) -> CGFloat {
        let rows = CGFloat(min(max(halfRows, halfRowsRange.lowerBound), halfRowsRange.upperBound)) / 2
        return isHorizontalScreen ? rows : rows + 3
    }

    static func maxWidthOnScreen(auto: Bool, percent: Int, physicalWidth: Double?) -> Double {
        auto ? comfortableWidth(physicalWidth) : clampedScreenFraction(percent)
    }

    static func maxHeightOnScreen(percent: Int) -> Double {
        clampedScreenFraction(percent)
    }

    private static func clampedScreenFraction(_ percent: Int) -> Double {
        Double(min(max(percent, screenPercentRange.lowerBound), screenPercentRange.upperBound)) / 100
    }

    /// The selection ring is drawn this far outside the card, under it.
    static let cardRingMargin = CGFloat(3)

    /// Capped so the selection ring around the card still fits in the tile.
    static func effectiveCardPadding(_ padding: CGFloat, edgeInsets: CGFloat) -> CGFloat {
        min(max(padding, 0), max(0, edgeInsets - cardRingMargin))
    }

    /// The card around a tile's title row (from edgeInsets, across the tile's inner width) and its thumbnail
    /// (down to contentBottom), with `padding` on every side.
    static func cardFrame(tileWidth: CGFloat, edgeInsets: CGFloat, contentBottom: CGFloat, padding: CGFloat) -> CGRect {
        let inset: CGFloat = edgeInsets - effectiveCardPadding(padding, edgeInsets: edgeInsets)
        let width: CGFloat = tileWidth - inset * 2
        let height: CGFloat = contentBottom + edgeInsets - inset * 2
        return CGRect(x: inset, y: inset, width: width, height: height)
    }

    static func cardInnerRadius(cardRadius: CGFloat, padding: CGFloat) -> CGFloat {
        max(0, cardRadius - padding)
    }
}

enum ThumbnailPlaceholderLayout {
    static func reservesWindowGeometry(_ windowSize: CGSize?, screenRecordingGranted: Bool) -> Bool {
        guard screenRecordingGranted, let windowSize else { return false }
        return windowSize.width > 0 && windowSize.height > 0
    }
}
