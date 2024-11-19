//
//  GraphBounds.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/25/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/*
 1. We create a specific size/bound for the graph-view, based on eastern, southern, northern and western most nodes
 2. We only look at nodes eastern, western etc. nodes for the given traversal level (eg top-level or some group)
 */
extension GraphState {

    // "the white dotted-line rectangle" (see Figma)
    @MainActor
    func graphBounds(_ scale: CGFloat,
                     graphView: CGRect,
                     graphOffset: CGPoint,
                     positionalData: BoundaryNodesPositions) -> CGRect {
        let east = positionalData.east
        let west = positionalData.west
        let south = positionalData.south
        let north = positionalData.north

        let scaledDevice = CGSize(
            width: graphView.width * scale,
            height: graphView.height * scale)

        let yDiff = graphView.height - scaledDevice.height
        let xDiff = graphView.width - scaledDevice.width

        let width = west.x - east.x
        let height = north.y - south.y

        let scaledWidth = width * scale
        let scaledHeight = height * scale

        let size = CGSize(width: scaledWidth, height: scaledHeight)

        // the x part of the origin; ie start from western-most node and then go half the width in-land
        let boxMidX = (west.x * scale) - scaledWidth/2

        // TODO: why exactly does this formula work, especially the xDiff parts?
        let positionX = boxMidX + (xDiff - graphOffset.x) - xDiff/2 + (graphOffset.x * scale)

        let boxMidY = (north.y * scale) - scaledHeight/2
        let positionY = boxMidY + (yDiff - graphOffset.y) - yDiff/2 + (graphOffset.y * scale)

        // ORIGINAL
        //        let positionX = (west.position.width * scale) - scaledWidth/2 + (xDiff - graphOffset.width) - xDiff/2 + (graphOffset.width * scale)
        //        let positionY = (north.position.height * scale) - scaledHeight/2 + (yDiff - graphOffset.height) - yDiff/2 + (graphOffset.height * scale)

        //        #if DEV_DEBUG
        //        log("\n \n graphBounds: graphView: \(graphView)")
        //        log("graphBounds: scale: \(scale)")
        //        log("graphBounds: graphOffset: \(graphOffset)")
        //
        //        log("graphBounds: scaledDevice: \(scaledDevice)")
        //        log("graphBounds: yDiff: \(yDiff)")
        //        log("graphBounds: xDiff: \(xDiff)")
        //
        //        log("graphBounds: north.position.width: \(north.position.width)")
        //        log("graphBounds: west.position.width: \(west.position.width)")
        //
        //        log("graphBounds: (north.position.width * scale): \((north.position.width * scale))")
        //        log("graphBounds: (west.position.width * scale): \((west.position.width * scale))")
        //
        //        log("graphBounds: width: \(width)")
        //        log("graphBounds: height: \(height)")
        //        log("graphBounds: scaledWidth: \(scaledWidth)")
        //        log("graphBounds: scaledHeight: \(scaledHeight)")
        //
        //        log("graphBounds: positionX: \(positionX)")
        //        log("graphBounds: positionY: \(positionY)")
        //        #endif

        return CGRect(origin: CGPoint(x: positionX,
                                      y: positionY),
                      size: size)
    }
}
