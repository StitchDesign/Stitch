//
//  CustomShapeView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct CustomShapeView: View {

    var shape: CustomShape // aka `Shapes`
    var shapeLayerNodeColor: Color // fill color
    var shapeLayerNodeSize: CGSize
    var strokeData: LayerStrokeData

    var usesAbsoluteCoordinates: Bool

    var body: some View {

        let baseFrame = shape.baseFrame
        let maskShape = holeShapeMask(shapes: shape.shapes,
                                      smallestShape: baseFrame.size)

        // TODO: finalize handling of scale with the stroke-line
        let xScale = usesAbsoluteCoordinates
            ? 1
            : shape.xScale(shapeLayerNodeSize)

        let yScale = usesAbsoluteCoordinates
            ? 1
            : shape.yScale(shapeLayerNodeSize)

        let strokeScale = xScale > yScale ? xScale : yScale

        let xOffset = usesAbsoluteCoordinates ? 0 : shape.xOffset
        let yOffset = usesAbsoluteCoordinates ? 0 : shape.yOffset

        CustomShapeInnerView(stroke: strokeData.stroke,
                             xOffset: xOffset,
                             yOffset: yOffset,
                             // Setting max fixes warning
                             xScale: max(xScale, 0),
                             yScale: max(yScale, 0),
                             maskShape: maskShape,
                             strokeScale: strokeScale,
                             filledView: filledView,
                             trimmedView: trimmedView)
    }

    @ViewBuilder
    func baseView(_ color: Color) -> some View {
        Rectangle()
            .fill(color)
            .frame(self.shape.baseFrame.size)
    }

    @ViewBuilder
    func filledView(maskShape: Path) -> some View {
        baseView(shapeLayerNodeColor)
            .frame(self.shape.baseFrame.size)
            .mask(maskShape.fill(style: .init(eoFill: true)))
    }

    @ViewBuilder
    func trimmedView(maskShape: Path,
                     strokeScale: CGFloat) -> some View {
        baseView(strokeData.color)
            .frame(self.shape.baseFrame.size)
            .mask(maskShape
                    // stroke progress: 0 -> 1
                    .trimmedPath(from: strokeData.strokeStart,
                                 to: strokeData.strokeEnd)
                    // stroke width
                    .strokedPath(.init(lineWidth: strokeData.width / strokeScale)))
    }
}

struct CustomShapeInnerView<T: View, U: View>: View {
    let stroke: LayerStroke
    let xOffset: CGFloat
    let yOffset: CGFloat
    let xScale: CGFloat
    let yScale: CGFloat
    let maskShape: Path
    let strokeScale: CGFloat

    @ViewBuilder var filledView: (Path) -> T
    @ViewBuilder var trimmedView: (Path, CGFloat) -> U

    var body: some View {
        ZStack {
            filledView(maskShape)

            if stroke != .none {
                trimmedView(maskShape, strokeScale)
            }
        }
        .offset(x: xOffset, y: yOffset)
        .scaleEffect(x: xScale, y: yScale)
    }
}
