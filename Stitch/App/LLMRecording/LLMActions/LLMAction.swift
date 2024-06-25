//
//  LLMRecording.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/11/24.
//

import Foundation
import SwiftUI
import SwiftyJSON
import StitchSchemaKit

/// What we write to JSON/JSONL file
struct LLMRecordingData: Equatable, Encodable {
    let actions: [LLMAction]
    let prompt: String // user-entered
}


extension [LLMAction] {
    func asJSON() -> JSON? {
        do {
            let data = try JSONEncoder().encode(self)
            let json = try JSON(data: data)
            log("[LLMAction]: asJSON: encoded json: \(json)")
            return json
        } catch {
            log("[LLMAction]: asJSON: error: \(error)")
            return nil
        }
    }
        
    func asJSONDisplay() -> String {
        self.asJSON()?.description ?? "No LLM-Acceptable Actions Detected"
    }
}

enum LLMActionNames: String, Equatable {
    case addNode = "Add Node",
         moveNode = "Move Node",
         setField = "Set Field",
         addEdge = "Add Edge",
         changeNodeType = "Change Node Type",
         addLayerInput = "Add Layer Input",
         addLayerOutput = "Add Layer Output"
}

//enum LLMAction: Equatable, Codable {
enum LLMAction: Equatable {
    case addNode(LLMAddNode),
         moveNode(LLMMoveNode),
         addEdge(LLMAddEdge),
         setField(LLMSetFieldAction),
         changeNodeType(LLMAChangeNodeTypeAction),
         addLayerInput(LLMAddLayerInput),
         addLayerOutput(LLMAddLayerOutput)
}

//extension LLMAction: Codable {
extension LLMAction: Encodable {
    
    // Top level coding keys an LLM-action may contain
    enum CodingKeys: String, CodingKey {
        case action,
             
             // creating node
             node,
             
             // moving node
             translation,
             
             // creating edge
             from, to,
             
             // setting field
             field, value,
        
            // changing node type, setting field
            nodeType,
        
            // label of a layer input or output
            port
    }

//    public init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//
//        // the `type` key, whether it's "lineTo" or "moveTo"
//        let type = try container.decode(LLMAction.self, forKey: .type)
//
//        switch type {
//
//        case .addNode(value: llmAddNode):
//            let point = try container.decode(Add.self, forKey: .addNode)
//            self = .lineTo(point: point)
//
//        case .moveNode(value: llmMoveNode):
//            let point = try container.decode(PathPoint.self, forKey: .moveNode)
//            self = .moveTo(point: point)
//        }
//
//    }

    // Note: we encode a key-value pair (e.g. "type: moveTo")
    // which we don't actually use in the enum.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .addNode(let x):
            try container.encode(x.action, forKey: .action)
            try container.encode(x.node, forKey: .node)
        
        case .moveNode(let x):
            try container.encode(x.action, forKey: .action)
            try container.encode(x.node, forKey: .node)
            try container.encode(x.translation, forKey: .translation)
            
        case .addEdge(let x):
            try container.encode(x.action, forKey: .action)
            try container.encode(x.from, forKey: .from)
            try container.encode(x.to, forKey: .to)
            
        case .setField(let x):
            try container.encode(x.action, forKey: .action)
            try container.encode(x.field, forKey: .field)
            try container.encode(x.value, forKey: .value)
            try container.encode(x.nodeType, forKey: .nodeType)
        
        case .changeNodeType(let x):
            try container.encode(x.action, forKey: .action)
            try container.encode(x.node, forKey: .node)
            try container.encode(x.nodeType, forKey: .nodeType)
            
        case .addLayerInput(let x):
            try container.encode(x.action, forKey: .action)
            try container.encode(x.node, forKey: .node)
            try container.encode(x.port, forKey: .port)
            
        case .addLayerOutput(let x):
            try container.encode(x.action, forKey: .action)
            try container.encode(x.node, forKey: .node)
            try container.encode(x.port, forKey: .port)
        }
    }
}
