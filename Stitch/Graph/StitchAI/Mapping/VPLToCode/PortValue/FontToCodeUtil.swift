//
//  FontToCodeUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/25.
//

import SwiftUI

/// Decomposes a StitchFont into the best SwiftUI modifier representation
/// Uses Approach 3 (Hybrid): intelligent decomposition for better SwiftUI code
///
/// Precedence Rules:
/// 1. .font() takes precedence when we can map to standard SwiftUI system fonts
/// 2. Fallback to .system(size:, weight:, design:) for complex combinations
/// 3. Individual .fontDesign() and .fontWeight() modifiers are handled separately during parsing
func decomposeFontToModifiers(_ stitchFont: StitchFont) -> StrictViewModifier? {
    // Strategy: Create the most appropriate SwiftUI font modifier based on the StitchFont
    // We'll prioritize .font() for system fonts with common sizes
    
    let fontChoice = stitchFont.fontChoice
    let fontWeight = stitchFont.fontWeight
    
    // Try to map to a standard SwiftUI system font first
    if let systemFont = mapStitchFontToSwiftUISystemFont(fontChoice, fontWeight) {
        let fontArg = SyntaxViewModifierArgumentType.memberAccess(
            SyntaxViewMemberAccess(base: nil, property: String(systemFont.dropFirst())) // Remove leading dot
        )
        return .font(FontViewModifier(font: fontArg))
    }
    
    // Fallback: Create .fontDesign() and .fontWeight() modifiers separately
    // This provides more granular control and is more idiomatic for complex fonts
    
    // For now, create a composite font modifier
    // Future enhancement: return multiple modifiers
    let designString = mapStitchFontChoiceToSwiftUIDesign(fontChoice)
    let weightString = mapStitchFontWeightToSwiftUIWeight(fontWeight)
    
    // Create a combined font specification directly as syntax
    let combinedFont = ".system(size: 17, weight: \(weightString), design: \(designString))"
    let fontArg = SyntaxViewModifierArgumentType.simple(
        SyntaxViewSimpleData(value: combinedFont, syntaxKind: .literal(.memberAccess))
    )
    
    return .font(FontViewModifier(font: fontArg))
}

// MARK: - StitchFont to SwiftUI Mapping Functions

func mapStitchFontToSwiftUISystemFont(_ fontChoice: StitchFontChoice, _ fontWeight: StitchFontWeight) -> String? {
    // Map common combinations to standard SwiftUI system fonts
    switch (fontChoice, fontWeight) {
    case (.sf, .SF_regular):
        return ".body"
    case (.sf, .SF_bold):
        return ".headline"  // headline is bold by default
    case (.sf, .SF_light):
        return ".subheadline"
    default:
        return nil  // Use fallback approach
    }
}

func mapStitchFontChoiceToSwiftUIDesign(_ fontChoice: StitchFontChoice) -> String {
    switch fontChoice {
    case .sf:
        return ".default"
    case .sfMono:
        return ".monospaced"
    case .sfRounded:
        return ".rounded"
    case .newYorkSerif:
        return ".serif"
    }
}

func mapStitchFontWeightToSwiftUIWeight(_ weight: StitchFontWeight) -> String {
    // Extract the actual weight from the prefixed enum case
    let weightString = String(describing: weight)
    if let underscoreIndex = weightString.lastIndex(of: "_") {
        let actualWeight = String(weightString[weightString.index(after: underscoreIndex)...])
        return ".\(actualWeight)"
    }
    return ".regular"  // fallback
}
