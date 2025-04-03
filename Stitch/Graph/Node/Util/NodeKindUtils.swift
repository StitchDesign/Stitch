//
//  NodeKind.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/11/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension NodeKind {

    var mediaType: SupportedMediaFormat {
        switch self {
        case .patch(let patch):
            return patch.supportedMediaType
        case .layer(let layer):
            return layer.supportedMediaType
        case .group:
            return .unknown
        }
    }

    var canUseMediaPicker: Bool {
        switch self {
        case .patch(let x):
            return x.usesCustomValueSpaceWidth
        case .layer(let x):
            return x.usesCustomValueSpaceWidth
        case .group:
            return false
        }
    }

    var multifieldUsesOverallLabel: Bool {
        switch self {
        case .layer:
            return true
        case .group:
            return false
        case .patch(let x):
            return x.multifieldUsesOverallLabel
        }
    }

    /// Returns "patch", "layer", or "group".
    var parentDescription: String {
        switch self {
        case .patch:
            return "patch"
        case .layer:
            return "layer"
        case .group:
            return "group"
        }
    }

    var description: String {
        switch self {
        case .patch(let patch):
            return patch.defaultDisplayTitle()
        case .layer(let layer):
            return layer.defaultDisplayTitle()
        case .group:
            return "group"
        }
    }

    var getPatch: Patch? {
        switch self {
        case .patch(let patch):
            return patch
        default:
            return nil
        }
    }

    var getLayer: Layer? {
        switch self {
        case .layer(let layer):
            return layer
        default:
            return nil
        }
    }

    var isLayer: Bool {
        switch self {
        case .layer:
            return true
        default:
            return false
        }
    }

    var isPatch: Bool {
        switch self {
        case .patch:
            return true
        default:
            return false
        }
    }

    var isGroup: Bool {
        switch self {
        case .group:
            return true
        default:
            return false
        }
    }

    // Checks if Patch creates some media which uses the singleton pattern.
    var singletonMediaOption: NodeKind? {
        switch self {
        case .patch(let patch):
            switch patch {
            case .cameraFeed:
                return .patch(.cameraFeed)
            case .location:
                return .patch(.location)
            default:
                return nil
            }
        case .layer(let layer):
            switch layer {
            case .realityView:
                return .layer(.realityView)
            default:
                return nil
            }
        case .group:
            return nil
        }
    }

    // TODO: node colors for splitter
    func nodeUIColor(_ splitterType: SplitterType? = nil) -> NodeUIColor {
        switch self {
        case .patch(let patch):
            return patch.nodeUIColor(splitterType)
        case .layer:
            return NodeUIColor.layerNode
        case .group:
            return NodeUIColor.groupNode
        }
    }

    var nodeUIKind: NodeUIKind {
        switch self {
        case .patch(let patch):
            return patch.nodeUIKind
        case .layer:
            return NodeUIKind.inputsOnly
        case .group:
            return NodeUIKind.doubleSided
        }
    }

    @MainActor
    func defaultInputs(for type: UserVisibleType?) -> PortValuesList {
        self.rowDefinitions(for: type).inputs.map { $0.defaultValues }
    }

    @MainActor
    func createDefaultNode(id: NodeId,
                           activeIndex: ActiveIndex,
                           graphDelegate: GraphDelegate?) -> NodeViewModel? {
        switch self {
        case .patch(let patch):
            return patch.defaultNode(id: id,
                                     position: .zero,
                                     zIndex: .zero,
                                     graphDelegate: graphDelegate)
        case .layer(let layer):
            return layer.defaultNode(id: id,
                                     position: .zero,
                                     zIndex: .zero,
                                     graphDelegate: nil)
        case .group:
            // Not intended here
            fatalError()
        }
    }
    
    /// Considers special nodes which loop inputs.
    @MainActor func determineMaxLoopCount(from valuesList: PortValuesList) -> Int {
        switch self {
        case .layer(let layer):
            switch layer {
            case .realityView:
                return 1
            default:
                return valuesList.longestLoopLength
            }
        default:
            return valuesList.longestLoopLength
        }
    }
    
    var supportedMediaType: SupportedMediaFormat? {
        switch self {
        case .patch(let patch):
            return patch.supportedMediaType
        case .layer(let layer):
            return layer.supportedMediaType
        default:
            return nil
        }
    }
    
    func getDisplayTitle(customName: String?) -> String {
        // Always prefer a custom name
        if let customName = customName,
           customName != "" {
            return customName
        }

        switch self {
        case .patch(let x):
            return x.defaultDisplayTitle()
        case .group:
            return "Group"
        case .layer(let x):
            return x.defaultDisplayTitle()
        }
    }
    
    // Some inputs don't need to coerce PortValues and can instead copy values directly
    @MainActor
    func canCopyInputValues(portId: Int?,
                            userVisibleType: UserVisibleType?) -> Bool {
        guard let portId = portId else {
            return false
        }
        
        return self.graphNode?.rowDefinitions(for: userVisibleType)
            .inputs[safe: portId]?.canDirectlyCopyUpstreamValues ?? false
    }
}
