//
//  LayerUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/13/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias ZIndex = Double

typealias LayerSingleValueKeyPath = ReferenceWritableKeyPath<LayerViewModel, PortValue>
typealias LayerMultiValueKeyPath = ReferenceWritableKeyPath<LayerViewModel, PortValues>

extension Layer {
    @MainActor
    func hasMultiKeyPath(at port: Int) -> Bool {
        // MARK: no longer used
        false
//        guard let inputType = self.getPreviewLayerInputType(at: port) else {
//            fatalErrorIfDebug()
//            return false
//        }
//        
//        return inputType.supportsLoopedTypes
    }

    @MainActor
    func getPreviewLayerInputType(at portId: Int) -> LayerInputPort? {
        self.layerGraphNode.inputDefinitions[safe: portId]
    }
    
    var supportsOutputs: Bool {
        switch self {
        case .canvasSketch, .textField, .switchLayer:
            return true
        case .text, .oval, .rectangle, .image, .group, .video, .model3D, .realityView, .shape, .colorFill, .hitArea, .map, .progressIndicator, .linearGradient, .radialGradient, .angularGradient, .sfSymbol, .videoStreaming, .material, .box, .sphere, .cylinder, .cone, .spacer:
            return false
        }
    }

    static var searchableLayers: [Layer] {
        Layer.allCases.filter { layer in
            !ignoredLayers.contains(layer)
        }
    }

    static var ignoredLayers: Set<Layer> {
        Set([.group])
    }

    // Called both when layer-node first placed on graph
    // and when deserializing.
    @MainActor
    func defaultNode(id: NodeId, // = NodeId(),
                     // ie center of graph
                     position: CGSize,
                     zIndex: Double,
                     firstCreation: Bool = true,
                     graphDelegate: GraphState?) -> NodeViewModel {

        let node = self.layerGraphNode.createViewModel(
            id: id,
            position: position.toCGPoint,
            zIndex: zIndex,
            graphDelegate: graphDelegate)

        /*
         When first creating a brand new node (not recreating it from schema)
         we must ensure that the node's position and previousPosition
         line up against a top-left grid intersection
         when node is placed on graph.
         */
//        if firstCreation {
//            node.adjustPosition(center: position.toCGPoint)
//        }
        
        return node
    }

    var previewType: PreviewLayerType {
        switch self {
        case .text:
            return .text
        case .group:
            return .group
        case .video, .image:
            return .visualMedia
        case .model3D:
            return .model3D
        case .realityView:
            return .realityView
        case .shape, .oval, .rectangle:
            return .shape
        case .colorFill:
            return .colorFill
        case .hitArea:
            return .hitArea
        case .canvasSketch:
            return .canvasSketch
        case .textField:
            return .textField
        case .map:
            return .map
        case .progressIndicator:
           return .progressIndicator
        case .switchLayer:
           return .switchLayer
        case .linearGradient:
            return .linearGradient
        case .radialGradient:
            return .radialGradient
        case .angularGradient:
            return .angularGradient
        case .sfSymbol:
            return .sfSymbol
        case .videoStreaming:
            return .videoStreaming
        case .material:
            return .material
        case .box:
            return .box
        case .sphere:
            return .sphere
        case .cylinder:
            return .cylinder
        case .cone:
            return .cone
        case .spacer:
            return .spacer
        }
    }

    // TODO: can this method just be "false if realityView, else true" ?

    /// Returns true if some layer node's port flattens incoming values rather than supports looping. i.e.
    /// the Reality node's first input.
    @MainActor
    func doesPortSupportLooping(portId: Int) -> Bool {
        !self.hasMultiKeyPath(at: portId)
    }
    
    var supportedMediaType: SupportedMediaFormat? {
        switch self {
        case .video:
            return .video
        case .image:
            return .image
        case .model3D:
            return .model3D
        default:
            return nil
        }
    }
    
    var supportsSidebarGroup: Bool {
        switch self {
        case .group, .realityView:
            return true
            
        default:
            return false
        }
    }
    
    @MainActor
    static let layers3D: [Layer] = Layer.allCases
        .filter { $0.inputDefinitions.contains(.transform3D) }
}
