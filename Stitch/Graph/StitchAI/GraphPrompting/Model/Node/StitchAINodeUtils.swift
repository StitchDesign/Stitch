//
//  StitchAINodeUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/13/25.
//

import SwiftUI
import StitchSchemaKit

//extension CurrentStep.NodeKind {
//    static func getAiNodeDescriptions() -> [StitchAINodeKindDescription_V31.StitchAINodeKindDescription] {
//        // Filter out the scroll interaction node
//        let allDescriptions = CurrentStep.Patch.allAiDescriptions + CurrentStep.Layer.allAiDescriptions
//        return allDescriptions.filter { description in
//            !description.nodeKind.contains("scrollInteraction")
//        }
//    }
//}



// TODO: move to schema versioning

/// Redundant copy for newest version, should Stitch AI and SSK versions diverge.
extension NodeKind_V31.NodeKind {
    static func getAiNodeDescriptions() -> [StitchAINodeKindDescription] {
        // Filter out the scroll interaction node
        let allDescriptions = Patch_V31.Patch.allAiDescriptions + Layer_V31.Layer.allAiDescriptions
        return allDescriptions.filter { description in
            !description.nodeKind.contains("scrollInteraction")
        }
    }
}

struct StitchAINodeKindDescription {
    let nodeKind: String
    let description: String
    let types: Set<UserVisibleType_V31.UserVisibleType>?
}

extension StitchAINodeKindDescription: Encodable {
    enum CodingKeys: String, CodingKey {
        case nodeKind = "node_kind"
        case description
        case types
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeKind, forKey: .nodeKind)
        try container.encode(description, forKey: .description)
        
        if let types = self.types {
            let typeStrings = types.map(\.asLLMStepNodeType)
            try container.encode(Array(typeStrings).sorted(), forKey: .types)
        }
    }
}

protocol NodeKindDescribable: CaseIterable {
    func defaultDisplayTitle() -> String
    
    var aiNodeDescription: String { get }
    
    var types: Set<UserVisibleType_V31.UserVisibleType>? { get }
    
    static var titleDisplay: String { get }
}

extension NodeKindDescribable {
    var aiDisplayTitle: String {
        Self.toCamelCase(self.defaultDisplayTitle()) + " || \(Self.titleDisplay)"
    }

    static var allAiDescriptions: [StitchAINodeKindDescription] {
        Self.allCases.map {
            .init(nodeKind: $0.aiDisplayTitle,
                  description: $0.aiNodeDescription,
                  types: $0.types
            )
        }
    }
    
    private static func toCamelCase(_ sentence: String) -> String {
        let words = sentence.components(separatedBy: " ")
        let camelCaseString = words.enumerated().map { index, word in
            index == 0 ? word.lowercased() : word.capitalized
        }.joined()
        return camelCaseString
    }
}

extension Patch_V31.Patch: NodeKindDescribable {
    var types: Set<UserVisibleType_V31.UserVisibleType>? {
        guard let migratedPatch = try? self.convert(to: Patch.self) else {
            fatalErrorIfDebug("No patch for this type: \(self)")
            return nil
        }
        
        // Check runtime support
        let types = migratedPatch.availableNodeTypes
        
        // Downgrade back
        let downgradedTypes: [UserVisibleType_V31.UserVisibleType] = types.compactMap {
            guard let convertedType = try? $0.convert(to: UserVisibleType_V31.UserVisibleType.self) else {
                log("No support at this version for type for: \(self)")
                return nil
            }
            
            return convertedType
        }
        
        guard !downgradedTypes.isEmpty else {
            return nil
        }
        
        return Set(downgradedTypes)
    }
}
extension Layer_V31.Layer: NodeKindDescribable {
    // layers don't do node types
    var types: Set<UserVisibleType_V31.UserVisibleType>? { nil }
}

//public enum PatchOrLayer: Codable, Hashable, Sendable {
//    case patch(Patch_V31.Patch), layer(Layer_V31.Layer)
//}

extension PatchOrLayer_V31.PatchOrLayer {
//    var description: String {
//        switch self {
//        case .patch(let patch):
//            return patch.defaultDisplayTitle()
//        case .layer(let layer):
//            return layer.defaultDisplayTitle()
//        }
//    }
    
    var asLLMStepNodeName: String {
        switch self {
        case .patch(let x):
            // e.g. Patch.squareRoot -> "Square Root" -> "squareRoot || Patch"
            return x.aiDisplayTitle
        case .layer(let x):
            return x.aiDisplayTitle
        }
    }
}

//extension StitchAINodeKindDescription {
//    init<T>(_ nodeKindType: T) where T: CurrentStep.NodeKindDescribable {
//        self.nodeKind = nodeKindType.aiDisplayTitle
//        self.description = nodeKindType.aiNodeDescription
//    }
//}
//
///// Redundant copy for newest version, should Stitch AI and SSK versions diverge.
//extension StitchAINodeKindDescription {
//    init<T>(_ nodeKindType: T) where T: NodeKindDescribable {
//        self.nodeKind = nodeKindType.aiDisplayTitle
//        self.description = nodeKindType.aiNodeDescription
//    }
//}

struct StitchAINodeSectionDescription: Encodable {
    var header: String
    var nodes: [StitchAINodeIODescription]
}

extension StitchAINodeSectionDescription {
    @MainActor
    init(_ section: NodeSection,
         graph: GraphState) throws {
        let nodesInSection: [StitchAINodeIODescription] = try section
            .getNodesForSection()
            .compactMap { patchOrLayer -> StitchAINodeIODescription? in
                guard let migratedPatchOrLayer = try? patchOrLayer.convert(to: PatchOrLayer.self) else {
                    fatalErrorIfDebug("StitchAINodeSectionDescription: unable to convert patchOrLayer for: \(patchOrLayer)")
                    return nil
                }
                
                // Use node definitions, if available
                if let graphNode = migratedPatchOrLayer.graphNode {
                    return try .init(graphNode)
                }
                
                // Backup plan: create default node, extract data from there
                guard let defaultNode = migratedPatchOrLayer
                    .createDefaultNode(id: .init(),
                                       activeIndex: .init(.zero),
                                       graphDelegate: graph) else {
                    fatalErrorIfDebug()
                    return nil
                }
                
                let inputs: [StitchAIPortValueDescription] = try defaultNode.inputsObservers.compactMap { inputObserver in
                    let runtimeValue = inputObserver.getActiveValue(activeIndex: .init(.zero))
                    
                    // Backwards compat check for runtime's PortValue
                    // Silent failures allow for new port value types to get ignored, which should be ok for layers
                    guard let migratedValue = try? runtimeValue.convert(to: CurrentStep.PortValue.self) else {
                        switch patchOrLayer {
                        case .patch(let patch):
                            fatalErrorIfDebug("Issues reading values for patch \(patch) on value \(runtimeValue)")
                            throw StitchAIManagerError.portValueDescriptionNotSupported(patchOrLayer.asLLMStepNodeName)
                        
                        case .layer:
                            // Less of a big deal for layers to not support inputs since ordering isn't important
                            return nil
                        }
                    }
                    
                    return StitchAIPortValueDescription(
                        label: inputObserver.label(node: defaultNode,
                                                   coordinate: .input(inputObserver.id),
                                                   graph: graph),
                        value: migratedValue)
                }
                
                // Calculate node to get outputs values
                if let evalResult = defaultNode.evaluate() {
                    defaultNode.updateOutputsObservers(newValuesList: evalResult.outputsValues, graph: graph)
                }
                
                let outputs: [StitchAIPortValueDescription] = try defaultNode.outputsObservers.map { outputObserver in
                    let runtimeValue = outputObserver.getActiveValue(activeIndex: .init(.zero))
                    
                    // Backwards compat check for runtime's PortValue
                    let migratedValue = try runtimeValue.convert(to: CurrentStep.PortValue.self)
                    
                    return StitchAIPortValueDescription(
                        label: outputObserver.label(node: defaultNode,
                                                    coordinate: .output(outputObserver.id),
                                                    graph: graph),
                        value: migratedValue)
                }
                
                assertInDebug(inputs.first { $0.value == .none } == nil)
                assertInDebug(outputs.first { $0.value == .none } == nil)
                
                return .init(nodeKind: patchOrLayer.asLLMStepNodeName,
                             inputs: inputs,
                             outputs: outputs)
            }
        
        self.header = section.description
        self.nodes = nodesInSection
    }
}

struct StitchAINodeIODescription: Encodable {
    var nodeKind: String
    var inputs: [StitchAIPortValueDescription]
    var outputs: [StitchAIPortValueDescription]
}

extension StitchAINodeIODescription {
    @MainActor
    init(_ NodeInfo: any NodeDefinition.Type) throws {
        let migratedNodeKind = try NodeInfo.graphKind.kind.convert(to: PatchOrLayer_V31.PatchOrLayer.self)
        self.nodeKind = migratedNodeKind.asLLMStepNodeName
        let rowDefinitions = NodeInfo.rowDefinitions(for: NodeInfo.defaultUserVisibleType)
        
        do {
            self.inputs = try rowDefinitions.inputs.compactMap {
                // Migrates PortValue data to supported AI version
                guard let migratedInput = try? $0.defaultValues.first!.convert(to: CurrentStep.PortValue.self) else {
                    // Silent failure for layer inputs which don't have ordering constraints of patches
                    switch migratedNodeKind {
                    case .layer:
                        return nil
                    case .patch:
                        throw StitchAIManagerError.portValueDescriptionNotSupported(migratedNodeKind.asLLMStepNodeName)
                    }
                }
                
                return .init(label: $0.label,
                             value: migratedInput)
            }
            
            self.outputs = try rowDefinitions.outputs.map {
                let migratedOutput = try $0.value.convert(to: CurrentStep.PortValue.self)
                
                return .init(label: $0.label,
                             value: migratedOutput)
            }
        } catch {
            log("Error converting node types at StitchAINodeIODescription for \(self.nodeKind): \(error.localizedDescription)")
            throw StitchAIManagerError.portValueDescriptionNotSupported(migratedNodeKind.asLLMStepNodeName)
        }
    }
}

struct StitchAIPortValueDescription {
    var label: String
    var value: CurrentStep.PortValue
}

extension StitchAIPortValueDescription: Encodable {
    enum CodingKeys: String, CodingKey {
        case label
        case valueType
        case value
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let nodeType = self.value.nodeType
        
        try container.encodeIfPresent(self.label != "" ? self.label : nil,
                                      forKey: .label)
        try container.encode(nodeType.asLLMStepNodeType,
                             forKey: .valueType)
        try container.encode(self.value.anyCodable,
                             forKey: .value)
    }
}
