//
//  GraphNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/10/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import OrderedCollections

// fka `GraphNode`
protocol NodeDefinition {
    static var graphKind: NodeDefinitionKind { get }
    static var defaultTitle: String { get }
    
    // TODO: `LayerGraphNode.rowDefinitions` can NEVER have a UserVisibleType
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions
    @MainActor static func createEphemeralObserver() -> NodeEphemeralObservable?

    static var inputCountVariesByType: Bool { get }
    static var outputCountVariesByType: Bool { get }
}

// fka `PatchGraphNode`
protocol PatchNodeDefinition: NodeDefinition {
    static var patch: Patch { get }
    static var defaultUserVisibleType: UserVisibleType? { get }
    static var inputCountVariesByType: Bool { get }
    static var outputCountVariesByType: Bool { get }
}

extension PatchNodeDefinition {
    static var defaultUserVisibleType: UserVisibleType? { nil }
    static var graphKind: NodeDefinitionKind { .patch(Self.self) }
}



// fka `LayerGraphNode`
protocol LayerNodeDefinition: NodeDefinition {
    associatedtype Content: View
    
    static var layer: Layer { get }
    
    static var inputDefinitions: LayerInputTypeSet { get }
    
    @MainActor
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool) -> Content
}

extension LayerNodeDefinition {
    static var graphKind: NodeDefinitionKind { .layer(Self.self) }
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(layerInputs: Self.inputDefinitions,
              layer: self.layer)
    }
}

extension NodeDefinition {

    static var inputCountVariesByType: Bool { false }
    static var outputCountVariesByType: Bool { false }

    static func createEphemeralObserver() -> NodeEphemeralObservable? { nil }
    static var kind: NodeKind { Self.graphKind.kind }
    static var defaultTitle: String { Self.kind.getDisplayTitle(customName: nil) }

    @MainActor
    static func createViewModel(id: NodeId = NodeId(),
                                position: CGPoint,
                                zIndex: CGFloat,
                                parentGroupNodeId: GroupNodeId? = nil,
                                activeIndex: ActiveIndex,
                                graphDelegate: GraphDelegate?) -> NodeViewModel {
        NodeViewModel(from: Self.self,
                      id: id,
                      position: position,
                      zIndex: zIndex,
                      parentGroupNodeId: parentGroupNodeId,
                      activeIndex: activeIndex,
                      graphDelegate: graphDelegate)
    }

//    @MainActor
//    static func createFakeViewModel() -> NodeViewModel {
//        Self.createViewModel(position: .zero,
//                             zIndex: .zero,
//                             activeIndex: .init(.zero))
//    }
//
//    @MainActor
//    static func createFakeNodeEntity() -> NodeEntity {
//        Self.createFakeViewModel().createSchema()
//    }
}

// fka `GraphNodeKind`
enum NodeDefinitionKind {
    case patch(PatchNodeDefinition.Type)
    case layer(any LayerNodeDefinition.Type)
}

extension NodeDefinitionKind {
    var kind: NodeKind {
        switch self {
        case .patch(let patchGraphNode):
            return .patch(patchGraphNode.patch)
        case .layer(let layerGraphNode):
            return .layer(layerGraphNode.layer)
        }
    }
    
    var patch: PatchNodeDefinition.Type? {
        switch self {
        case .patch(let patchNodeDefinition):
            return patchNodeDefinition
        default:
            return nil
        }
    }
}
