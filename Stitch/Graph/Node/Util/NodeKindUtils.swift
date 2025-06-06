//
//  NodeKind.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/11/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

enum NodeMediaSupport {
    // almost all media nodes
    case single(SupportedMediaFormat)
    
    // just loop builder, which supports all types
    case all
}

extension NodeKind {

    func mediaType(coordinate: InputCoordinate) -> NodeMediaSupport? {
        switch self {
        case .patch(let patch):
            assertInDebug(coordinate.portId.isDefined) // called incorrectly
            return patch.supportedMediaType(portId: coordinate.portId ?? 0)
        case .layer(let layer):
            guard let type = layer.supportedMediaType else { return nil }
            return .single(type)
        case .group:
            return nil
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
    
    var defaultDisplayTitle: String {
        self.getDisplayTitle()
    }
    
    func getDisplayTitle(customName: String? = nil) -> String {
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
}

extension PatchOrLayer {
    @MainActor
    func defaultInputs(for type: UserVisibleType?) -> PortValuesList {
        self.rowDefinitionsOldOrNewStyle(for: type).inputs.map { $0.defaultValues }
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

extension NodeKind: CaseIterable {
    public static var allCases: [NodeKind] {
        let patchCases = Patch.allCases.map(NodeKind.patch)
        let layerCases = Layer.allCases.map(NodeKind.layer)
        return patchCases + layerCases
    }
    
    var nodeDescriptionBody: String? {
        switch self {
        case .patch(let patch):
            return patch.nodeDescriptionBody
        case .layer(let layer):
            return layer.nodeDescriptionBody
        default:
            fatalErrorIfDebug()
            return nil
        }
    }
}
