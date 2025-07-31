//
//  FontCodeExamples.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/31/25.
//

import Foundation
import SwiftUI

struct FontCodeExamples {
    
    // MARK: - Basic Font Modifier Examples
    
    static let systemFontBody = MappingCodeExample(
        title: "System Font - Body",
        code:
"""
Text("Hello World")
    .font(.body)
"""
    )
    
    static let systemFontHeadline = MappingCodeExample(
        title: "System Font - Headline",
        code:
"""
Text("Important Title")
    .font(.headline)
"""
    )
    
    static let systemFontLargeTitle = MappingCodeExample(
        title: "System Font - Large Title",
        code:
"""
Text("Big Header")
    .font(.largeTitle)
"""
    )
    
    static let systemFontCaption = MappingCodeExample(
        title: "System Font - Caption",
        code:
"""
Text("Small note")
    .font(.caption)
"""
    )
    
    // MARK: - Custom System Font Examples
    
    static let customSystemFont = MappingCodeExample(
        title: "Custom System Font",
        code:
"""
Text("Custom Font")
    .font(.system(size: 24))
"""
    )
    
    static let customSystemFontWithWeight = MappingCodeExample(
        title: "Custom System Font with Weight",
        code:
"""
Text("Bold Text")
    .font(.system(size: 18, weight: .bold))
"""
    )
    
    static let customSystemFontWithDesign = MappingCodeExample(
        title: "Custom System Font with Design",
        code:
"""
Text("Rounded Font")
    .font(.system(size: 20, design: .rounded))
"""
    )
    
    static let customSystemFontComplete = MappingCodeExample(
        title: "Custom System Font - Complete",
        code:
"""
Text("Complete Example")
    .font(.system(size: 22, weight: .semibold, design: .serif))
"""
    )
    
    // MARK: - Font Weight Modifier Examples
    
    static let fontWeightRegular = MappingCodeExample(
        title: "Font Weight - Regular",
        code:
"""
Text("Regular Weight")
    .fontWeight(.regular)
"""
    )
    
    static let fontWeightBold = MappingCodeExample(
        title: "Font Weight - Bold",
        code:
"""
Text("Bold Weight")
    .fontWeight(.bold)
"""
    )
    
    static let fontWeightLight = MappingCodeExample(
        title: "Font Weight - Light",
        code:
"""
Text("Light Weight")
    .fontWeight(.light)
"""
    )
    
    static let fontWeightHeavy = MappingCodeExample(
        title: "Font Weight - Heavy",
        code:
"""
Text("Heavy Weight")
    .fontWeight(.heavy)
"""
    )
    
    // MARK: - Font Design Modifier Examples
    
    static let fontDesignDefault = MappingCodeExample(
        title: "Font Design - Default",
        code:
"""
Text("Default Design")
    .fontDesign(.default)
"""
    )
    
    static let fontDesignRounded = MappingCodeExample(
        title: "Font Design - Rounded",
        code:
"""
Text("Rounded Design")
    .fontDesign(.rounded)
"""
    )
    
    static let fontDesignMonospaced = MappingCodeExample(
        title: "Font Design - Monospaced",
        code:
"""
Text("Monospaced Design")
    .fontDesign(.monospaced)
"""
    )
    
    static let fontDesignSerif = MappingCodeExample(
        title: "Font Design - Serif",
        code:
"""
Text("Serif Design")
    .fontDesign(.serif)
"""
    )
    
    // MARK: - Combined Font Modifier Examples
    
    static let combinedFontModifiers = MappingCodeExample(
        title: "Combined Font Modifiers",
        code:
"""
Text("Combined Styling")
    .font(.title2)
    .fontWeight(.medium)
    .fontDesign(.rounded)
"""
    )
    
    static let fontWithColorAndWeight = MappingCodeExample(
        title: "Font with Color and Weight",
        code:
"""
Text("Styled Text")
    .font(.headline)
    .fontWeight(.bold)
    .foregroundColor(.blue)
"""
    )
    
    static let multilineTextWithFont = MappingCodeExample(
        title: "Multiline Text with Font",
        code:
"""
Text("This is a longer text that demonstrates font styling across multiple lines")
    .font(.body)
    .fontWeight(.regular)
    .fontDesign(.default)
"""
    )
    
    // MARK: - Edge Case Examples
    
    static let emptyTextWithFont = MappingCodeExample(
        title: "Empty Text with Font",
        code:
"""
Text("")
    .font(.body)
    .fontWeight(.bold)
"""
    )
    
    static let textWithMultipleWeights = MappingCodeExample(
        title: "Text with Multiple Font Weights (Last Wins)",
        code:
"""
Text("Weight Override")
    .fontWeight(.light)
    .fontWeight(.bold)
"""
    )
    
    static let textWithMultipleDesigns = MappingCodeExample(
        title: "Text with Multiple Font Designs (Last Wins)",
        code:
"""
Text("Design Override")
    .fontDesign(.serif)
    .fontDesign(.rounded)
"""
    )
    
    // MARK: - Complex Layout Examples
    
    static let stackWithDifferentFonts = MappingCodeExample(
        title: "Stack with Different Fonts",
        code:
"""
VStack {
    Text("Title")
        .font(.largeTitle)
        .fontWeight(.bold)
    
    Text("Subtitle")
        .font(.title2)
        .fontWeight(.medium)
    
    Text("Body text with more details")
        .font(.body)
        .fontDesign(.default)
    
    Text("Caption or note")
        .font(.caption)
        .fontWeight(.light)
        .foregroundColor(.gray)
}
"""
    )
    
    static let fontInScrollView = MappingCodeExample(
        title: "Font Styling in ScrollView",
        code:
"""
ScrollView {
    VStack(spacing: 16) {
        Text("Header")
            .font(.title)
            .fontWeight(.bold)
            .fontDesign(.rounded)
        
        Text("Content")
            .font(.body)
            .fontDesign(.default)
    }
}
"""
    )
}