import Cocoa

class Appearance {
    // size
    static var resolvedSize = AppearanceSizePreference.medium
    static var hideThumbnails = Bool(false)
    static var windowPadding = CGFloat(1000)
    static var windowCornerRadius = CGFloat(1000)
    static var cellCornerRadius = CGFloat(1000)
    static var edgeInsetsSize = CGFloat(1000)
    static var maxWidthOnScreen = CGFloat(1000)
    static var rowsCount = CGFloat(1000)
    static var iconSize = CGFloat(1000)
    static var fontHeight = CGFloat(3)
    static var font = NSFont.systemFont(ofSize: fontHeight)
    static var windowMinWidthInRow = CGFloat(1000)
    static var windowMaxWidthInRow = CGFloat(1000)

    static var maxHeightOnScreen = CGFloat(0.8)

    // size: constants
    static let interCellPadding = CGFloat(1)
    static let intraCellPadding = CGFloat(5)
    static let appIconLabelSpacing = CGFloat(2)

    // theme
    static var fontColor = NSColor.red
    static var imagesShadowColor = NSColor.red // for icon, thumbnail and windowless images
    static var textHaloColor = NSColor.red // behind text and glyphs drawn in fontColor
    static var cardBorderColor = NSColor.red
    static var material = LegacyMaterial.ultraDark
    static var highlightBorderWidth = CGFloat(3)

    // theme: constants
    static var enablePanelShadow = true
    static var highlightFocusedBackgroundColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.2) } }
    static var highlightHoveredBackgroundColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.1) } }
    static var highlightFocusedBorderColor: NSColor { get { NSColor.systemAccentColor } }
    static var highlightHoveredBorderColor: NSColor { get { NSColor.systemAccentColor.withAlphaComponent(0.7) } }
    static var searchMatchHighlightColor: NSColor { get { NSColor.systemYellow.withAlphaComponent(0.5) } }
    static var searchMatchForegroundColor: NSColor { get { NSColor(calibratedWhite: 0.12, alpha: 1) } }

    private static var currentStyle: AppearanceStylePreference { Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) }
    private static var currentSize: AppearanceSizePreference { Preferences.effectiveAppearanceSize(SwitcherSession.activeShortcutIndex) }
    static var currentTheme: AppearanceThemePreference {
        let theme = Preferences.effectiveAppearanceTheme(SwitcherSession.activeShortcutIndex)
        return theme == .system ? NSAppearance.currentDrawing().getThemeName() : theme
    }

    static func update() {
        updateSize()
        updateTheme()
    }

    private static func updateSize() {
        let isHorizontalScreen = NSScreen.preferred.isHorizontal()
        updateMaxSizeOnScreen()
        let sizeToApply: AppearanceSizePreference = currentSize == .auto ? .large : currentSize
        resolvedSize = sizeToApply
        let fineTune = usesFineTuneSizing
        applyConcreteSize(sizeToApply, isHorizontalScreen, fineTune: fineTune)
        updateFont(fineTune: fineTune)
    }

    static func applySize(_ size: AppearanceSizePreference) {
        let isHorizontalScreen = NSScreen.preferred.isHorizontal()
        resolvedSize = size
        applyConcreteSize(size, isHorizontalScreen, fineTune: false)
        updateFont(fineTune: false)
    }

    private static func updateMaxSizeOnScreen() {
        let physicalWidth: Double? = NSScreen.preferred.physicalSize().map { $0.width }
        maxWidthOnScreen = AppearanceTestable.maxWidthOnScreen(auto: Preferences.switcherMaxWidthAuto, percent: Preferences.switcherMaxWidth, physicalWidth: physicalWidth)
        maxHeightOnScreen = AppearanceTestable.maxHeightOnScreen(percent: Preferences.switcherMaxHeight)
    }

    /// The Fine-tune sheet's sizes stand in for the global Size, so they don't apply to a shortcut that overrides the
    /// size, nor to Auto, which picks its own size per summon (`TilesView.resolveAutoSize`).
    private static var usesFineTuneSizing: Bool {
        currentSize != .auto && !Preferences.hasOverride("appearanceSizeOverride", SwitcherSession.activeShortcutIndex)
    }

    private static func applyConcreteSize(_ size: AppearanceSizePreference, _ isHorizontalScreen: Bool, fineTune: Bool) {
        if currentStyle == .appIcons {
            appIconsSize(size)
        } else if currentStyle == .titles {
            titlesSize(size)
        } else {
            thumbnailsSize(isHorizontalScreen, fineTune ? fineTuneSizing : AppearanceTestable.thumbnailsSizing(preset(size)))
        }
    }

    private static var fineTuneSizing: AppearanceTestable.ThumbnailsSizing {
        .init(halfRows: Preferences.thumbnailHalfRows, iconSize: Preferences.thumbnailIconSize, fontSize: Preferences.titleFontSize)
    }

    static func preset(_ size: AppearanceSizePreference) -> AppearanceTestable.ThumbnailsPreset {
        switch size {
            case .small: return .small
            case .medium: return .medium
            case .large, .auto: return .large
        }
    }

    /// Choosing a Size moves the Fine-tune sliders to that size's values; they are its starting point.
    static func resetFineTuneSizing(to size: AppearanceSizePreference) {
        let sizing = AppearanceTestable.thumbnailsSizing(preset(size))
        Preferences.set("thumbnailHalfRows", String(sizing.halfRows), false)
        Preferences.set("thumbnailIconSize", String(sizing.iconSize), false)
        Preferences.set("titleFontSize", String(sizing.fontSize), false)
    }

    private static func updateTheme() {
        highlightBorderWidth = currentStyle == .titles ? 2 : 3
        if currentTheme == .dark {
            darkTheme()
        } else {
            lightTheme()
        }
        // for Liquid Glass, we don't want a shadow around the panel
        if #available(macOS 26.0, *), currentStyle == .appIcons && LiquidGlass.canUsePrivateLook {
            enablePanelShadow = false
        } else {
            enablePanelShadow = true
        }
    }

    private static func thumbnailsSize(_ isHorizontalScreen: Bool, _ sizing: AppearanceTestable.ThumbnailsSizing) {
        hideThumbnails = false
        windowPadding = 18
        windowCornerRadius = 23
        cellCornerRadius = 10
        edgeInsetsSize = 12
        if #available(macOS 26.0, *) {
            windowPadding = 28
            windowCornerRadius = 43
            cellCornerRadius = 18
        }
        rowsCount = AppearanceTestable.thumbnailRows(halfRows: sizing.halfRows, isHorizontalScreen: isHorizontalScreen)
        iconSize = CGFloat(sizing.iconSize)
        fontHeight = CGFloat(sizing.fontSize)
        let tilesPanelRatio = (NSScreen.preferred.frame.width * maxWidthOnScreen) / (NSScreen.preferred.frame.height * maxHeightOnScreen)
        (windowMinWidthInRow, windowMaxWidthInRow) = AppearanceTestable.goodValuesForThumbnailsWidthMinMax(tilesPanelRatio, rowsCount)
    }

    private static func appIconsSize(_ size: AppearanceSizePreference) {
        hideThumbnails = true
        windowPadding = 25
        windowCornerRadius = 23
        cellCornerRadius = 10
        edgeInsetsSize = 5
        if #available(macOS 26.0, *) {
            edgeInsetsSize = 6
        }
        windowMinWidthInRow = 0.04
        windowMaxWidthInRow = 0.3
        rowsCount = 1
        switch size {
            case .small:
                iconSize = 70
                fontHeight = 13
                if #available(macOS 26.0, *) {
                    windowCornerRadius = 50
                    cellCornerRadius = 24
                }
            case .medium:
                iconSize = 110
                fontHeight = 14
                if #available(macOS 26.0, *) {
                    windowCornerRadius = 55
                    cellCornerRadius = 35
                }
            case .large, .auto:
                windowPadding = 28
                iconSize = 150
                fontHeight = 16
                if #available(macOS 26.0, *) {
                    windowCornerRadius = 75
                    cellCornerRadius = 45
                }
        }
    }

    private static func titlesSize(_ size: AppearanceSizePreference) {
        hideThumbnails = true
        windowPadding = 18
        windowCornerRadius = 23
        cellCornerRadius = 10
        edgeInsetsSize = 7
        windowMinWidthInRow = 0.6
        windowMaxWidthInRow = 0.9
        rowsCount = 1
        switch size {
            case .small:
                iconSize = 18
                fontHeight = 13
            case .medium:
                iconSize = 24
                fontHeight = 14
            case .large, .auto:
                iconSize = 30
                fontHeight = 16
        }
    }

    private static func updateFont(fineTune: Bool) {
        font = NSFont.systemFont(ofSize: fontHeight, weight: fontWeight(fineTune: fineTune))
    }

    private static func fontWeight(fineTune: Bool) -> NSFont.Weight {
        if fineTune && currentStyle == .thumbnails { return Preferences.titleFontWeight.weight }
        guard #available(macOS 26.0, *) else { return .regular }
        return currentStyle == .appIcons ? .semibold : .medium
    }

    private static func lightTheme() {
        fontColor = .black.withAlphaComponent(0.8)
        imagesShadowColor = .gray.withAlphaComponent(0.8)
        textHaloColor = .white
        cardBorderColor = .black.withAlphaComponent(0.1)
        material = LegacyMaterial.mediumLight
    }

    private static func darkTheme() {
        fontColor = .white.withAlphaComponent(0.85)
        imagesShadowColor = .gray.withAlphaComponent(0.8)
        textHaloColor = .black
        cardBorderColor = .white.withAlphaComponent(0.1)
        material = LegacyMaterial.dark
    }
}

/// The only `NSVisualEffectView.Material` values that pin light or dark explicitly. Deprecated in
/// 10.14 in favour of semantic materials, which we can't use: those follow the view's
/// `NSAppearance`, whereas our theme comes from the user's own preference (see `updateTheme`).
/// Referenced by rawValue because naming the cases trips `SWIFT_TREAT_WARNINGS_AS_ERRORS`.
enum LegacyMaterial {
    static let dark = NSVisualEffectView.Material(rawValue: 2)!
    static let mediumLight = NSVisualEffectView.Material(rawValue: 8)!
    static let ultraDark = NSVisualEffectView.Material(rawValue: 9)!
}
