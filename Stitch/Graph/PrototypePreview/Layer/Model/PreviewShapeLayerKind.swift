//
//  PreviewShapeLayerKind.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

enum PreviewShapeLayerKind {
    // e.g. Shape Layer Node
    // (which receives `ShapeInstructions` from an Oval Patch Node, Triangle Patch Node etc.)
    case pathBased(CustomShape),
         // e.g. Oval Layer Node, Rectangle Layer Node
         swiftUIRectangle(CGFloat),
         swiftUIOval,
         // e.g. Shape Layer Node or Union Node before anything plugged in
         none
    
    // DEBUG
    var display: String {
        switch self {
        case .pathBased:
            return "Custom Shape"
        case .swiftUIRectangle:
            return "SwiftUI Rectangle"
        case .swiftUIOval:
            return "SwiftUI Oval"
        case .none:
            return "None"
        }
    }
}
