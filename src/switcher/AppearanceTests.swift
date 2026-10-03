import XCTest

final class AppearanceTests: XCTestCase {
    // TODO add 6, 7, 8 rowsCount and reuse vertical screens data from bellow
    func testGoodValuesForThumbnailsWidthMinMax() throws {
        var actual: (CGFloat, CGFloat)
        for (model, (pixelWidth, pixelHeight), _, (expectedHorizontal, _), expectedArray) in screens {
            for (rowCount, expectedMin, expectedMax) in expectedArray {
                actual = AppearanceTestable.goodValuesForThumbnailsWidthMinMax((pixelWidth * expectedHorizontal) / (pixelHeight * 0.8), CGFloat(rowCount))
                XCTAssertEqual(actual.0, expectedMin, accuracy: 0.01, model)
                XCTAssertEqual(actual.1, expectedMax, accuracy: 0.01, model)
            }
        }
    }


    func testComfortableWidth() throws {
        var actual: Double
        for (model, _, (physicalWidth, physicalHeight), (expectedHorizontal, expectedVertical), _) in screens {
            // screen used horizontally
            actual = AppearanceTestable.comfortableWidth(physicalWidth)
            XCTAssertEqual(actual, expectedHorizontal, accuracy: 0.01, model)
            // screen used vertically
            actual = AppearanceTestable.comfortableWidth(physicalHeight)
            XCTAssertEqual(actual, expectedVertical, accuracy: 0.01, model)
        }

    }

    /// Screens that don't report their physical dimensions (`physicalWidth == nil`) get the 0.9
    /// default — the same clamp Windows 11 uses. Without this, ultrawides would fall to 0.45 just
    /// because we lack the data, which is worse than picking a sane default.
    func testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil() throws {
        XCTAssertEqual(AppearanceTestable.comfortableWidth(nil), 0.9)
    }

    /// Portrait-oriented usage (aspectRatio < 1) takes the second formula branch with different
    /// constants. The fixture above is horizontal-only; this pins the portrait path.
    func testGoodValuesForThumbnailsWidthMinMaxPortrait() throws {
        // aspectRatio = 0.5, rowsCount = 4 → minRatio = 1.3/4 = 0.325, maxRatio = 2.1/4 = 0.525
        // Then clamp: lo = max(0.09, 0.325) = 0.325, hi = min(0.30, 0.525) = 0.30
        let (lo, hi) = AppearanceTestable.goodValuesForThumbnailsWidthMinMax(0.5, 4)
        XCTAssertEqual(lo, 0.325, accuracy: 0.001)
        XCTAssertEqual(hi, 0.30, accuracy: 0.001)
        // smaller portrait ratio with more rows → both fall into the clamp zone
        let (lo2, hi2) = AppearanceTestable.goodValuesForThumbnailsWidthMinMax(0.5, 16)
        XCTAssertEqual(lo2, max(0.09, 1.3 / 16), accuracy: 0.001)
        XCTAssertEqual(hi2, min(0.30, 2.1 / 16), accuracy: 0.001)
    }

    /// The Small/Medium/Large buttons reset the fine-tune sliders to these values, so they must stay the
    /// values those sizes always had.
    func testThumbnailsSizingPresetsKeepTheSmallMediumLargeValues() {
        XCTAssertEqual(AppearanceTestable.thumbnailsSizing(.small), AppearanceTestable.ThumbnailsSizing(halfRows: 10, iconSize: 16, fontSize: 13))
        XCTAssertEqual(AppearanceTestable.thumbnailsSizing(.medium), AppearanceTestable.ThumbnailsSizing(halfRows: 8, iconSize: 26, fontSize: 14))
        XCTAssertEqual(AppearanceTestable.thumbnailsSizing(.large), AppearanceTestable.ThumbnailsSizing(halfRows: 6, iconSize: 28, fontSize: 16))
    }

    /// Vertical screens fit 3 more rows than horizontal ones, like the presets always did (3→6, 4→7, 5→8).
    func testThumbnailRowsStepByHalfAndAddThreeOnVerticalScreens() {
        XCTAssertEqual(AppearanceTestable.thumbnailRows(halfRows: 7, isHorizontalScreen: true), 3.5)
        XCTAssertEqual(AppearanceTestable.thumbnailRows(halfRows: 6, isHorizontalScreen: false), 6)
        XCTAssertEqual(AppearanceTestable.thumbnailRows(halfRows: 10, isHorizontalScreen: false), 8)
    }

    func testThumbnailRowsAreClampedToTheSliderRange() {
        XCTAssertEqual(AppearanceTestable.thumbnailRows(halfRows: 0, isHorizontalScreen: true), 1)
        XCTAssertEqual(AppearanceTestable.thumbnailRows(halfRows: 40, isHorizontalScreen: true), 8)
    }

    func testMaxWidthOnScreenFollowsComfortableWidthWhenAuto() {
        XCTAssertEqual(AppearanceTestable.maxWidthOnScreen(auto: true, percent: 50, physicalWidth: 825),
                       AppearanceTestable.comfortableWidth(825))
    }

    func testMaxWidthOnScreenUsesThePercentClampedWhenNotAuto() {
        XCTAssertEqual(AppearanceTestable.maxWidthOnScreen(auto: false, percent: 95, physicalWidth: 825), 0.95, accuracy: 0.0001)
        XCTAssertEqual(AppearanceTestable.maxWidthOnScreen(auto: false, percent: 10, physicalWidth: nil), 0.4, accuracy: 0.0001)
        XCTAssertEqual(AppearanceTestable.maxWidthOnScreen(auto: false, percent: 150, physicalWidth: nil), 1.0, accuracy: 0.0001)
    }

    func testMaxHeightOnScreenIsThePercentClamped() {
        XCTAssertEqual(AppearanceTestable.maxHeightOnScreen(percent: 80), 0.8, accuracy: 0.0001)
        XCTAssertEqual(AppearanceTestable.maxHeightOnScreen(percent: 0), 0.4, accuracy: 0.0001)
    }

    /// The card wraps the title row (which starts at edgeInsets and spans the tile's inner width) and the
    /// thumbnail (down to contentBottom), with the padding on every side.
    func testCardWrapsTheTitleRowAndThumbnailWithThePadding() {
        let frame = AppearanceTestable.cardFrame(tileWidth: 300, edgeInsets: 12, contentBottom: 245, padding: 6)
        XCTAssertEqual(frame, CGRect(x: 6, y: 6, width: 288, height: 245))
        XCTAssertEqual(frame.maxY, 245 + 6)
    }

    /// The selection ring is drawn 3pt outside the card, under it; the padding stops where that ring would leave
    /// the tile. Down at 0 the card hugs its content.
    func testCardPaddingIsClampedSoTheSelectionRingFitsTheTile() {
        XCTAssertEqual(AppearanceTestable.effectiveCardPadding(20, edgeInsets: 12), 9)
        XCTAssertEqual(AppearanceTestable.effectiveCardPadding(-1, edgeInsets: 12), 0)
        XCTAssertEqual(AppearanceTestable.effectiveCardPadding(0.3, edgeInsets: 12), 0.3, accuracy: 0.0001)
        XCTAssertEqual(AppearanceTestable.cardFrame(tileWidth: 300, edgeInsets: 12, contentBottom: 245, padding: 0),
                       CGRect(x: 12, y: 12, width: 276, height: 233))
    }

    /// The thumbnail's corners are concentric with the card's: the card radius minus the padding between them.
    func testCardInnerRadiusIsConcentric() {
        XCTAssertEqual(AppearanceTestable.cardInnerRadius(cardRadius: 16, padding: 6), 10)
        XCTAssertEqual(AppearanceTestable.cardInnerRadius(cardRadius: 4, padding: 6), 0)
    }

    func testThumbnailPlaceholderReservesKnownWindowGeometryWhileCaptureIsAvailable() {
        XCTAssertTrue(ThumbnailPlaceholderLayout.reservesWindowGeometry(
            CGSize(width: 1200, height: 800), screenRecordingGranted: true))
    }

    func testThumbnailPlaceholderUsesIconGeometryWithoutScreenRecording() {
        XCTAssertFalse(ThumbnailPlaceholderLayout.reservesWindowGeometry(
            CGSize(width: 1200, height: 800), screenRecordingGranted: false))
    }

    func testThumbnailPlaceholderUsesIconGeometryWithoutValidWindowSize() {
        XCTAssertFalse(ThumbnailPlaceholderLayout.reservesWindowGeometry(nil, screenRecordingGranted: true))
        XCTAssertFalse(ThumbnailPlaceholderLayout.reservesWindowGeometry(.zero, screenRecordingGranted: true))
    }

    private let screens: [(String, (CGFloat, CGFloat), (CGFloat, CGFloat), (CGFloat, CGFloat), [(Int, CGFloat, CGFloat)])] = [
        // screen model, (widthInPixels, heightInPixels), (physicalWidthInMM, physicalHeightInMM), (expectedWidthForHorizontal, expectedWidthForVertical), (rowCount, expectedMinWidth, expectedMaxWidth)
        ("11\" Laptop: MacBook Air 11\": HD", (1366, 768), (255.7, 178.6), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("13\" Laptop: MacBook Air 13\": WXGA+", (1440, 900), (304.1, 197.8), (0.90, 0.90), [(3, 0.13, 0.28), (4, 0.10, 0.21), (5, 0.09, 0.17)]),
        ("14\" Laptop: MacBook Pro 14\": 3K", (3024, 1964), (311.0, 221.1), (0.90, 0.90), [(3, 0.13, 0.29), (4, 0.10, 0.22), (5, 0.09, 0.17)]),
        ("15\" Laptop: MacBook Pro 15\": QXGA", (2880, 1800), (344.4, 233.0), (0.90, 0.90), [(3, 0.13, 0.28), (4, 0.10, 0.21), (5, 0.09, 0.17)]),
        ("16\" Laptop: MacBook Pro 16\": 3.5K", (3456, 2234), (358.4, 245.9), (0.90, 0.90), [(3, 0.13, 0.29), (4, 0.10, 0.22), (5, 0.09, 0.17)]),
        ("19\" Monitor: Apple Studio Display 19\": HD", (1440, 900), (403.0, 236.0), (0.90, 0.90), [(3, 0.13, 0.28), (4, 0.10, 0.21), (5, 0.09, 0.17)]),
        ("20\" Monitor: Apple Cinema Display 20\": WSXGA+", (1680, 1050), (440.0, 268.0), (0.90, 0.90), [(3, 0.13, 0.28), (4, 0.10, 0.21), (5, 0.09, 0.17)]),
        ("21\" Monitor: LG 21:9 UltraWide: UWHD", (2560, 1080), (470.0, 290.0), (0.90, 0.90), [(3, 0.09, 0.19), (4, 0.09, 0.14), (5, 0.09, 0.11)]),
        ("22\" Monitor: ASUS 22\" Full HD: Full HD", (1920, 1080), (485.0, 290.0), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("24\" Monitor: Dell P2419H: Full HD", (1920, 1080), (531.3, 298.6), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("27\" Monitor: LG 27UK850-W: 4K", (3840, 2160), (596.8, 336.4), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("30\" Monitor: BenQ PD3200U: 4K", (3840, 2160), (657.5, 376.3), (0.90, 0.90), [(3, 0.12, 0.25), (4, 0.09, 0.19), (5, 0.09, 0.15)]),
        ("32\" Monitor: BenQ EW3270U: 4K", (3840, 2160), (711.5, 398.9), (0.84, 0.90), [(3, 0.12, 0.27), (4, 0.09, 0.20), (5, 0.09, 0.16)]),
        ("34\" UltraWide Monitor: LG 34UC79G-B: UWHD", (2560, 1080), (798.5, 336.5), (0.75, 0.90), [(3, 0.10, 0.22), (4, 0.09, 0.17), (5, 0.09, 0.14)]),
        ("34\" UltraWide Monitor: LG 34WN80C-B: UWQHD", (3440, 1440), (799.8, 334.8), (0.75, 0.90), [(3, 0.10, 0.22), (4, 0.09, 0.17), (5, 0.09, 0.13)]),
        ("32\" TV: Samsung UE32T5300: Full HD", (1920, 1080), (715.0, 406.0), (0.83, 0.90), [(3, 0.13, 0.27), (4, 0.09, 0.20), (5, 0.09, 0.16)]),
        ("40\" TV: Samsung Q60B: 4K", (3840, 2160), (889.0, 510.0), (0.67, 0.90), [(3, 0.16, 0.30), (4, 0.12, 0.25), (5, 0.09, 0.20)]),
        ("43\" TV: LG 43UN7300: 4K", (3840, 2160), (956.0, 551.0), (0.62, 0.90), [(3, 0.17, 0.30), (4, 0.13, 0.27), (5, 0.10, 0.22)]),
        ("50\" TV: Samsung TU8000: 4K", (3840, 2160), (1110.0, 630.0), (0.54, 0.90), [(3, 0.19, 0.30), (4, 0.15, 0.30), (5, 0.12, 0.25)]),
        ("55\" TV: LG OLED55CXPUA: 4K", (3840, 2160), (1210.0, 715.0), (0.49, 0.83), [(3, 0.21, 0.30), (4, 0.16, 0.30), (5, 0.13, 0.28)]),
        ("60\" TV: Vizio 60-inch 4K: 4K", (3840, 2160), (1320.0, 750.0), (0.45, 0.80), [(3, 0.23, 0.30), (4, 0.17, 0.30), (5, 0.14, 0.30)]),
    ]
}
