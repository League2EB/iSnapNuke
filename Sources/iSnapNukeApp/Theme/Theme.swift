import AppKit
import SwiftUI

enum iSnapNukeTheme {
    static let background = Color(lightHex: 0xFDFCFC, darkHex: 0x1A1417)
    static let foreground = Color(lightHex: 0x28151F, darkHex: 0xF6F4F5)
    static let card = Color(lightHex: 0xFFFFFF, darkHex: 0x271B22)
    static let primary = Color(lightHex: 0xDE83B4, darkHex: 0xDE82B3)
    static let primaryForeground = Color(hex: 0x0A0A0A)
    static let secondary = Color(lightHex: 0xAC6294, darkHex: 0xB06999)
    static let accent = Color(lightHex: 0x4D74BA, darkHex: 0x5A7DBF)
    static let accentForeground = Color.white
    static let muted = Color(lightHex: 0xF7F2F6, darkHex: 0x372531)
    static let mutedForeground = Color(lightHex: 0x846279, darkHex: 0xB398AB)
    static let border = Color(lightHex: 0xEBE0E6, darkHex: 0x432D39)
    static let destructive = Color(lightHex: 0xEF4444, darkHex: 0xDC2626)
}

extension Color {
    init(hex: UInt) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init(lightHex: UInt, darkHex: UInt) {
        self.init(
            nsColor: NSColor(
                name: nil,
                dynamicProvider: { appearance in
                    let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    return NSColor(
                        red: CGFloat((isDark ? darkHex : lightHex) >> 16 & 0xFF) / 255,
                        green: CGFloat((isDark ? darkHex : lightHex) >> 8 & 0xFF) / 255,
                        blue: CGFloat((isDark ? darkHex : lightHex) & 0xFF) / 255,
                        alpha: 1
                    )
                }
            )
        )
    }
}
