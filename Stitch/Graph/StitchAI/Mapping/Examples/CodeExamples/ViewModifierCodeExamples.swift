//
//  ViewModifierCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/3/25.
//

import Foundation
import SwiftUI


struct ViewModifierCodeExamples {
    
    static let colorInitInFillModifier = MappingCodeExample(
        title: "colorInitInFillModifier",
        code:
"""
Rectangle()
    .fill(Color(red: Double.random(in: 0...1),
                green: Double.random(in: 0...1),
                blue: Double.random(in: 0...1)))
    .frame(width: 100, height: 100)
"""
    )
    
    static let paddingNoArgsModifier = MappingCodeExample(
        title: "padding no args",
        code:
"""
Ellipse().padding()
"""
    )
    
}
