//
//  ColorContrastTests.swift
//
#if os(macOS)
import AppKit
import Foundation
import Testing

@testable import SwiftTerm

final class ColorContrastTests {
    private let white = ColorContrast.RGB.white
    private let black = ColorContrast.RGB.black

    @Test func colorThatAlreadyReachesTheRatioIsUnchanged() {
        let darkGray = ColorContrast.RGB(red: 0.2, green: 0.2, blue: 0.2)
        #expect(ColorContrast.adjusted(darkGray, toReach: 4.5, against: white) == darkGray)
    }

    @Test func lightTextOnLightBackgroundDarkensJustEnough() {
        let nearWhite = ColorContrast.RGB(red: 0.97, green: 0.97, blue: 0.95)
        let adjusted = ColorContrast.adjusted(nearWhite, toReach: 4.5, against: white)
        let ratio = ColorContrast.ratio(adjusted, white)
        #expect(ratio >= 4.5)
        #expect(ratio < 4.6)
        #expect(ColorContrast.relativeLuminance(adjusted) < ColorContrast.relativeLuminance(nearWhite))
    }

    @Test func darkTextOnDarkBackgroundLightensJustEnough() {
        let background = ColorContrast.RGB(red: 0.05, green: 0.07, blue: 0.09)
        let dimBlue = ColorContrast.RGB(red: 0.1, green: 0.15, blue: 0.3)
        let adjusted = ColorContrast.adjusted(dimBlue, toReach: 4.5, against: background)
        let ratio = ColorContrast.ratio(adjusted, background)
        #expect(ratio >= 4.5)
        #expect(ratio < 4.6)
        // The hue survives: blue stays the strongest component.
        #expect(adjusted.blue > adjusted.red)
        #expect(adjusted.blue > adjusted.green)
    }

    @Test func textCrossesToTheOtherSideWhenItsOwnSideCannotReachTheRatio() {
        // Near-black text on a dark gray that even black can't reach 4.5 against.
        let background = ColorContrast.RGB(red: 0.3, green: 0.3, blue: 0.3)
        #expect(ColorContrast.ratio(black, background) < 4.5)
        let nearBlack = ColorContrast.RGB(red: 0.25, green: 0.25, blue: 0.25)
        let adjusted = ColorContrast.adjusted(nearBlack, toReach: 4.5, against: background)
        #expect(ColorContrast.ratio(adjusted, background) >= 4.5)
        #expect(ColorContrast.relativeLuminance(adjusted) > ColorContrast.relativeLuminance(background))
    }

    @Test func unreachableRatioGivesTheMostContrastAvailable() {
        let background = ColorContrast.RGB(red: 0.46, green: 0.46, blue: 0.46)
        let adjusted = ColorContrast.adjusted(background, toReach: 21, against: background)
        let best = max(ColorContrast.ratio(black, background), ColorContrast.ratio(white, background))
        #expect(abs(ColorContrast.ratio(adjusted, background) - best) < 0.0001)
    }

    @MainActor
    @Test func terminalViewAdjustsTextButNotBlockElements() throws {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 400, height: 200))
        view.nativeBackgroundColor = .white
        view.nativeForegroundColor = .black
        view.feed(text: "\u{1B}[38;2;250;250;250mA\u{2588}\u{1B}[2;38;2;120;120;120mB\u{1B}[0m")
        let terminal = view.getTerminal()
        let text = try #require(terminal.getCharData(col: 0, row: 0))
        let dimText = try #require(terminal.getCharData(col: 2, row: 0))

        let unchanged = try #require(view.getAttributes(text.attribute, withUrl: false))
        #expect(contrast(unchanged[.foregroundColor], .white) < 1.1)

        view.minimumContrastRatio = 4.5
        let attributes = try #require(view.getAttributes(text.attribute, withUrl: false))
        #expect(contrast(attributes[.foregroundColor], .white) >= 4.5)
        // Block elements are drawn in the color the program chose.
        #expect(contrast(attributes[SwiftTermShapeColorKey], .white) < 1.1)
        let dimAttributes = try #require(view.getAttributes(dimText.attribute, withUrl: false))
        #expect(contrast(dimAttributes[.foregroundColor], .white) >= 4.5)
    }

    private func contrast(_ value: Any?, _ background: NSColor) -> Double {
        func components(_ color: NSColor) -> ColorContrast.RGB {
            let srgb = color.usingColorSpace(.sRGB)!
            return ColorContrast.RGB(red: Double(srgb.redComponent), green: Double(srgb.greenComponent), blue: Double(srgb.blueComponent))
        }
        guard let color = value as? NSColor else { return 0 }
        return ColorContrast.ratio(components(color), components(background))
    }
}
#endif
