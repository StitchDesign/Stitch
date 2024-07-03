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
struct ApplyStroke: ViewModifier {
    
    let stroke: LayerStrokeData
    
    @ViewBuilder
    func body(content: Content) -> some View {
        
        switch stroke.stroke {
                        
        case .none:
            content
            
        case .inside, .outside:
            
//            let strokeWidth = stroke.width
//            let strokeStart = stroke.strokeStart
//            let strokeEnd = stroke.strokeEnd
            
//            let strokedShape = shape
//            let strokedShape = Rectangle()
//                // applying .trim to filled-shape would affect the shape itself
//                .trim(from: strokeStart, to: strokeEnd)
//                .fill(.clear)
//                .stroke(stroke.color,
//                        style: .init(lineWidth: strokeWidth,
//                                     lineCap: stroke.strokeLineCap.toCGLineCap,
//                                     lineJoin: stroke.strokeLineJoin.toCGLineJoin))
//            
//            // Using padding means we don't need to know the size of the view receiving the `.stroke`.
//            // negative padding = moves stroke completely outside
//            // positive padding = moves stroke completely inside
//            let strokeWidthPadding = stroke.stroke == .outside ? -strokeWidth : strokeWidth
            
            let strokedShape = Rectangle().stitchStroke(stroke)
            
            content.overlay {
                strokedShape // .padding(strokeWidthPadding/2)
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
        
        return strokedShape.padding(strokeWidthPadding/2)
    }
    
    // Note: SwiftUI cannot combine `.strokeBorder` with `.fill` or `.trim`; so we prefer `.stroke` instead
    // fka `applyStrokeToShape`
    func createStitchShape(_ stroke: LayerStrokeData,
                           _ color: Color,
                           _ opacity: Double,
                           size: CGSize) -> some View {
        
        let filledShape = self.fill(color.opacity(opacity))
        let strokedShape = self.stitchStroke(stroke)
        
        return filledShape.overlay { strokedShape }
    
        
        
//        let shape = self
//
//        let strokeWidth = stroke.width
//        let strokeStart = stroke.strokeStart
//        let strokeEnd = stroke.strokeEnd
                
//        let filledShape = shape
//            .fill(color.opacity(opacity))
        
//        filledShape
        
        // can apply .frame LATER
//            .frame(width: size.width, height: size.height)
        
            
        
        
//        return filledShape.modifier(ApplyStroke(stroke: stroke))
//
//        
//        let strokedShape = shape
//            // applying .trim to filled-shape would affect the shape itself
//            .trim(from: strokeStart, to: strokeEnd)
//            .fill(.clear)
//            .stroke(stroke.color,
//                    style: .init(lineWidth: strokeWidth,
//                                 lineCap: stroke.strokeLineCap.toCGLineCap,
//                                 lineJoin: stroke.strokeLineJoin.toCGLineJoin))
//        
//        switch stroke.stroke {
//
//        case .inside:
//            return filledShape
//                // .overlay the stroke-shape over the filled-shape, so that inside-border is not covered up
//                .overlay {
//                    strokedShape
//                    // - strokeWidth = stroke completely inside
//                        .frame(width: size.width - strokeWidth,
//                               height: size.height - strokeWidth)
//                }
//                .eraseToAnyView()
//            
//        case .outside:
//            return filledShape
//                .overlay {
//                    strokedShape
//                    // + strokeWidth = stroke completely outside
//                        .frame(width: size.width + strokeWidth,
//                               height: size.height + strokeWidth)
//                }
//                .eraseToAnyView()
//            
//        case .none:
//            // TODO: why is .fill broken in some cases for path-based shapes?
//            return shape
//                .fill(color)
//                .opacity(opacity)
//                .eraseToAnyView()
//
//        } // switch stroke.stroke
    }
}
