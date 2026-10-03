protocol EffectView: NSView {
    func updateAppearance(cornerRadius: CGFloat)
    /// Where `TilesView` places its content (scroll view, search field, empty-state label).
    /// For `NSVisualEffectView` that's the view itself; for `NSGlassEffectView` it's `contentView`,
    /// the only place Apple guarantees rendering for embedded views.
    var hostView: NSView { get }
}

extension EffectView {
    func updateAppearance() { updateAppearance(cornerRadius: Appearance.windowCornerRadius) }
}

@available(macOS 26.0, *)
extension NSGlassEffectView: EffectView {
    func updateAppearance(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        // Left rectangular, the clip set in `makeGlassEffectView` draws a straight outline outside the
        // glass shape on macOS 27 (#5757). Set here, not there: cached views are reused across style
        // and size changes.
        layer!.cornerRadius = cornerRadius
    }

    var hostView: NSView { contentView! }
}

class FrostedGlassEffectView: NSVisualEffectView, EffectView {
    var hostView: NSView { self }

    convenience init() {
        self.init(frame: .zero)
        blendingMode = .behindWindow
        state = .active
        wantsLayer = true
        updateAppearance()
    }

    func updateAppearance(cornerRadius: CGFloat) {
        material = Appearance.material
        updateRoundedCorners(cornerRadius)
    }

    /// using layer!.cornerRadius works but the corners are aliased; this custom approach gives smooth rounded corners
    /// see https://stackoverflow.com/a/29386935/2249756
    private func updateRoundedCorners(_ cornerRadius: CGFloat) {
        if cornerRadius == 0 {
            maskImage = nil
        } else {
            let edgeLength = 2.0 * cornerRadius + 1.0
            let mask = NSImage(size: NSSize(width: edgeLength, height: edgeLength), flipped: false) { rect in
                let bezierPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
                NSColor.black.set()
                bezierPath.fill()
                return true
            }
            mask.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
            mask.resizingMode = .stretch
            maskImage = mask
        }
    }
}

/// The switcher's background. By default none: tiles sit directly on whatever is behind the panel. The Fine-tune
/// sheet's background opacity fades the upstream glass back in behind them.
class TransparentEffectView: NSView, EffectView {
    var hostView: NSView { self }
    private var background: EffectView?

    /// Observed on macOS 27: clicks and scrolls on fully transparent pixels of the panel went to the window
    /// behind it, so scrolling over a gap between tiles scrolled the page underneath. 1/255 of alpha is
    /// invisible, but leaves no fully transparent pixel. `TilesPanel` also sets `ignoresMouseEvents` explicitly.
    convenience init() {
        self.init(frame: .zero)
        wantsLayer = true
        layer!.backgroundColor = NSColor.black.withAlphaComponent(1 / 255).cgColor
    }

    func updateAppearance(cornerRadius: CGFloat) {
        let opacity = CGFloat(Preferences.switcherBackgroundOpacity) / 100
        guard opacity > 0 else {
            background?.isHidden = true
            return
        }
        let background = background ?? addBackground()
        background.isHidden = false
        background.alphaValue = opacity
        background.updateAppearance(cornerRadius: cornerRadius)
    }

    private func addBackground() -> EffectView {
        let view = makeEffectView(for: requiredEffectViewKind())
        view.frame = bounds
        view.autoresizingMask = [.width, .height]
        addSubview(view, positioned: .below, relativeTo: nil)
        background = view
        layoutBackground()
        return view
    }

    /// Glass rebuilds its layers only when laid out (see `layoutCard`), and the panel resizes on every summon.
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutBackground()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        layoutBackground()
    }

    private func layoutBackground() {
        guard let background, window != nil else { return }
        background.needsLayout = true
        background.layoutSubtreeIfNeeded()
    }
}

/// The card behind each tile's title row and thumbnail, holding them together like DockDoor's preview cards. With no
/// panel background the title would sit on whatever is behind the switcher, unreadable over text or light content;
/// the glass (DockDoor's card variant) blurs that into an even backing.
func makeCard() -> NSView {
    let card = makeCardMaterial()
    card.wantsLayer = true
    card.layer!.cornerCurve = .continuous
    card.layer!.masksToBounds = true
    card.layer!.borderWidth = 1.5
    return card
}

private func makeCardMaterial() -> NSView {
    if #available(macOS 26.0, *) {
        let glass = NSGlassEffectView()
        glass.contentView = NSView()
        if LiquidGlass.canUsePrivateLook {
            LiquidGlass.applyCardVariant(glass)
        } else {
            glass.style = .regular
        }
        return glass
    }
    let frosted = NSVisualEffectView()
    frosted.blendingMode = .behindWindow
    frosted.state = .active
    frosted.material = Appearance.material
    return frosted
}

/// The Fine-tune sheet's card opacity and corner radius. The glass shape and the layer clip get the same radius,
/// like the panel's glass does for #5757.
func styleCard(_ card: NSView) {
    let radius = CGFloat(Preferences.cardCornerRadius)
    card.alphaValue = CGFloat(Preferences.cardOpacity) / 100
    if #available(macOS 26.0, *), let glass = card as? NSGlassEffectView {
        glass.cornerRadius = radius
    }
    card.layer!.cornerRadius = radius
    card.layer!.borderColor = Appearance.cardBorderColor.cgColor
}

/// `NSGlassEffectView` sizes its internal layers in `layout()`, and AppKit's layout pass never reaches the card:
/// `TileView` stops it at the tile boundary. Measured: its internal layers stayed 0x0 and the glass drew nothing
/// until laid out explicitly (see also `TileView.viewDidMoveToWindow`).
func layoutCard(_ card: NSView, _ frame: NSRect) {
    guard card.frame != frame else { return }
    card.frame = frame
    card.layoutSubtreeIfNeeded()
}

/// The App Icons style uses the private `set_variant:` on `NSGlassEffectView` to get the macOS
/// Cmd-Tab-like clear glass look. `style = .clear` alone renders nearly fully transparent, so the
/// variant is what makes the panel visible. Cards use variant 18, the glass DockDoor puts behind its preview
/// cards. Lives here as a free helper (no NSGlassEffectView subclass).
enum LiquidGlass {
    private static let setVariantSelector = NSSelectorFromString("set_variant:")
    private typealias SetVariantFn = @convention(c) (AnyObject, Selector, Int) -> Void

    static let canUsePrivateLook: Bool = {
        if #available(macOS 26.0, *) {
            return class_getInstanceMethod(object_getClass(NSGlassEffectView()), setVariantSelector) != nil
        }
        return false
    }()

    @available(macOS 26.0, *)
    static func applyClearVariant(_ view: NSGlassEffectView) {
        applyVariant(view, 3)
    }

    @available(macOS 26.0, *)
    static func applyCardVariant(_ view: NSGlassEffectView) {
        applyVariant(view, 18)
    }

    @available(macOS 26.0, *)
    private static func applyVariant(_ view: NSGlassEffectView, _ variant: Int) {
        guard let method = class_getInstanceMethod(object_getClass(view), setVariantSelector) else { return }
        let f = unsafeBitCast(method_getImplementation(method), to: SetVariantFn.self)
        f(view, setVariantSelector, variant)
    }
}

enum EffectViewKind {
    case frosted
    case liquidGlassRegular
    case liquidGlassClear
}

func requiredEffectViewKind() -> EffectViewKind {
    if #available(macOS 26.0, *) {
        if Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) == .appIcons,
           LiquidGlass.canUsePrivateLook {
            return .liquidGlassClear
        }
        return .liquidGlassRegular
    }
    return .frosted
}

@available(macOS 26.0, *)
private func makeGlassEffectView(clear: Bool) -> NSGlassEffectView {
    let glass = NSGlassEffectView()
    glass.style = clear ? .clear : .regular
    if clear {
        LiquidGlass.applyClearVariant(glass)
    }
    // NSGlassEffectView only renders views embedded in `contentView`; this single host holds the
    // scroll view, search field and empty-state label so they all sit inside the glass.
    glass.contentView = NSView()
    // without this, there are weird shadows around the corners (most visible with .regular glass)
    glass.wantsLayer = true
    glass.layer!.masksToBounds = true
    glass.layer!.cornerCurve = .continuous
    // after the layer exists: `updateAppearance` rounds the clip through it
    glass.updateAppearance()
    return glass
}

func makeEffectView(for kind: EffectViewKind) -> EffectView {
    if #available(macOS 26.0, *) {
        switch kind {
            case .liquidGlassClear:
                return makeGlassEffectView(clear: true)
            case .liquidGlassRegular:
                if Preferences.effectiveAppearanceStyle(SwitcherSession.activeShortcutIndex) == .appIcons {
                    Logger.error {
                        let os = ProcessInfo.processInfo.operatingSystemVersion
                        return "Private API set_variant is no longer available. macOS version: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
                    }
                }
                return makeGlassEffectView(clear: false)
            case .frosted:
                break
        }
    }
    return FrostedGlassEffectView()
}
