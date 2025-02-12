//
//  ColorUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/4/22.
//
import SwiftUI
import UIKit


extension Color {
    static let trueColor = Stitch.trueColor
    static let falseColor = Stitch.falseColor

    static let assortedColors: Set<Color> = Set([
        .blue,
        .red,
        .gray,
        .green,
        .purple,
        .pink,
        .orange,
        .yellow,
        .cyan,
        .black,
        .brown,
        .indigo,
        .mint,
        .teal
    ])

    static var randomAssortedColor: Color {
        Self.assortedColors.randomElement() ?? .falseColor
    }
}
