//
//  LayerTextview.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/3/22.
//

import SwiftUI
import StitchSchemaKit

// A wrapper for all our Text layers within the preview window.
// SwiftUI does not (yet) have a .justify text alignment option,
// so we use UIKit when textAlignment = .justify
struct LayerTextView: View {
    let value: String
    let color: Color
    let fontSize: LayerDimension
    let textAlignment: LayerTextAlignment
    let verticalAlignment: LayerTextVerticalAlignment
    let textDecoration: LayerTextDecoration
    let textFont: StitchFont

    var fontDesign: Font.Design {
        textFont.fontChoice.asFontDesign
    }
    
    var fontWeight: Font.Weight {
        textFont.fontWeight.asFontWeight
    }
    
    var body: some View {
        if getSwiftUIAlignment(textAlignment,
                               verticalAlignment).isDefined {
            Text(value)
                .modifier(StitchFontModifier(fontSize: fontSize,
                                             fontDesign: fontDesign,
                                             fontWeight: fontWeight))
                .foregroundColor(color)
                .underline(textDecoration.isUnderline, pattern: .solid)
                .strikethrough(textDecoration.isStrikethrough, pattern: .solid)
        } else {
            // TODO: do we still need this, or does SwiftUI now support text-justification?
            // UITextView's do not respect SwiftUI alignments
            JustifiedLayerTextView(
                text: value,
                color: color,
                font: UIFont.systemFont(ofSize: fontSize.asNumber))
                .fontDesign(fontDesign)
                .fontWeight(fontWeight)
                .underline(textDecoration.isUnderline, pattern: .solid)
                .strikethrough(textDecoration.isStrikethrough, pattern: .solid)
        }

    }
}

struct StitchFontModifier: ViewModifier {
    let fontSize: LayerDimension
    let fontDesign: Font.Design
    let fontWeight: Font.Weight
    
    var resizeFontByFrame: Bool {
        fontSize.isAuto || fontSize.isHug
    }
    
    func body(content: Content) -> some View {
        if resizeFontByFrame {
            content
                .modifier(FitSystemFont(fontDesign: fontDesign, 
                                        fontWeight: fontWeight))
        } else {
            content
                .font(.system(size: fontSize.asNumber,
                              weight: fontWeight,
                              design: fontDesign))
        }
    }
}

// https://stackoverflow.com/questions/57035746/how-to-scale-text-to-fit-parent-view-with-swiftui
struct FitSystemFont: ViewModifier {
    
    let fontDesign: Font.Design
    let fontWeight: Font.Weight
    
    var lineLimit: Int = 1
    var minimumScaleFactor: CGFloat = 0.01
    var percentage: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .font(
                    .system(size: min(geometry.size.width, geometry.size.height) * percentage,
                            weight: fontWeight,
                            design: fontDesign))
            
            // Not used?
//                .lineLimit(self.lineLimit)
            
                .minimumScaleFactor(self.minimumScaleFactor)
            // position within GeometryReader, not Preview Winodw
                .position(x: geometry.frame(in: .local).midX,
                          y: geometry.frame(in: .local).midY)
        }
    }
}
