//
//  StitchAINodeUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/13/25.
//

import SwiftUI
import StitchSchemaKit

extension CurrentStep.NodeKind {
    static func getAiNodeDescriptions() -> [StitchAINodeKindDescription_V31.StitchAINodeKindDescription] {
        // Filter out the scroll interaction node
        let allDescriptions = CurrentStep.Patch.allAiDescriptions + CurrentStep.Layer.allAiDescriptions
        return allDescriptions.filter { description in
            !description.nodeKind.contains("scrollInteraction")
        }
    }
}

/// Redundant copy for newest version, should Stitch AI and SSK versions diverge.
extension NodeKind {
    static func getAiNodeDescriptions() -> [StitchAINodeKindDescription] {
        // Filter out the scroll interaction node
        let allDescriptions = Patch.allAiDescriptions + Layer.allAiDescriptions
        return allDescriptions.filter { description in
            !description.nodeKind.contains("scrollInteraction")
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
                // Use node definitions, if available
                if let graphNode = patchOrLayer.graphNode {
                    return try .init(graphNode)
                }
                
                // Backup plan: create default node, extract data from there
                guard let defaultNode = patchOrLayer.createDefaultNode(id: .init(),
                                                                       activeIndex: .init(.zero),
                                                                       graphDelegate: graph) else {
                    fatalErrorIfDebug()
                    return nil
                }
                
                let inputs: [StitchAIPortValueDescription] = try defaultNode.inputsObservers.map { inputObserver in
                    let runtimeValue = inputObserver.getActiveValue(activeIndex: .init(.zero))
                    
                    // Backwards compat check for runtime's PortValue
                    let migratedValue = try runtimeValue.convert(to: CurrentStep.PortValue.self)
                    
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
        self.nodeKind = NodeInfo.graphKind.kind.asLLMStepNodeName
        let rowDefinitions = NodeInfo.rowDefinitions(for: NodeInfo.defaultUserVisibleType)
        
        do {
            self.inputs = try rowDefinitions.inputs.map {
                // Migrates PortValue data to supported AI version
                let migratedInput = try $0.defaultValues.first!.convert(to: CurrentStep.PortValue.self)
                
                return .init(label: $0.label,
                             value: migratedInput)
            }
            
            self.outputs = try rowDefinitions.outputs.map {
                let migratedOutput = try $0.value.convert(to: CurrentStep.PortValue.self)
                
                return .init(label: $0.label,
                             value: migratedOutput)
            }
        } catch {
            log("Error converting node types at StitchAINodeIODescription: \(error.localizedDescription)")
            throw StitchAIManagerError.portValueDescriptionNotSupported
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
