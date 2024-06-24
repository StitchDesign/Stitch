//
//  StitchTheme.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/30/23.
//

import SwiftUI

struct StitchThemeData: Identifiable, Equatable, Codable, Hashable {
    var id = UUID()
    let edgeColor: Color
    let highlightedEdgeColor: Color

    // TODO: add associated file for app icon
    //    let appIconFileName: String
}

enum StitchTheme: String, CaseIterable, Codable, Equatable, Hashable {
    case purple = "Purple",
         mint = "Mint",
         red = "Red",
         orange = "Orange",
         pink = "Pink"

    static let defaultTheme = Self.purple

    var appIconName: String? {
        switch self {
        case .mint:
            return "AppIconMint"
        case .orange:
            return "AppIconOrange"
        case .pink:
            return "AppIconPink"
        default:
            // nil = default app icon
            return nil
        }
    }

    var themeData: StitchThemeData {
        switch self {
        case .purple:
            return StitchThemeData.purpleTheme
        case .mint:
            return StitchThemeData.mintTheme
        case .red:
            return StitchThemeData.redTheme
        case .orange:
            return StitchThemeData.orangeTheme
        case .pink:
            return StitchThemeData.pinkTheme
        }
    }
}

// TODO: if need light vs dark mode versions, can move into Assets
extension StitchThemeData {

    // AVAILABLE THEMES

    static let purpleTheme = StitchThemeData(
        edgeColor: StitchThemeData.STITCH_PURPLE_COLOR,
        highlightedEdgeColor: StitchThemeData.STITCH_PURPLE_HIGHLIGHTED_COLOR)

    static let mintTheme = StitchThemeData(
        edgeColor: StitchThemeData.STITCH_MINT_COLOR,
        highlightedEdgeColor: StitchThemeData.STITCH_MINT_HIGHLIGHTED_COLOR)

    static let redTheme = StitchThemeData(
        edgeColor: StitchThemeData.STITCH_EDGE_RED_COLOR,
        highlightedEdgeColor: StitchThemeData.STITCH_EDGE_RED_HIGHLIGHTED_COLOR)

    static let orangeTheme = StitchThemeData(
        edgeColor: StitchThemeData.STITCH_ORANGE_COLOR,
        highlightedEdgeColor: StitchThemeData.STITCH_ORANGE_HIGHLIGHTED_COLOR)

    static let pinkTheme = StitchThemeData(
        edgeColor: StitchThemeData.STITCH_PINK_COLOR,
        highlightedEdgeColor: StitchThemeData.STITCH_PINK_HIGHLIGHTED_COLOR)

    // THEME EDGE COLORS:

    // purple
    static let STITCH_PURPLE_COLOR = STITCH_PURPLE
    static let STITCH_PURPLE_HIGHLIGHTED_COLOR = Color(.highlightedEdge)

    // mint
    static let STITCH_MINT_HEX = "#38CB96"
    static let STITCH_MINT_COLOR = UIColor(hex: Self.STITCH_MINT_HEX)!.toColor
    static let STITCH_MINT_HIGHLIGHTED_HEX = "#5ED3A9" // highlighted
    static let STITCH_MINT_HIGHLIGHTED_COLOR = UIColor(hex: Self.STITCH_MINT_HIGHLIGHTED_HEX)!.toColor

    // red
    static let STITCH_EDGE_RED_HEX = "#E04040"
    static let STITCH_EDGE_RED_COLOR = UIColor(hex: Self.STITCH_EDGE_RED_HEX)!.toColor
    static let STITCH_EDGE_RED_HIGHLIGHTED_HEX = "#E46464" // highlighted
    static let STITCH_EDGE_RED_HIGHLIGHTED_COLOR = UIColor(hex: Self.STITCH_EDGE_RED_HIGHLIGHTED_HEX)!.toColor

    // orange
    static let STITCH_ORANGE_HEX = "#F17530"
    static let STITCH_ORANGE_COLOR = UIColor(hex: Self.STITCH_ORANGE_HEX)!.toColor
    static let STITCH_ORANGE_HIGHLIGHTED_HEX = "#F28F57" // highlighted
    static let STITCH_ORANGE_HIGHLIGHTED_COLOR = UIColor(hex: Self.STITCH_ORANGE_HIGHLIGHTED_HEX)!.toColor

    // pink
    static let STITCH_PINK_HEX = "#F8A7F0"
    static let STITCH_PINK_COLOR = UIColor(hex: Self.STITCH_PINK_HEX)!.toColor
    static let STITCH_PINK_HIGHLIGHTED_HEX = "#F7B7F1" // highlighted
    static let STITCH_PINK_HIGHLIGHTED_COLOR = UIColor(hex: Self.STITCH_PINK_HIGHLIGHTED_HEX)!.toColor
}

// #Preview {
//    AppThemes()
// }
