//
//  ModifiedNavigationKeyTests.swift
//
//  Arrows, Home and End with Shift, Option or Control outside the kitty
//  keyboard protocol reach the program as xterm sends them,
//  CSI 1 ; modifiers final, whether or not Option is Meta, except that
//  Option-Left and Option-Right alone send Esc b and Esc f while it is.
//
#if os(macOS)
import AppKit
import Carbon.HIToolbox
import Testing
@testable import SwiftTerm

@MainActor
final class ModifiedNavigationKeyTests {

    private final class CapturingDelegate: TerminalViewDelegate {
        var sent: [UInt8] = []
        func send(source: TerminalView, data: ArraySlice<UInt8>) { sent.append(contentsOf: data) }
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func scrolled(source: TerminalView, position: Double) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func clipboardRead(source: TerminalView) -> Data? { nil }
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
    }

    private enum Key: CaseIterable {
        case up, down, right, left, home, end

        var functionKey: Int {
            switch self {
            case .up: return NSUpArrowFunctionKey
            case .down: return NSDownArrowFunctionKey
            case .right: return NSRightArrowFunctionKey
            case .left: return NSLeftArrowFunctionKey
            case .home: return NSHomeFunctionKey
            case .end: return NSEndFunctionKey
            }
        }

        var keyCode: Int {
            switch self {
            case .up: return kVK_UpArrow
            case .down: return kVK_DownArrow
            case .right: return kVK_RightArrow
            case .left: return kVK_LeftArrow
            case .home: return kVK_Home
            case .end: return kVK_End
            }
        }

        var final: String {
            switch self {
            case .up: return "A"
            case .down: return "B"
            case .right: return "C"
            case .left: return "D"
            case .home: return "H"
            case .end: return "F"
            }
        }
    }

    private func keyEvent(_ key: Key, _ modifiers: NSEvent.ModifierFlags) -> NSEvent {
        let character = String(UnicodeScalar(UInt32(key.functionKey))!)
        // macOS marks these keys as function keys, and arrows as keypad keys too.
        return NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers.union([.function, .numericPad]),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: character,
            charactersIgnoringModifiers: character,
            isARepeat: false,
            keyCode: UInt16(key.keyCode))!
    }

    private func sentBytes(for key: Key, _ modifiers: NSEvent.ModifierFlags,
                           optionAsMetaKey: Bool = true, setup: String = "") -> String {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 160))
        let delegate = CapturingDelegate()
        view.terminalDelegate = delegate
        view.optionAsMetaKey = optionAsMetaKey
        view.getTerminal().feed(text: setup)
        view.keyDown(with: keyEvent(key, modifiers))
        return String(decoding: delegate.sent, as: UTF8.self)
    }

    @Test func everyModifierCombinationIsSentAsXtermDoes() {
        let combinations: [(NSEvent.ModifierFlags, Int)] = [
            ([.shift], 2), ([.option], 3), ([.shift, .option], 4), ([.control], 5),
            ([.shift, .control], 6), ([.option, .control], 7), ([.shift, .option, .control], 8),
        ]
        for optionAsMetaKey in [true, false] {
            for (modifiers, parameter) in combinations {
                for key in Key.allCases {
                    // Option-Left and Option-Right alone keep Esc b and Esc f while Option is Meta; see the test below.
                    if optionAsMetaKey, modifiers == [.option], key == .left || key == .right { continue }
                    #expect(sentBytes(for: key, modifiers, optionAsMetaKey: optionAsMetaKey)
                            == "\u{1b}[1;\(parameter)\(key.final)",
                            "\(key) with \(modifiers), Option as Meta \(optionAsMetaKey)")
                }
            }
        }
    }

    @Test func shiftLeftIsSentInApplicationCursorModeToo() {
        #expect(sentBytes(for: .left, [.shift], setup: "\u{1b}[?1h") == "\u{1b}[1;2D")
    }

    @Test func optionLeftAndRightAloneStayEmacsWordMotionWhileOptionIsMeta() {
        #expect(sentBytes(for: .left, [.option]) == "\u{1b}b")
        #expect(sentBytes(for: .right, [.option]) == "\u{1b}f")
        #expect(sentBytes(for: .left, [.option], optionAsMetaKey: false) == "\u{1b}[1;3D")
    }

    @Test func keysWithoutModifiersOrWithCommandKeepTheirOwnHandling() {
        let view = TerminalView(frame: CGRect(x: 0, y: 0, width: 320, height: 160))
        for key in Key.allCases {
            #expect(view.modifiedNavigationKeySequence(for: keyEvent(key, [])) == nil)
            #expect(view.modifiedNavigationKeySequence(for: keyEvent(key, [.command, .shift])) == nil)
        }
    }
}
#endif
