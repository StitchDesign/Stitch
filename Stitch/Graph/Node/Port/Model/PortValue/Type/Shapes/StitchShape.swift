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

    // For outside-stroke on non-custom shapes
    let position: StitchPosition // adjusted position
    let size: CGSize // non-scaled size

    var body: some View {
        switch previewShapeKind {

        case .pathBased(let customShape):
            return CustomShapeView(
                shape: customShape,
                shapeLayerNodeColor: color.opacity(opacity),
                shapeLayerNodeSize: layerNodeSize,
                strokeData: stroke,
                usesAbsoluteCoordinates: usesAbsoluteCoordinates)
                .eraseToAnyView()

        case .swiftUIRectangle(let cornerRadius):
            return RoundedRectangle(cornerRadius: cornerRadius)
                .applyStrokeToShape(stroke,
                                    color,
                                    opacity,
                                    position: position,
                                    size: size)
                .eraseToAnyView()

        case .swiftUIOval:
            return Ellipse()
                .applyStrokeToShape(stroke,
                                    color,
                                    opacity,
                                    position: position,
                                    size: size)
                .eraseToAnyView()

        case .none:
            return EmptyView()
                .eraseToAnyView()
        }
    }
}
