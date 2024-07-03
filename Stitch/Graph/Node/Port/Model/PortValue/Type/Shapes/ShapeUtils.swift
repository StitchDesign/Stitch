//
//  ShapeUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/9/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Always applied BEFORE .frame and .position
// Intended for strokes on non-Shape layers.
struct ApplyStroke: ViewModifier {
    
    let stroke: LayerStrokeData
    
    @ViewBuilder
    func body(content: Content) -> some View {
        
        switch stroke.stroke {
                        
        case .none:
            content
            
        case .inside, .outside:
            content.overlay {
                //
                Rectangle().stitchStroke(stroke)
            }
        }
    }
}



extension InsettableShape {
    
    func stitchStroke(_ stroke: LayerStrokeData) -> some View {
        
        let strokeWidth = stroke.width
        
        let strokedShape = self
            .trim(from: stroke.strokeStart,
                  to: stroke.strokeEnd)
            .fill(.clear)
            .stroke(stroke.color,
                    style: .init(lineWidth: strokeWidth,
                                 lineCap: stroke.strokeLineCap.toCGLineCap,
                                 lineJoin: stroke.strokeLineJoin.toCGLineJoin))
        
        let strokeWidthPadding = stroke.stroke == .outside ? -strokeWidth : strokeWidth
        
        // Use .padding to move the stroke completely inside or outside the shape.
        return strokedShape.padding(strokeWidthPadding/2)
    }
    
    // Note: SwiftUI cannot combine `.strokeBorder` with `.fill` or `.trim`; so we prefer `.stroke` instead
    // fka `applyStrokeToShape`
    func createStitchShape(_ stroke: LayerStrokeData,
                           _ color: Color,
                           _ opacity: Double) -> some View {
        
        let filledShape = self.fill(color.opacity(opacity))
        let strokedShape = self.stitchStroke(stroke)
        
        return filledShape.overlay { strokedShape }
    }
}
