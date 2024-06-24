//
//  SidebarIcons.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

let MASKS_LAYER_ABOVE_ICON_NAME = "arrow.turn.left.up"

extension Layer {
    var sidebarLeftSideIcon: String {
        switch self {
        case .group:
            return "folder"
        case .image:
            return "photo"
        case .rectangle:
            return "rectangle"
        case .oval, .colorFill:
            return "oval"
        case .model3D:
            return "rotate.3d"
        // TODO: New Icon from Adam
        case .realityView:
            return "rotate.3d"
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
            return "star"
        case .videoStreaming:
            return "video.bubble.left"
        }
    }
}
