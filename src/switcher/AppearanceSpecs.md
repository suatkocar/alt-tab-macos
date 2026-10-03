# Appearance (window sizing) — Specs

> **Line coverage:** `AppearanceTestable.swift` 79% · _refreshed 2026-05-27 by `/coverage-explore`_

## Summary

Two pure sizing functions in `AppearanceTestable` decide how big the switcher's thumbnails are on a
given display, so the UI feels right from an 11" laptop to a 60" TV. The suite pins their output against
a table of **21 real device models** (laptops, monitors, ultrawides, TVs) with known pixel + physical
dimensions, so a tweak to the formula can't silently regress any class of screen.

- `comfortableWidth(physicalDimension)` → the fraction of the screen the switcher should occupy (smaller
  fraction on bigger/wider screens, separate expectations for horizontal vs vertical use).
- `goodValuesForThumbnailsWidthMinMax(ratio, rowCount)` → the (min, max) thumbnail width for a given
  screen aspect ratio and row count (3, 4, or 5 rows).

## Behavior & edge cases

- Driven entirely by a fixture table: each row is `(model, pixels, physical-mm, expected comfortable
  fractions, [(rowCount, expectedMin, expectedMax)])`. Both tests loop the table and assert with `0.01`
  tolerance, naming the failing model.
- Bigger physical screens get a smaller comfortable fraction (a 60" TV shouldn't show a half-screen
  switcher); ultrawides get distinct horizontal vs vertical fractions.

## Test scenarios

Mirrors `AppearanceTests.swift` 1:1.

- **testGoodValuesForThumbnailsWidthMinMax** — for every model × {3,4,5} rows, the computed (min, max) thumbnail width matches the fixture.
- **testComfortableWidth** — for every model, the comfortable width fraction matches for both horizontal and vertical screen use.
- **testComfortableWidthFallsBackToDefaultWhenPhysicalWidthIsNil** — when the screen's physical dimensions aren't reported, fall back to the 0.9 default rather than the 0.45 floor.
- **testGoodValuesForThumbnailsWidthMinMaxPortrait** — for aspectRatio < 1 (portrait usage), the (min, max) uses the portrait formula and stays within the [0.09, 0.30] clamps.

## Fine-tune sizing

The Fine-tune sheet stores the Thumbnails style's rows (doubled, so a slider can step by half a row), app icon
size and title font size, plus how much of the screen the switcher may use. These pure functions turn them into
`Appearance` values; the Size presets are the sliders' starting points.

- **testThumbnailsSizingPresetsKeepTheSmallMediumLargeValues** — Small, Medium and Large keep the rows, icon and font sizes they always had, since choosing a Size resets the sliders to them.
- **testThumbnailRowsStepByHalfAndAddThreeOnVerticalScreens** — rows step by half, and vertical screens fit 3 more rows (the presets' 3→6, 4→7, 5→8).
- **testThumbnailRowsAreClampedToTheSliderRange** — a stored value outside 1–8 rows is clamped.
- **testMaxWidthOnScreenFollowsComfortableWidthWhenAuto** — with Auto on, the stored percent is ignored and `comfortableWidth` decides.
- **testMaxWidthOnScreenUsesThePercentClampedWhenNotAuto** — otherwise the percent applies, clamped to 40–100%.
- **testMaxHeightOnScreenIsThePercentClamped** — the max height is the stored percent, clamped to 40–100%.
- **testCardWrapsTheTitleRowAndThumbnailWithThePadding** — the card wraps the title row and the thumbnail with the padding on every side.
- **testCardPaddingIsClampedSoTheSelectionRingFitsTheTile** — the padding is capped where the selection ring would leave the tile; at 0 the card hugs its content.
- **testCardInnerRadiusIsConcentric** — the thumbnail's corners are the card's radius minus the padding, never negative.

## Thumbnail placeholders

- **testThumbnailPlaceholderReservesKnownWindowGeometryWhileCaptureIsAvailable** — a newly discovered window reserves its final aspect ratio while its first capture is in flight, so replacing the app-icon placeholder does not resize the switcher.
- **testThumbnailPlaceholderUsesIconGeometryWithoutScreenRecording** — an icon-only tile stays square when no window capture can arrive.
- **testThumbnailPlaceholderUsesIconGeometryWithoutValidWindowSize** — unknown or invalid window geometry falls back to the app icon.
