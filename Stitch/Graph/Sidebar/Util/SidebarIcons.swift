//
//  SidebarIcons.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

let MASKS_LAYER_ABOVE_ICON_NAME = "arrow.turn.left.up"

//extension Layer {
extension SidebarItemGestureViewModel {
    @MainActor var isMasking: Bool {
        
        // TODO: why is this not animated? and why does it jitter?
//        // index of this layer
//        guard let index = graph.sidebarListState.masterList.items
//            .firstIndex(where: { $0.id.asLayerNodeId == nodeId }) else {
//            return withAnimation { false }
//        }
//
//        // hasSidebarLayerImmediatelyAbove
//        guard graph.sidebarListState.masterList.items[safe: index - 1].isDefined else {
//            return withAnimation { false }
//        }
//
        let atleastOneIndexMasks = self.graphDelegate?
            .getLayerNode(id: self.id)?
            .layerNode?.masksPort.allLoopedValues
            .contains(where: { $0.getBool ?? false })
        ?? false
        
//        return withAnimation {
          return atleastOneIndexMasks
//        }
    }
    
    @MainActor var sidebarLeftSideIcon: String {
        guard let layerNode = self.graphDelegate?.getNodeViewModel(id)?.layerNode,
              let activeIndex = self.graphDelegate?.documentDelegate?.activeIndex else {
//            fatalErrorIfDebug()
            return "oval"
        }
        
        switch layerNode.layer {
        case .group:
            return "folder"
        case .image:
            return "photo"
        case .rectangle:
            return "rectangle"
        case .oval:
            return "oval"
        case .colorFill:
            return "swatchpalette.fill"
        case .model3D:
            return "move.3d"
        case .realityView:
            return "globe"
        case .video:
            return "film"
        case .text:
            return "t.square"
        case .shape:
            return "star"
        case .hitArea:
            return "circle.square"
        case .canvasSketch:
            return "scribble.variable"
        case .textField:
            return "t.square"
        case .map:
            return "mappin.circle"
        case .progressIndicator:
          //TODO: Better image?
            return "circle.grid.cross.right.fill"
        case .switchLayer:
            return "switch.2"
        case .linearGradient:
            return "line.3.crossed.swirl.circle.fill"
        case .radialGradient:
            return "line.3.crossed.swirl.circle.fill"
        case .angularGradient:
            return "line.3.crossed.swirl.circle.fill"
        case .sfSymbol:
            let defaultSymbol = "star"
            let sfSymbolInputValues = layerNode.sfSymbolPort.allLoopedValues
            let adjustedActiveIndex = activeIndex.adjustedIndex(sfSymbolInputValues.count)
            return sfSymbolInputValues[safe: adjustedActiveIndex]?.getString?.string ?? defaultSymbol
        case .videoStreaming:
            return "video.bubble.left"
        case .material:
            return "circle.filled.pattern.diagonalline.rectangle"
        case .box:
            return "cube"
        case .sphere:
            return "rotate.3d"
        case .cylinder:
            return "cylinder"
        case .cone:
            return "cone"
        }
    }
}
