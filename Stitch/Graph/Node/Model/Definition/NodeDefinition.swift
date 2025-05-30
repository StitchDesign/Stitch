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
import RealityKit

// fka `GraphNode`
protocol NodeDefinition {
    static var graphKind: NodeDefinitionKind { get }
    
    static var defaultTitle: String { get }
    
    @MainActor
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions
    
    @MainActor
    static func evaluate(node: NodeViewModel) -> EvalResult?
    
    @MainActor
    static func createEphemeralObserver() -> NodeEphemeralObservable?

    static var inputCountVariesByType: Bool { get }
    
    static var outputCountVariesByType: Bool { get }
    
    static var defaultUserVisibleType: UserVisibleType? { get }
}

// fka `PatchGraphNode`
protocol PatchNodeDefinition: NodeDefinition {
    static var patch: Patch { get }
    
    static var inputCountVariesByType: Bool { get }
    
    static var outputCountVariesByType: Bool { get }
}

extension NodeDefinition {
    /// Default eval caller which calls legacy eval.
    @MainActor
    static func evaluate(node: NodeViewModel) -> EvalResult? {
        node.evaluate()
    }
}

extension PatchNodeDefinition {
    static var defaultUserVisibleType: UserVisibleType? { nil }
    static var graphKind: NodeDefinitionKind { .patch(Self.self) }
}

extension Layer {
    @MainActor
    var inputDefinitions: LayerInputPortSet {
        self.layerGraphNode.inputDefinitions
    }
}

// fka `LayerGraphNode`
protocol LayerNodeDefinition: NodeDefinition {
    associatedtype Content: View
    
    static var layer: Layer { get }
    
    @MainActor static var inputDefinitions: LayerInputPortSet { get }
    
    @MainActor
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: LayerRealityCameraContent?) -> Content
}

extension LayerNodeDefinition {
    static var graphKind: NodeDefinitionKind { .layer(Self.self) }
    
    static var defaultUserVisibleType: UserVisibleType? { nil }
    
    @MainActor
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(layerInputs: Self.inputDefinitions,
              layer: self.layer)
    }
}

extension NodeDefinition {

    static var inputCountVariesByType: Bool { false }
    static var outputCountVariesByType: Bool { false }

    static func createEphemeralObserver() -> NodeEphemeralObservable? { nil }
    static var kind: PatchOrLayer { Self.graphKind.kind }
    static var defaultTitle: String { Self.kind.asNodeKind.getDisplayTitle(customName: nil) }

    // TODO: separate functions for creating Patch vs Layer nodes; Layer nodes themselves never take canvas-position
    @MainActor
    static func createViewModel(id: NodeId = NodeId(),
                                position: CGPoint,
                                zIndex: CGFloat,
                                parentGroupNodeId: GroupNodeId? = nil,
                                graphDelegate: GraphState?) -> NodeViewModel {
        NodeViewModel(from: Self.self,
                      id: id,
                      position: position,
                      zIndex: zIndex,
                      parentGroupNodeId: parentGroupNodeId,
                      graphDelegate: graphDelegate)
    }
}

// fka `GraphNodeKind`
enum NodeDefinitionKind {
    case patch(PatchNodeDefinition.Type)
    case layer(any LayerNodeDefinition.Type)
}

extension NodeDefinitionKind {
    var kind: PatchOrLayer {
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
