# Switcher panel background — Specs

No unit tests: `NSGlassEffectView` needs macOS 26 at runtime, and CI runs on macOS 15. The switcher's own
background is pinned on screen instead, by `ai/verify-no-panel-background.swift`.

## Summary

By default the switcher panel draws no background: `TilesView` hosts its content in a `TransparentEffectView`,
the panel is non-opaque and casts no shadow, and it has no scroller, so tiles sit directly on whatever is behind
it. The Fine-tune sheet's background opacity fades the upstream glass back in behind them (with the panel shadow
at 100%).

Each tile's title row and thumbnail sit together on one glass card (`makeCard`, the glass DockDoor puts behind its
preview cards). The card wraps that content with the Fine-tune sheet's padding (0.1pt steps, capped so the
selection ring fits the tile), so a shorter thumbnail makes a shorter card; the thumbnail's corners are concentric
with the card's, and the selection ring hugs the card with the matching radius. Its opacity and corner radius also
come from the sheet; at 0% opacity it disappears. Glyphs drawn in `Appearance.fontColor` without a card behind them
(status icons, the windowless-app indicator, the App Icons style's title, or any title once the card is at 0%) get
a halo in the opposite colour (`Appearance.textHaloColor`).

Glass builds its layers only when laid out inside a window, and `TileView` stops AppKit's layout at the tile
boundary, so the card is laid out explicitly (`layoutCard`, `TileView.viewDidMoveToWindow`); the same goes for the
background glass on every panel resize.

The panel still owns its transparent area: `TransparentEffectView` is filled at 1/255 alpha and the panel
sets `ignoresMouseEvents` explicitly, because clicks and scrolls on fully transparent pixels reached the
window behind it.

`requiredEffectViewKind()` still picks one of three effect views: frosted (macOS 25 and earlier), regular glass,
or the private clear-glass variant used by App Icons. It keys `TilesView`'s cache, picks the glass the background
opacity fades in, and the search discovery hint builds that glass for itself. `TilesView` caches one instance per
kind and calls `updateAppearance()` on reuse, so anything that varies with style or size has to be re-applied
there rather than at construction.

## Automated check

- **The panel draws no background** — `ai/verify-no-panel-background.swift [AltTab binary]` covers the
  screen with stripes, shows the switcher, and compares the panel's top and bottom padding with the same
  strips before it appeared. Exit 0 when they are identical, 1 when a background tints or blurs them (as it
  should once the background opacity is above 0).

## Manual scenarios

- **Text stays legible without a background** — summon Thumbnails, App Icons and Titles over a white
  window, over a page of text and over a dark window, in light and dark themes. Titles (on their cards),
  status icons and the windowless-app indicator stay readable; the selection highlight stays visible.
- **Fine-tune applies live** — change each slider and summon: background opacity, card opacity, corner
  radius and padding (down to 0, in 0.1pt steps), max width (Auto shows the width it gives), max height, font
  size and weight, icon size, rows. Choosing a Size resets font, icon and rows to that Size.
- **Cards hug their content** — narrow windows sit centred in a card no wider than the title row; a wide,
  short window gets a short card, with the selection ring around the card rather than the whole tile.
- **Gaps don't leak events** — with the switcher over a scrollable page, scroll and click in the gaps
  between tiles: the page behind must not scroll or take the click.
- **No scroller** — with more windows than fit, no scroller appears; wheel, trackpad and arrow keys still
  scroll.
- **Search hint keeps its glass** — the search discovery hint next to the switcher still has a background,
  and its text stays readable.
- **Glass corners clip to the glass shape** — the backing layer clips to the same continuous corner
  radius as `NSGlassEffectView`, which bounds the rectangular corner artifacts of
  [#5757](https://github.com/lwouis/alt-tab-macos/issues/5757). Inspect the search hint's corners, and the
  panel's once the background opacity is up, in light and dark appearances, against contrasting backgrounds.
- **Recheck on later macOS builds** — this works around a rendering bug rather than identifying it.
  Disabling the window shadow, allowing glass layout, and clipping to a rectangle all failed to fix it.
  Confirm the artifact is still there before keeping the rounded clip.
