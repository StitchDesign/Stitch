//
//  AIGraphCreationContentJSON_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import StitchSchemaKit
import SwiftUI

enum AIGraphCreationContentJSON_V0: StitchSchemaVersionable {
    // MARK: - ensure versions are correct
    static let version = StitchAISchemaVersion._V0
    typealias PreviousInstance = Self.AIGraphCreationContentJSON
    // MARK: - end
    
    /// Represents the structured content of a message
    struct AIGraphCreationContentJSON: Codable {
        var steps: [Step_V0.Step] // Array of steps in the visual programming sequence
    }
}

extension AIGraphCreationContentJSON_V0.AIGraphCreationContentJSON: StitchVersionedCodable {
    // TODO: create migration for v1
    public init(previousInstance: AIGraphCreationContentJSON_V0.AIGraphCreationContentJSON) {
        fatalError()
    }
}

extension AIGraphCreationContentJSON_V0.AIGraphCreationContentJSON {
    static func exampleData() -> Self {
        let id0 = UUID()
        let id1 = UUID()
        
        let addNode = StepActionAddNode(nodeId: id0, nodeName: .patch(.add))
        let textNode = StepActionAddNode(nodeId: id1, nodeName: .layer(.text))
        
        let setInput1 = StepActionSetInput(nodeId: id0,
                                          port: .portIndex(0),
                                          value: .number(3),
                                          valueType: .number)
        let setInput2 = StepActionSetInput(nodeId: id0,
                                          port: .portIndex(1),
                                          value: .number(5),
                                          valueType: .number)
        let changeType = StepActionChangeValueType(nodeId: id0,
                                                  valueType: .string)
        
        let makeConnection = StepActionConnectionAdded(
            port: .keyPath(.init(layerInput: .text,
                                 portType: .packed)),
            toNodeId: id1,
            fromPort: 0,
            fromNodeId: id0)
        
        let steps: [Step] = [
            addNode.toStep,
            textNode.toStep,
            setInput1.toStep,
            setInput2.toStep,
            changeType.toStep,
            makeConnection.toStep
        ]
        
        return .init(steps: steps)
    }
}
