//
//  ShapeUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/9/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension InsettableShape {
    // Note: SwiftUI cannot combine `.strokeBorder` with `.fill` or `.trim`; so we prefer `.stroke` instead
    func applyStrokeToShape(_ stroke: LayerStrokeData,
                            _ color: Color,
                            _ opacity: Double,
                            position: StitchPosition,
                            size: CGSize) -> AnyView {

        let shape = self

        let strokeWidth = stroke.width
        let strokeStart = stroke.strokeStart
        let strokeEnd = stroke.strokeEnd
                
        let filledShape = shape
            .fill(color.opacity(opacity))
            .frame(width: size.width, height: size.height)
        
        let strokedShape = shape
            // applying .trim to filled-shape would affect the shape itself
            .trim(from: strokeStart, to: strokeEnd)
            .fill(.clear)
            .stroke(stroke.color,
                    style: .init(lineWidth: strokeWidth,
                                 lineCap: stroke.strokeLineCap.toCGLineCap,
                                 lineJoin: stroke.strokeLineJoin.toCGLineJoin))
        
        switch stroke.stroke {

        case .inside:
            return filledShape
                // .overlay the stroke-shape over the filled-shape, so that inside-border is not covered up
                .overlay {
                    strokedShape
                    // - strokeWidth = stroke completely inside
                        .frame(width: size.width - strokeWidth,
                               height: size.height - strokeWidth)
                }
                .eraseToAnyView()
            
        case .outside:
            return filledShape
                .overlay {
                    strokedShape
                    // + strokeWidth = stroke completely outside
                        .frame(width: size.width + strokeWidth,
                               height: size.height + strokeWidth)
                }
                .eraseToAnyView()
            
        case .none:
            // TODO: why is .fill broken in some cases for path-based shapes?
            return shape
                .fill(color)
                .opacity(opacity)
                .eraseToAnyView()

        } // switch stroke.stroke
    }
}
