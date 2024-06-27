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
    let actions: LLMActions
    let prompt: String // user-entered
}

extension LLMActions {
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
         setInput = "Set Input",
         addEdge = "Add Edge",
         changeNodeType = "Change Node Type",
         addLayerInput = "Add Layer Input",
         addLayerOutput = "Add Layer Output"
}

typealias LLMActions = [LLMAction]

enum LLMAction: Equatable {
    case addNode(LLMAddNode),
         moveNode(LLMMoveNode),
         addEdge(LLMAddEdge),
         setInput(LLMSetInputAction),
         changeNodeType(LLMAChangeNodeTypeAction),
         addLayerInput(LLMAddLayerInput),
         addLayerOutput(LLMAddLayerOutput)
}

//extension LLMAction: Codable {
extension LLMAction: Encodable, Decodable {
    
    // Top level coding keys an LLM-action may contain
    enum CodingKeys: String, CodingKey {
        case action,
             
             // creating node
             node,
             
             // moving node
             translation,
             
             // creating edge
             from, to,
             
             // setting input (`field` = port coordinate)
             field, value,
        
            // changing node type, setting field
            nodeType,
        
            // label of a layer input or output
            port
    }

    // where was this decoder code originally from?
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // the `type` key, whether it's "lineTo" or "moveTo"
        
        // will be a string
        let action = try container.decode(String.self, forKey: .action)

        switch action {
        
        case LLMActionNames.addNode.rawValue:
            log("LLMAction: Decoder: decoding .addNode")
            let node = try container.decode(String.self, forKey: .node)
            self = .addNode(.init(node: node))
        
        case LLMActionNames.moveNode.rawValue:
            log("LLMAction: Decoder: decoding .moveNode")
            let node = try container.decode(String.self, forKey: .node)
            let port = try container.decode(String.self, forKey: .port)
            let translation = try container.decode(LLMMoveNodeTranslation.self, forKey: .translation)
            self = .moveNode(.init(node: node,
                                   port: port,
                                   translation: translation))
            
        case LLMActionNames.addEdge.rawValue:
            log("LLMAction: Decoder: decoding .addEdge")
            let from = try container.decode(LLMPortCoordinate.self, forKey: .from)
            let to = try container.decode(LLMPortCoordinate.self, forKey: .to)
            self = .addEdge(.init(from: from, to: to))
            
        case LLMActionNames.setInput.rawValue:
            log("LLMAction: Decoder: decoding .setInput")
            let field = try container.decode(LLMPortCoordinate.self, forKey: .field)
            log("LLMAction: Decoder: decoding .setInput: decoded field")
            let value = try container.decode(JSONFriendlyFormat.self, forKey: .value)
            log("LLMAction: Decoder: decoding .setInput: decoded value")
            let nodeType = try container.decode(String.self, forKey: .nodeType)
            log("LLMAction: Decoder: decoding .setInput: decoded nodeType")
            self = .setInput(.init(field: field, value: value, nodeType: nodeType))
                
        case LLMActionNames.changeNodeType.rawValue:
            log("LLMAction: Decoder: decoding .changeNodeType")
            let node = try container.decode(String.self, forKey: .node)
            let nodeType = try container.decode(String.self, forKey: .nodeType)
            self = .changeNodeType(.init(node: node, nodeType: nodeType))
            
        
        case LLMActionNames.addLayerInput.rawValue:
            log("LLMAction: Decoder: decoding .addLayerInput")
            let node = try container.decode(String.self, forKey: .node)
            let port = try container.decode(String.self, forKey: .port)
            self = .addLayerInput(.init(node: node, port: port))
        
        case LLMActionNames.addLayerOutput.rawValue:
            log("LLMAction: Decoder: decoding .addLayerOutput")
            let node = try container.decode(String.self, forKey: .node)
            let port = try container.decode(String.self, forKey: .port)
            self = .addLayerOutput(.init(node: node, port: port))
        
        default:
            fatalErrorIfDebug("LLMAction: decoder: unrecognized action")
            self = .moveNode(.init(node: "", port: "", translation: .init(x: 0, y: 0)))
            return
        }
    }

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
            try container.encode(x.port, forKey: .port)
            try container.encode(x.translation, forKey: .translation)
            
        case .addEdge(let x):
            try container.encode(x.action, forKey: .action)
            try container.encode(x.from, forKey: .from)
            try container.encode(x.to, forKey: .to)
            
        case .setInput(let x):
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
