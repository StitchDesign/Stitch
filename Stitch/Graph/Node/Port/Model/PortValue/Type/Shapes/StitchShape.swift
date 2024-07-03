//
//  StitchShape.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct StitchShape: View {
    var stroke: LayerStrokeData = .defaultEmptyStroke
    let color: Color
    let opacity: Double
    let layerNodeSize: CGSize
    let previewShapeKind: PreviewShapeLayerKind
    let usesAbsoluteCoordinates: Bool

    var body: some View {
        switch previewShapeKind {
            
        case .pathBased(let customShape):
            CustomShapeView(
                shape: customShape,
                shapeLayerNodeColor: color.opacity(opacity),
                shapeLayerNodeSize: layerNodeSize,
                strokeData: stroke,
                usesAbsoluteCoordinates: usesAbsoluteCoordinates)
            
        case .swiftUIRectangle(let cornerRadius):
            RoundedRectangle(cornerRadius: cornerRadius)
                .createStitchShape(stroke,
                                   color,
                                   opacity)
            
        case .swiftUIOval:
            Ellipse()
                .createStitchShape(stroke,
                                   color,
                                   opacity)
            
        case .none:
            EmptyView()
        }
    }
}
