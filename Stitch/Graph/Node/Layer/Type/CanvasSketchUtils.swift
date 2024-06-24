//
//  CanvasSketchLayerNodeUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/2/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// `Array<DrawingViewLine>` = lines for a single canvas drawing,
// so a loop of canvas drawings is `Array<Array<DrawingViewLine>>`
typealias DrawingViewLines = [DrawingViewLine]

struct DrawingViewLine: Identifiable, Equatable, Hashable {
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
    let id = UUID()
}

struct DrawingViewHelpers {

    static func createPath(for points: [CGPoint]) -> Path {
        var path = Path()

        if let firstPoint = points.first {
            path.move(to: firstPoint)
        }

        for index in 1..<points.count {
            let mid = calculateMidPoint(points[index - 1], points[index])
            path.addQuadCurve(to: mid, control: points[index - 1])
        }

        if let last = points.last {
            path.addLine(to: last)
        }

        return path
    }

    static func calculateMidPoint(_ point1: CGPoint, _ point2: CGPoint) -> CGPoint {
        CGPoint(x: (point1.x + point2.x)/2, y: (point1.y + point2.y)/2)
    }
}

struct CanvasSketchLayerNodeHelpers {

    static let defaultLineColor: Color = .black

    static let defaultLineWidth: CGFloat = 4.0

    static let starterLines: [DrawingViewLine] = [
        DrawingViewLine(points: [CGPoint(x: 443.953125, y: 289.984375)],
                        color: .black,
                        lineWidth: 6.0),
        DrawingViewLine(points: [CGPoint(x: 443.953125, y: 289.984375)],
                        color: .black,
                        lineWidth: 6.0),
        DrawingViewLine(points: [CGPoint(x: 443.953125, y: 289.984375)],
                        color: .black,
                        lineWidth: 6.0),
        DrawingViewLine(points: [
            CGPoint(x: 443.953125, y: 289.984375),
            CGPoint(x: 443.953125, y: 289.109375),
            CGPoint(x: 443.953125, y: 286.03515625),
            CGPoint(x: 443.953125, y: 276.1796875),
            CGPoint(x: 443.953125, y: 257.8046875),
            CGPoint(x: 443.953125, y: 209.23046875),
            CGPoint(x: 443.859375, y: 198.3359375),
            CGPoint(x: 441.62890625, y: 190.5703125),
            CGPoint(x: 433.18359375, y: 185.1015625),
            CGPoint(x: 417.07421875, y: 182.515625),
            CGPoint(x: 392.6875, y: 182.41015625),
            CGPoint(x: 351.671875, y: 189.41015625),
            CGPoint(x: 299.640625, y: 207.12890625),
            CGPoint(x: 254.3359375, y: 227.54296875),
            CGPoint(x: 213.1484375, y: 250.96484375),
            CGPoint(x: 175.87109375, y: 278.24609375),
            CGPoint(x: 149.2421875, y: 303.9765625),
            CGPoint(x: 131.515625, y: 328.48828125),
            CGPoint(x: 121.52734375, y: 353.72265625),
            CGPoint(x: 118.27734375, y: 381.05859375),
            CGPoint(x: 124.37109375, y: 411.578125),
            CGPoint(x: 146.8671875, y: 449.65234375),
            CGPoint(x: 178.04296875, y: 484.93359375),
            CGPoint(x: 211.28515625, y: 511.125),
            CGPoint(x: 247.04296875, y: 532.95703125),
            CGPoint(x: 281.43359375, y: 545.75390625),
            CGPoint(x: 314.484375, y: 550.23828125),
            CGPoint(x: 341.7734375, y: 549.83203125),
            CGPoint(x: 363.84765625, y: 544.90234375),
            CGPoint(x: 382.6328125, y: 536.4296875),
            CGPoint(x: 396.703125, y: 525.7734375),
            CGPoint(x: 408.9140625, y: 508.578125),
            CGPoint(x: 421.44921875, y: 478.953125),
            CGPoint(x: 432.41796875, y: 443.46875),
            CGPoint(x: 439.546875, y: 415.14453125),
            CGPoint(x: 443.97265625, y: 397.20703125),
            CGPoint(x: 447.04296875, y: 385.92578125),
            CGPoint(x: 448.890625, y: 379.63671875),
            CGPoint(x: 449.6640625, y: 377.9765625),
            CGPoint(x: 449.86328125, y: 378.91796875),
            CGPoint(x: 449.03125, y: 383.51953125),
            CGPoint(x: 441.671875, y: 397.7421875),
            CGPoint(x: 420.7578125, y: 425.8125),
            CGPoint(x: 390.46875, y: 461.0390625),
            CGPoint(x: 356.640625, y: 495.25390625),
            CGPoint(x: 327.50390625, y: 518.33203125),
            CGPoint(x: 300.77734375, y: 529.76953125),
            CGPoint(x: 275.30078125, y: 533.52734375),
            CGPoint(x: 256.2578125, y: 525.53125),
            CGPoint(x: 239.97265625, y: 507.09765625),
            CGPoint(x: 227.23828125, y: 480.55859375),
            CGPoint(x: 219.23046875, y: 452.859375),
            CGPoint(x: 215.4921875, y: 432.765625),
            CGPoint(x: 213.49609375, y: 419.71484375),
            CGPoint(x: 212.73046875, y: 412.13671875),
            CGPoint(x: 212.73046875, y: 409.62109375)
        ],
        color: .black,
        lineWidth: 6.0)
    ]

}
