//
//  StitchAIConstants.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation

let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
let OPEN_AI_MODEL = "ft:gpt-4o-2024-08-06:adammenges::AdhLWSuL"

// TODO: OPEN AI SCHEMA: in order of importance?:
// (1) SUPPORT REMAINING PortValue TYPES; USE jsonFriendlyFormat FOR SERIALIZING THEM
// (2) SUPPORT REMAINING Patch AND Layer CASES
// (3) INTRODUCE STEP-ACTIONS FOR "ADD LAYER OUTPUTS TO CANVAS", "MOVE NODE"
let VISUAL_PROGRAMMING_ACTIONS_SCHEMA = """
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
            { "type": "boolean" }
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
        "value": {
          "anyOf": [
            { "type": "number" },
            { "type": "string" },
            { "type": "boolean" }
          ]
        },
        "port": {
          "anyOf": [
            { "type": "integer" },
            { "$ref": "#/$defs/LayerPorts" }
          ]
        }
      },
      "required": ["step_type", "node_id", "port", "value"],
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
        "model3DImport || Patch",
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
        "canvasSketch || Layer"
      ],
      "type": "string"
    },
    "NodeType": {
      "enum": [
        "number",
        "text",
        "boolean",
        "size",
        "position",
        "point3D",
        "padding",
        "assignedLayer"
      ],
      "type": "string"
    },
    "LayerPorts": {
      "enum": [
        "Text",
        "Scale",
        "Shape",
        "Image",
        "Position",
        "Color",
        "Opacity"
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
  "additionalProperties": false
}
"""
