#!/usr/bin/env swift
// Checks that the switcher panel draws no background of its own. It covers every screen with a backdrop, shows
// the switcher, captures the area around it, hides it, captures the same area again, and compares the panel's top
// and bottom padding (the strips between the panel edge and the tiles) across the two. Glass or frosted
// backgrounds blur and tint the backdrop there; with no background the strips stay identical.
//
// usage: ai/verify-no-panel-background.swift [AltTab binary] [output dir] [stripes|white|none]
// The backdrop defaults to stripes; `white` checks legibility on a light window, `none` keeps the real
// screen (any still content works, since the check only compares the switcher shown with it hidden).
// The AltTab under test must already be running, and the terminal needs Screen Recording.
// Exit codes: 0 no background, 1 background visible, 2 the measurement itself is unreliable.
import Cocoa

let args = CommandLine.arguments
let binary = args.count > 1 ? args[1] : "/Applications/AltTab.app/Contents/MacOS/AltTab"
let outDir = URL(fileURLWithPath: args.count > 2 ? args[2] : "/tmp/alttab-verify")
let backdropStyle = args.count > 3 ? args[3] : "stripes"
// how much of the screen around the panel is captured; its top strip is the control area
let margin = CGFloat(40)
// stays clear of the tiles: on macOS 26+ the thumbnails style pads the panel by 28pt
let paddingBand = (from: CGFloat(8), to: CGFloat(18))
// stays clear of the panel's rounded corners (43pt radius on macOS 26+)
let cornerInset = CGFloat(60)
let changedChannelDelta = 24

final class BackdropView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        bounds.fill()
        guard backdropStyle == "stripes" else { return }
        NSColor.black.setFill()
        stride(from: CGFloat(0), to: bounds.width, by: 16).forEach { NSRect(x: $0, y: 0, width: 4, height: bounds.height).fill() }
    }
}

@discardableResult
func run(_ path: String, _ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    do { try process.run() } catch { return -1 }
    process.waitUntilExit()
    return process.terminationStatus
}

/// `rect` is in global points with a top-left origin, like `CGWindowListCopyWindowInfo` bounds; screens above or
/// left of the main one have negative coordinates, which `screencapture -R` accepts.
func capture(_ name: String, _ rect: CGRect) -> CGImage? {
    let url = outDir.appendingPathComponent(name)
    let region = "\(Int(rect.minX)),\(Int(rect.minY)),\(Int(rect.width)),\(Int(rect.height))"
    guard run("/usr/sbin/screencapture", ["-x", "-R", region, url.path]) == 0,
          let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

/// The biggest on-screen window AltTab owns while the switcher is up: the switcher panel itself.
func switcherFrame() -> CGRect? {
    guard let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
    return infos
        .filter { $0[kCGWindowOwnerName as String] as? String == "AltTab" }
        .compactMap { ($0[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) } }
        .max { $0.width * $0.height < $1.width * $1.height }
}

func pixels(_ image: CGImage, _ rect: CGRect) -> [UInt8] {
    guard let crop = image.cropping(to: rect) else { return [] }
    var data = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
    data.withUnsafeMutableBytes { buffer in
        let context = CGContext(data: buffer.baseAddress, width: crop.width, height: crop.height, bitsPerComponent: 8,
                                bytesPerRow: crop.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
    }
    return data
}

/// Share of pixels where any colour channel moved by more than `changedChannelDelta`.
func changedShare(_ before: CGImage, _ after: CGImage, _ rect: CGRect) -> Double {
    let a = pixels(before, rect)
    let b = pixels(after, rect)
    guard !a.isEmpty, a.count == b.count else { return .nan }
    let changed = stride(from: 0, to: a.count, by: 4).filter { i in
        (0..<3).contains { abs(Int(a[i + $0]) - Int(b[i + $0])) > changedChannelDelta }
    }.count
    return Double(changed) / Double(a.count / 4)
}

func toPixels(_ rect: CGRect, _ scale: CGFloat) -> CGRect {
    CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale).integral
}

func percent(_ share: Double) -> String { String(format: "%.1f%%", share * 100) }

func verify() -> Int32 {
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    Thread.sleep(forTimeInterval: 1)
    guard run(binary, ["--show=0"]) == 0 else { print("\(binary) --show=0 failed: is that AltTab running?"); return 2 }
    Thread.sleep(forTimeInterval: 1.2)
    guard let frame = switcherFrame() else { run(binary, ["--hide"]); print("the switcher did not appear"); return 2 }
    let area = frame.insetBy(dx: -margin, dy: -margin)
    let during = capture("panel.png", area)
    run(binary, ["--hide"])
    Thread.sleep(forTimeInterval: 0.6)
    guard let during, let hidden = capture("hidden.png", area) else { print("could not capture the screen"); return 2 }
    let scale = CGFloat(during.width) / area.width
    let width = frame.width - cornerInset * 2
    let bandHeight = paddingBand.to - paddingBand.from
    let top = CGRect(x: margin + cornerInset, y: margin + paddingBand.from, width: width, height: bandHeight)
    let bottom = CGRect(x: margin + cornerInset, y: margin + frame.height - paddingBand.to, width: width, height: bandHeight)
    let control = CGRect(x: margin + cornerInset, y: 4, width: width, height: margin - 12)
    let topShare = changedShare(hidden, during, toPixels(top, scale))
    let bottomShare = changedShare(hidden, during, toPixels(bottom, scale))
    let controlShare = changedShare(hidden, during, toPixels(control, scale))
    print("switcher frame (pt): \(frame)")
    print("pixels changed: top padding \(percent(topShare)), bottom padding \(percent(bottomShare)), control area \(percent(controlShare))")
    guard controlShare < 0.01 else { print("UNRELIABLE: the area around the panel changed during the run"); return 2 }
    let worst = max(topShare, bottomShare)
    if worst < 0.02 { print("PASS: the panel draws no background"); return 0 }
    if worst > 0.5 { print("FAIL: the panel draws a background over what is behind it"); return 1 }
    print("UNRELIABLE: partial change in the padding; inspect \(outDir.path)/panel.png")
    return 2
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let backdrops = NSScreen.screens.map { screen -> NSWindow in
    let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.level = .floating
    window.contentView = BackdropView()
    return window
}
if backdropStyle != "none" { backdrops.forEach { $0.orderFrontRegardless() } }
DispatchQueue.global().async {
    let code = verify()
    DispatchQueue.main.async { exit(code) }
}
app.run()
