import Cocoa

class CustomizeStyleSheet: SheetWindow {
    // Local labels (rows owned by this sheet). The Show/Hide rows below are sourced from
    // `ShowHideIllustratedView`'s static constants so each NSLocalizedString call lives in
    // exactly one place across the codebase.
    private static let labelShowTitles = NSLocalizedString("Show titles", comment: "")
    private static let labelTitleTruncation = NSLocalizedString("Title truncation", comment: "")

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        labelShowTitles,
        labelTitleTruncation,
        ShowHideIllustratedView.hideStatusIconsLabel,
        ShowHideIllustratedView.hideStatusIconsSubtitle,
        ShowHideIllustratedView.hideSpaceNumberLabelsLabel,
        ShowHideIllustratedView.hideColoredCirclesLabel,
        IllustratedImageThemeView.placeholderLabelText,
    ] + ShowTitlesPreference.allCases.map { $0.localizedString }
      + TitleTruncationPreference.allCases.map { $0.localizedString }

    static let illustratedImageWidth = width

    let style = Preferences.appearanceStyle
    var illustratedImageView: IllustratedImageThemeView!
    var showHideIllustratedView: ShowHideIllustratedView!

    override func makeContentView() -> NSView {
        // This sheet carries only the style-tied GLOBAL toggles. Anything per-shortcut
        // (`showAppsOrWindows`, `showTabsAsWindows`) belongs in `ControlsTab` instead.
        illustratedImageView = IllustratedImageThemeView(style, CustomizeStyleSheet.illustratedImageWidth)
        showHideIllustratedView = ShowHideIllustratedView(style, illustratedImageView)
        let showHideView = showHideIllustratedView.makeView()
        let advancedTable = TableGroupView(width: CustomizeStyleSheet.width)
        let showTitles = TableGroupView.Row(leftTitle: Self.labelShowTitles,
            rightViews: [LabelAndControl.makeDropdown(
                "showTitles", ShowTitlesPreference.allCases, extraAction: { [weak self] _ in
                    self?.showTitlesIllustratedImage()
                })])
        advancedTable.addRow(showTitles, onMouseEntered: { [weak self] _, _ in
            self?.showTitlesIllustratedImage()
        })
        let titleTruncation = TableGroupView.Row(leftTitle: Self.labelTitleTruncation,
            rightViews: LabelAndControl.makeRadioButtons("titleTruncation", TitleTruncationPreference.allCases))
        advancedTable.addRow(titleTruncation)
        advancedTable.onMouseExited = { [weak self] event, view in
            guard let self else { return }
            IllustratedImageThemeView.resetImage(self.illustratedImageView, event, view)
        }
        let advancedView = TableGroupSetView(originalViews: [advancedTable], padding: 0)
        return TableGroupSetView(originalViews: [illustratedImageView, showHideView, advancedView], padding: 0)
    }

    private func showTitlesIllustratedImage() {
        illustratedImageView.highlight(true, Preferences.showTitles.image.name)
    }
}

/// Sliders for what the Size presets and the transparent switcher otherwise fix: the panel's background, the
/// cards, how much of the screen the panel may use, and the Thumbnails style's font, icon and row sizes.
class FineTuneSheet: SheetWindow {
    private static let title = NSLocalizedString("Fine-tune", comment: "")
    private static let sizesNote = NSLocalizedString("Choosing a Size resets these to that Size. They apply to the Thumbnails style, except with Auto or a shortcut that overrides the Size.", comment: "")
    private static let labelBackgroundOpacity = NSLocalizedString("Background opacity", comment: "")
    private static let labelCardOpacity = NSLocalizedString("Card opacity", comment: "")
    private static let labelCardCornerRadius = NSLocalizedString("Card corner radius", comment: "")
    private static let labelCardPadding = NSLocalizedString("Card padding", comment: "")
    private static let labelMaxWidth = NSLocalizedString("Max width on screen", comment: "")
    private static let labelMaxHeight = NSLocalizedString("Max height on screen", comment: "")
    private static let labelTitleFontSize = NSLocalizedString("Title font size", comment: "")
    private static let labelTitleFontWeight = NSLocalizedString("Title font weight", comment: "")
    private static let labelIconSize = NSLocalizedString("App icon size", comment: "")
    private static let labelRows = NSLocalizedString("Rows of thumbnails", comment: "")
    private static let labelAuto = NSLocalizedString("Auto", comment: "")
    private static let sliderWidth = CGFloat(170)

    /// Pre-build search index for the open-button. See `SettingsSearchIndex.sheetSearchableStrings`.
    static let searchableStrings: [String] = [
        title, labelBackgroundOpacity, labelCardOpacity, labelCardCornerRadius, labelCardPadding, labelMaxWidth, labelMaxHeight,
        labelTitleFontSize, labelTitleFontWeight, labelIconSize, labelRows,
    ] + TitleFontWeightPreference.allCases.map { $0.localizedString }

    override func makeContentView() -> NSView {
        let switcher = TableGroupView(title: Self.title, width: SheetWindow.width)
        addSlider(switcher, Self.labelBackgroundOpacity, "switcherBackgroundOpacity", 0...100, "%")
        addSlider(switcher, Self.labelCardOpacity, "cardOpacity", 0...100, "%")
        addSlider(switcher, Self.labelCardCornerRadius, "cardCornerRadius", 0...24, "pt")
        addCardPaddingSlider(switcher)
        addMaxWidthRow(switcher)
        addSlider(switcher, Self.labelMaxHeight, "switcherMaxHeight", AppearanceTestable.screenPercentRange, "%")
        let sizes = TableGroupView(subTitle: Self.sizesNote, width: SheetWindow.width)
        addSlider(sizes, Self.labelTitleFontSize, "titleFontSize", 10...24, "pt")
        sizes.addRow(leftText: Self.labelTitleFontWeight,
                     rightViews: [LabelAndControl.makeDropdown("titleFontWeight", TitleFontWeightPreference.allCases)])
        addSlider(sizes, Self.labelIconSize, "thumbnailIconSize", 12...48, "pt")
        addRowsSlider(sizes)
        return TableGroupSetView(originalViews: [switcher, sizes], padding: 0)
    }

    /// Written on release, not while dragging: each value rebuilds the switcher (`preferencesRequiringUiReset`),
    /// and the icon size also fetches every app icon again.
    private func addSlider(_ table: TableGroupView, _ label: String, _ key: String, _ range: ClosedRange<Int>, _ unit: String) {
        let (slider, value) = makeSlider(key, range, unit)
        table.addRow(leftText: label, rightViews: [slider, value])
    }

    private func makeSlider(_ key: String, _ range: ClosedRange<Int>, _ unit: String) -> (NSSlider, NSTextField) {
        let views = LabelAndControl.makeLabelWithSlider("", key, Double(range.lowerBound), Double(range.upperBound), 0, false, unit, width: Self.sliderWidth)
        let slider = views[1] as! NSSlider
        slider.isContinuous = false
        return (slider, Self.valueLabel(views[2] as! NSTextField))
    }

    /// While Auto is on, the disabled slider shows the width Auto gives; turning Auto off starts from that width, so
    /// the switcher doesn't jump.
    private func addMaxWidthRow(_ table: TableGroupView) {
        let (slider, value) = makeSlider("switcherMaxWidth", AppearanceTestable.screenPercentRange, "%")
        let autoPercent = Int((AppearanceTestable.comfortableWidth(NSScreen.preferred.physicalSize().map { $0.width }) * 100).rounded())
        let show = { (percent: Int) in
            slider.integerValue = percent
            value.stringValue = Self.measurement(percent, "%")
        }
        slider.isEnabled = !Preferences.switcherMaxWidthAuto
        if Preferences.switcherMaxWidthAuto { show(autoPercent) }
        let autoSwitch = LabelAndControl.makeSwitch("switcherMaxWidthAuto", extraAction: { control in
            let isAuto = (control as! NSButton).state == .on
            slider.isEnabled = !isAuto
            show(autoPercent)
            guard !isAuto else { return }
            Preferences.set("switcherMaxWidth", String(autoPercent))
        })
        table.addRow(leftText: Self.labelMaxWidth, rightViews: [NSTextField(labelWithString: Self.labelAuto), autoSwitch, slider, value])
    }

    /// Steps by 0.1pt, which the stock slider (integer values only) can't express, so the value is stored in tenths.
    /// The upper end is where the selection ring around the card reaches the tile's edge (`effectiveCardPadding`).
    private func addCardPaddingSlider(_ table: TableGroupView) {
        let maxTenths = Int((AppearanceTestable.effectiveCardPadding(.greatestFiniteMagnitude, edgeInsets: Appearance.edgeInsetsSize) * 10).rounded())
        let slider = makeIntegerSlider(0...max(maxTenths, 1), Int((Preferences.cardPadding * 10).rounded()))
        let value = Self.valueLabel(NSTextField(labelWithString: Self.paddingText(slider.integerValue)))
        slider.onAction = { control in
            let tenths = (control as! NSSlider).integerValue
            value.stringValue = Self.paddingText(tenths)
            Preferences.set("cardPaddingTenths", String(tenths))
        }
        table.addRow(leftText: Self.labelCardPadding, rightViews: [slider, value])
    }

    private static func paddingText(_ tenths: Int) -> String {
        Self.measurementText(Double(tenths) / 10, "pt", fractionDigits: 1)
    }

    private func makeIntegerSlider(_ range: ClosedRange<Int>, _ value: Int) -> NSSlider {
        let slider = NSSlider()
        slider.minValue = Double(range.lowerBound)
        slider.maxValue = Double(range.upperBound)
        slider.isContinuous = false
        slider.integerValue = value
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addOrUpdateConstraint(slider.widthAnchor, Self.sliderWidth)
        return slider
    }

    /// Rows step by half a row, which the stock slider (integer values only) can't express, so the value is stored doubled.
    private func addRowsSlider(_ table: TableGroupView) {
        let range = AppearanceTestable.halfRowsRange
        let slider = NSSlider()
        slider.minValue = Double(range.lowerBound)
        slider.maxValue = Double(range.upperBound)
        slider.numberOfTickMarks = range.count
        slider.allowsTickMarkValuesOnly = true
        slider.isContinuous = false
        slider.integerValue = Preferences.thumbnailHalfRows
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.addOrUpdateConstraint(slider.widthAnchor, Self.sliderWidth)
        let value = Self.valueLabel(NSTextField(labelWithString: Self.rowsText(slider.integerValue)))
        slider.onAction = { control in
            let halfRows = (control as! NSSlider).integerValue
            value.stringValue = Self.rowsText(halfRows)
            Preferences.set("thumbnailHalfRows", String(halfRows))
        }
        table.addRow(leftText: Self.labelRows, rightViews: [slider, value])
    }

    private static func rowsText(_ halfRows: Int) -> String {
        halfRows % 2 == 0 ? String(halfRows / 2) : String(format: "%.1f", Double(halfRows) / 2)
    }

    private static func measurement(_ value: Int, _ unit: String) -> String {
        measurementText(Double(value), unit, fractionDigits: 0)
    }

    private static func measurementText(_ value: Double, _ unit: String, fractionDigits: Int) -> String {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter = NumberFormatter()
        formatter.numberFormatter.minimumFractionDigits = fractionDigits
        formatter.numberFormatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: Measurement(value: value, unit: Unit(symbol: unit)))
    }

    private static func valueLabel(_ field: NSTextField) -> NSTextField {
        field.textColor = .gray
        field.alignment = .right
        field.fit(56, field.fittingSize.height)
        return field
    }
}
