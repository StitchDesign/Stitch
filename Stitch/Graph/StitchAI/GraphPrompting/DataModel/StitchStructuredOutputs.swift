//
//  StructuredOutputs.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/16/25.
//

import SwiftUI
import StitchSchemaKit
import SwiftyJSON

extension StitchAIManager {
    static let structuredOutputs = StitchAIStructuredOutputsPayload()
}

struct StitchAIStructuredOutputsPayload {
//    var defs = StitchAIStructuredOutputsDefinitions()
    var schema = """
{
  "$defs": {
    "AddNodeAction": {
      "type": "object",
      "properties": {
        "step_type": { "type": "string", "const": "add_node" },
        "node_name": { "$ref": "#/$defs/NodeName" },
        "node_id": { "type": "string" },
        "node_type": { "$ref": "#/$defs/NodeType" }
      },
      "required": ["step_type", "node_name", "node_id", "node_type"],
      "additionalProperties": false
    },
    "ConnectNodesAction": {
      "type": "object",
      "properties": {
        "step_type": { "type": "string", "const": "connect_nodes" },
        "from_node_id": { "type": "string" },
        "to_node_id": { "type": "string" },
        "port": {
          "anyOf": [
            { "type": "integer" },
            { "$ref": "#/$defs/LayerPorts" }
          ]
        },
        "from_port": { "type": "integer" }
      },
      "required": ["step_type", "from_node_id", "to_node_id", "port", "from_port"],
      "additionalProperties": false
    },
    "ChangeNodeTypeAction": {
      "type": "object",
      "properties": {
        "step_type": { "type": "string", "const": "change_node_type" },
        "node_id": { "type": "string" },
        "node_type": { "$ref": "#/$defs/NodeType" }
      },
      "required": ["step_type", "node_id", "node_type"],
      "additionalProperties": false
    },
    "SetInputAction": {
      "type": "object",
      "properties": {
        "step_type": { "type": "string", "const": "set_input" },
        "node_id": { "type": "string" },
        "value": {
          "anyOf": [
            { "type": "number" },
            { "type": "string" },
            { "type": "boolean" },
            { "type": "object" }
          ]
        },
        "port": {
          "anyOf": [
            { "type": "integer" },
            { "$ref": "#/$defs/LayerPorts" }
          ]
        },
        "node_type": { "$ref": "#/$defs/NodeType" }
      },
      "required": ["step_type", "node_id", "port", "value", "node_type"],
      "additionalProperties": false
    },
    "AddLayerInputAction": {
      "type": "object",
      "properties": {
        "step_type": { "type": "string", "const": "add_layer_input" },
        "node_id": { "type": "string" },
        "port": {
          "anyOf": [
            { "type": "integer" },
            { "$ref": "#/$defs/LayerPorts" }
          ]
        }
      },
      "required": ["step_type", "node_id", "port"],
      "additionalProperties": false
    },
    "NodeID": {
      "type": "string",
      "description": "The unique identifier for the node (UUID)",
      "additionalProperties": false
    },
    "NodeName": {
      "enum": [
        "add || Patch",
        "subtract || Patch",
        "multiply || Patch",
        "divide || Patch",
        "mod || Patch",
        "power || Patch",
        "squareRoot || Patch",
        "absoluteValue || Patch",
        "round || Patch",
        "max || Patch",
        "min || Patch",
        "length || Patch",
        "arcTan2 || Patch",
        "sine || Patch",
        "cosine || Patch",
        "mathExpression || Patch",
        "clip || Patch",
        "or || Patch",
        "and || Patch",
        "not || Patch",
        "equals || Patch",
        "equalsExactly || Patch",
        "greaterThan || Patch",
        "greaterOrEqual || Patch",
        "lessThan || Patch",
        "lessThanOrEqual || Patch",
        "splitText || Patch",
        "textLength || Patch",
        "textReplace || Patch",
        "textStartsWith || Patch",
        "textEndsWith || Patch",
        "textTransform || Patch",
        "trimText || Patch",
        "time || Patch",
        "deviceTime || Patch",
        "dateAndTimeFormatter || Patch",
        "stopwatch || Patch",
        "delay || Patch",
        "delayOne || Patch",
        "imageImport || Patch",
        "videoImport || Patch",
        "soundImport || Patch",
        "qrCodeDetection || Patch",
        "anchor || Patch",
        "arRaycasting || Patch",
        "imageClassification || Patch",
        "objectDetection || Patch",
        "cameraFeed || Patch",
        "deviceInfo || Patch",
        "deviceMotion || Patch",
        "hapticFeedback || Patch",
        "keyboard || Patch",
        "mouse || Patch",
        "microphone || Patch",
        "speaker || Patch",
        "dragInteraction || Patch",
        "pressInteraction || Patch",
        "scrollInteraction || Patch",
        "location || Patch",
        "circleShape || Patch",
        "ovalShape || Patch",
        "roundedRectangleShape || Patch",
        "triangleShape || Patch",
        "shapeToCommands || Patch",
        "commandsToShape || Patch",
        "transformPack || Patch",
        "transformUnpack || Patch",
        "moveToPack || Patch",
        "lineToPack || Patch",
        "closePath || Patch",
        "base64StringToImage || Patch",
        "imageToBase64String || Patch",
        "colorToHSL || Patch",
        "colorToRGB || Patch",
        "colorToHex || Patch",
        "hslColor || Patch",
        "hexColor || Patch",
        "grayscale || Patch",
        "value || Patch",
        "random || Patch",
        "progress || Patch",
        "reverseProgress || Patch",
        "convertPosition || Patch",
        "velocity || Patch",
        "soulver || Patch",
        "whenPrototypeStarts || Patch",
        "valueForKey || Patch",
        "valueAtIndex || Patch",
        "valueAtPath || Patch",
        "splitter || Patch",
        "pack || Patch",
        "unpack || Patch",
        "sampleAndHold || Patch",
        "sampleRange || Patch",
        "smoothValue || Patch",
        "runningTotal || Patch",
        "jsonToShape || Patch",
        "jsonArray || Patch",
        "jsonObject || Patch",
        "text || Layer",
        "oval || Layer",
        "rectangle || Layer",
        "shape || Layer",
        "colorFill || Layer",
        "image || Layer",
        "video || Layer",
        "videoStreaming || Layer",
        "realityView || Layer",
        "canvasSketch || Layer",
        "box || Layer",
        "sphere || Layer",
        "cylinder || Layer",
        "cone || Layer",
        "3dModel || Layer"
      ],
      "type": "string"
    },
    "NodeType": {
      "enum": [
        "string",
        "bool",
        "int",
        "color",
        "number",
        "layerDimension",
        "size",
        "position",
        "3dPoint",
        "4dPoint",
        "transform",
        "plane",
        "pulse",
        "media",
        "json",
        "networkRequestType",
        "none",
        "anchoring",
        "cameraDirection",
        "interactionId",
        "scrollMode",
        "textAlignment",
        "textVerticalAlignment",
        "fitStyle",
        "animationCurve",
        "lightType",
        "layerStroke",
        "strokeLineCap",
        "strokeLineJoin",
        "textTransform",
        "dateAndTimeFormat",
        "shape",
        "scrollJumpStyle",
        "scrollDecelerationRate",
        "delayStyle",
        "shapeCoordinates",
        "shapeCommand",
        "shapeCommandType",
        "orientation",
        "cameraOrientation",
        "deviceOrientation",
        "vnImageCropOption",
        "textDecoration",
        "textFont",
        "blendMode",
        "mapType",
        "progressIndicatorStyle",
        "mobileHapticStyle",
        "contentMode",
        "spacing",
        "padding",
        "sizingScenario",
        "pinToId",
        "deviceAppearance",
        "materialThickness",
        "anchorEntity"
      ],
      "type": "string"
    }
  },
  "properties": {
    "steps": {
      "description": "The actions taken to create a graph",
      "type": "array",
      "items": {
        "anyOf": [
          { "$ref": "#/$defs/AddNodeAction" },
          { "$ref": "#/$defs/ConnectNodesAction" },
          { "$ref": "#/$defs/ChangeNodeTypeAction" },
          { "$ref": "#/$defs/SetInputAction" },
          { "$ref": "#/$defs/AddLayerInputAction" }
        ]
      }
    }
  },
  "required": ["steps"],
  "title": "VisualProgrammingActions",
  "type": "object",
  "additionalProperties": false,
  "strict": true
}
"""
}

struct StitchAIStructuredOutputsSchema: OpenAISchemaCustomizable {
    static let title = "VisualProgrammingActions"
    
    var properties = StitchAIStepsSchema()
    
    var schema = OpenAISchema(type: .object,
                              required: ["steps"],
                              additionalProperties: false,
                              title: Self.title,
                              description: "Strictly follow the action sequence: 1. ADD_NODE, 2. CHANGE_VALUE_TYPE, 3. SET_INPUT, 4. CONNECT_NODES")
}

struct StitchAIStructuredOutputsDefinitions: Encodable {
    // Step actions
    let AddNodeAction = StepStructuredOutputs(StepActionAddNode.self)
    let ConnectNodesAction = StepStructuredOutputs(StepActionConnectionAdded.self)
//    let ChangeValueTypeAction = StepStructuredOutputs(StepActionChangeValueType.self)
    let SetInputAction = StepStructuredOutputs(StepActionSetInput.self)
 
    // Types
    let NodeID = OpenAISchema(type: .string,
                              additionalProperties: false,
                              description: "The unique identifier for the node (UUID)")
 
    let NodeName = OpenAISchemaEnum(values: NodeKind.getAiNodeDescriptions().map(\.nodeKind), description: "The type of node to be created")
 
    let ValueType = OpenAISchemaEnum(values: NodeType.allCases
        .filter { $0 != .none }
        .map { $0.asLLMStepNodeType }, description: "The type of value for the node")
 
    let LayerPorts = OpenAISchemaEnum(values: LayerInputPort.allCases
        .map { $0.asLLMStepPort }, description: "The available ports for layer connections")
 
    // Schema definitions for value types
    let NumberSchema = OpenAISchema(type: .number,
                                   additionalProperties: false,
                                   description: "A numeric value")
 
    let StringSchema = OpenAISchema(type: .string,
                                    additionalProperties: false,
                                    description: "A text value")
 
    let BooleanSchema = OpenAISchema(type: .boolean,
                                     additionalProperties: false,
                                     description: "A boolean value")
 
    let ObjectSchema = OpenAISchema(type: .object,
                                    required: [], additionalProperties: false,
                                    description: "A JSON object value",
                                    properties: [:]
)

}

struct StitchAIStepsSchema: Encodable {
    let steps = OpenAISchema(
        type: .array,
        additionalProperties: false,
        description: "The actions taken to create a graph",
        items: OpenAIGeneric(
            anyOf: [
                OpenAISchemaRef(ref: "AddNodeAction"),
                OpenAISchemaRef(ref: "ConnectNodesAction"),
//                OpenAISchemaRef(ref: "ChangeValueTypeAction"),
                OpenAISchemaRef(ref: "SetInputAction")
            ]
        )
    )
}

struct StepStructuredOutputs: OpenAISchemaCustomizable {
    var properties: StitchAIStepSchema
    var schema: OpenAISchema
    
    init<T>(_ stepActionType: T.Type) where T: StepActionable {
        let requiredProps = T.structuredOutputsCodingKeys.map { $0.rawValue }
        
        self.properties = T.createStructuredOutputs()
        self.schema = .init(type: .object,
                            required: requiredProps,
                            additionalProperties: false)
    }
    
    init(properties: StitchAIStepSchema,
         schema: OpenAISchema) {
        self.properties = properties
        self.schema = schema
    }
}

struct StitchAIStepSchema: Encodable {
    var stepType: StepType
    var nodeId: OpenAISchema? = nil
    var nodeName: OpenAISchemaRef? = nil
    var port: OpenAISchemaRef? = nil
    var fromPort: OpenAISchema? = nil
    var fromNodeId: OpenAISchema? = nil
    var toNodeId: OpenAISchema? = nil
    var value: OpenAIGeneric? = nil
    var valueType: OpenAISchemaRef? = nil
    
    func encode(to encoder: Encoder) throws {
        // Reuses coding keys from Step struct
        var container = encoder.container(keyedBy: Step.CodingKeys.self)
        
        let stepTypeSchema = OpenAISchema(type: .string,
                                          const: self.stepType.rawValue,
                                          additionalProperties: false)
        
        try container.encode(stepTypeSchema, forKey: .stepType)
        try container.encodeIfPresent(nodeId, forKey: .nodeId)
        try container.encodeIfPresent(nodeName, forKey: .nodeName)
        try container.encodeIfPresent(port, forKey: .port)
        try container.encodeIfPresent(fromPort, forKey: .fromPort)
        try container.encodeIfPresent(fromNodeId, forKey: .fromNodeId)
        try container.encodeIfPresent(toNodeId, forKey: .toNodeId)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(valueType, forKey: .valueType)
    }
}
