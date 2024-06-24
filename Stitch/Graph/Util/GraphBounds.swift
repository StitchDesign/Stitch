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
                     groupNodeFocused: GroupNodeId?) -> CGRect? {

        // NOTE: nodes are retrieved per active traversal level,
        // ie top level vs some specific, focused group.
        let canvasItemsAtTraversalLevel = self.canvasItemsAtTraversalLevel(self.graphUI.groupNodeFocused)

        // If there are no nodes, then there is no graphBounds
        guard let east = Self.easternMostNode(groupNodeFocused,
                                              canvasItems: canvasItemsAtTraversalLevel),
              let west = Self.westernMostNode(groupNodeFocused,
                                              canvasItems: canvasItemsAtTraversalLevel),
              let south = Self.southernMostNode(groupNodeFocused,
                                                canvasItems: canvasItemsAtTraversalLevel),
              let north = Self.northernMostNode(groupNodeFocused,
                                                canvasItems: canvasItemsAtTraversalLevel) else {
            //            log("GraphState: graphBounds: had no nodes")
            return nil
        }

        let id = west.id
        if east.id == id, north.id == id, south.id == id {
            // If there's only one node, this fornula seems just fine.
            //            log("GraphState: graphBounds: had single node")
        }

        let scaledDevice = CGSize(
            width: graphView.width * scale,
            height: graphView.height * scale)

        let yDiff = graphView.height - scaledDevice.height
        let xDiff = graphView.width - scaledDevice.width

        let width = west.position.x - east.position.x
        let height = north.position.y - south.position.y

        let scaledWidth = width * scale
        let scaledHeight = height * scale

        let size = CGSize(width: scaledWidth, height: scaledHeight)

        // the x part of the origin; ie start from western-most node and then go half the width in-land
        let boxMidX = (west.position.x * scale) - scaledWidth/2

        // TODO: why exactly does this formula work, especially the xDiff parts?
        let positionX = boxMidX + (xDiff - graphOffset.x) - xDiff/2 + (graphOffset.x * scale)

        let boxMidY = (north.position.y * scale) - scaledHeight/2
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
