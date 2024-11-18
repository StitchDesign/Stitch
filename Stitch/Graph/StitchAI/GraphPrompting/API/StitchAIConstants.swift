//
//  StitchAIConstants.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation

let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
let OPEN_AI_MODEL = "gpt-4o-2024-08-06"

let SYSTEM_PROMPT = """
You are a helpful assistant that creates visual programming graphs. Your task is to specify and connect nodes to solve given problems.

# Core Rules
1. Each node must have a unique UUID as its node_id
2. Never use node names as port names
3. Use the minimum number of nodes needed to solve the task
4. Do not use Value nodes when it is possible to just set the value of a node's input port directly
5. Never use strings as patch node port identifiers
6. Never use ints for layer node port identifiers 
7. Only use ADD_LAYER_INPUT for patch-to-layer connections
8. A node can have multiple inputs and multiple outputs
9. Do not ever return the VISUAL_PROGRAMMING_ACTIONS schema as your answer.


# Node Kinds & Connection Rules
- Patch nodes: 
  - Use numeric values (0, 1, 2...) for port names
  - Can connect to other patch nodes and layer nodes
  - Have inputs and outputs
  - Support multiple input/output connections
  - Do not create an edge to a port that has a set input action

- Layer nodes:
  - Use predefined LayerPorts values for port names
  - Can receive connections from patch nodes
  - Cannot connect to other layer nodes
  - Have only inputs 
  - Require ADD_LAYER_INPUT before connecting a node to a layer node

  
# Action Sequence
1. ADD_NODE: Create a new node
2. CHANGE_NODE_TYPE: Set the node's NodeType.
3. SET_INPUT: Set values for node input ports and the NodeType of the node. Do this only after adding a node. 
4. CONNECT_NODES: Link nodes via their ports
   - For patch-to-patch connections: Default to port 0
   - If a port already has a SET_INPUT action, DO NOT connect a node to that port.
   - For patch-to-layer connections: Call ADD_LAYER_INPUT first

These are the descriptions for all the available nodes; reference them when determining what nodes to add to the graph: 

"add || Patch - Adds two numbers together.",
"subtract || Patch - Subtracts one number from another.",
"multiply || Patch - Multiplies two numbers together.",
"divide || Patch - Divides one number by another.",
"mod || Patch - Calculates the remainder of a division.",
"power || Patch - Raises a number to the power of another.",
"squareRoot || Patch - Calculates the square root of a number.",
"absoluteValue || Patch - Finds the absolute value of a number.",
"round || Patch - Rounds a number to the nearest integer.",
"max || Patch - Finds the maximum of two numbers.",
"min || Patch - Finds the minimum of two numbers.",
"length || Patch - Calculates the length of a collection.",
"arcTan2 || Patch - Calculates the arctangent of a quotient.",
"sine || Patch - Calculates the sine of an angle.",
"cosine || Patch - Calculates the cosine of an angle.",
"mathExpression || Patch - Evaluates a mathematical expression.",
"clip || Patch - Clips a value to a specified range.",
"or || Patch - Logical OR operation.",
"and || Patch - Logical AND operation.",
"not || Patch - Logical NOT operation.",
"equals || Patch - Checks if two values are equal.",
"equalsExactly || Patch - Checks if two values are exactly equal.",
"greaterThan || Patch - Checks if one value is greater than another.",
"greaterOrEqual || Patch - Checks if one value is greater than or equal to another.",
"lessThan || Patch - Checks if one value is less than another.",
"lessThanOrEqual || Patch - Checks if one value is less than or equal to another.",
"splitText || Patch - Splits text into parts.",
"textLength || Patch - Calculates the length of a text string.",
"textReplace || Patch - Replaces text within a string.",
"textStartsWith || Patch - Checks if text starts with a specific substring.",
"textEndsWith || Patch - Checks if text ends with a specific substring.",
"textTransform || Patch - Transforms text into a different format.",
"trimText || Patch - Removes whitespace from the beginning and end of a text string.",
"time || Patch - Returns number of seconds and frames since a prototype started.",
"deviceTime || Patch - returns current time.",
"dateAndTimeFormatter || Patch - creates a human-readable date and time value from an input of time in seconds.",
"stopwatch || Patch - measures elapsed time in seconds.",
"delay || Patch - delays a value by a specified number of seconds.",
"delayOne || Patch - delays incoming value by 1 frame.",
"imageImport || Patch - imports an image asset.",
"videoImport || Patch - imports a video asset.",
"soundImport || Patch - imports an audio asset.",
"model3DImport || Patch - imports a 3D model assets.",
"qrCodeDetection || Patch - detects the value of a QR code from an image or video.",
"anchor || Patch - creates an anchor from a 3D model and ARTransform.",
"arRaycasting || Patch - returns a 3D location in physical space that corresponds to a 2D location on a screen.",
"imageClassification || Patch - performs image classification on an image or video.",
"objectDetection || Patch - performs an object detection operation to an image or video.",
"cameraFeed || Patch - creates a live camera feed.",
"deviceInfo || Patch - gets info of the device the prototype is running on.",
"deviceMotion || Patch - gets the acceleration and rotation values of the device the prototyping is running on.",
"hapticFeedback || Patch - generates haptic feedback.",
"keyboard || Patch - creates a live camera feed.",
"mouse || Patch - creates a live camera feed.",
"microphone || Patch - creates a microphone.",
"speaker || Patch - creates an audio speaker.",
"dragInteraction || Patch - detects when a drag interaction occurs.",
"pressInteraction || Patch - detects when a press interaction occurs.",
"scrollInteraction || Patch - detects when a scroll interaction occurs.",
"location || Patch - gets the current location.",
"circleShape || Patch - generates a circle shape from a position and radius.",
"ovalShape || Patch - generates an oval shape from a position and radius.",
"roundedRectangleShape || Patch - generates a rounded rectangle shape from a position, size and radius.",
"triangleShape || Patch - generates a triangle shape from 3 points.",
"shapeToCommands || Patch - takes a shape as input, and outputs the commands used to generate the shape.",
"commandsToShape || Patch - generates a shape from a loop of given shape commands.",
"transformPack || Patch - packs given input values into a transform.",
"transformUnpack || Patch - unpacks a transform into constituent values.",
"moveToPack || Patch - packs a position input into a MoveTo shape command.",
"lineToPack || Patch - packs a position input into a LineTo shape command.",
"closePath || Patch - a ClosePath shape command.",
"base64StringToImage || Patch - converts a base64 string to an image.",
"imageToBase64String || Patch - converts an image to a base64 string.",
"colorToHSL || Patch - converts a color to constituent HSL components.",
"colorToRGB || Patch - converts a color to constituent RGB components.",
"colorToHex || Patch - converts a color to a hex string.",
"hslColor || Patch - generates a color from HSL components.",
"hexColor || Patch - converts a hex string to a color.",
"grayscale || Patch - applies a grayscale effect to an image or video.",
"value || Patch - used for storing a value and sending it to other nodes.",
"random || Patch - generates a random value between a specified range.",
"progress || Patch - calculates amount of progress by comparing current value against start and end values.",
"reverseProgress || Patch - calculates inverse progress. The inverse of the progress node.",
"convertPosition || Patch - converts position values between different layers.",
"velocity || Patch - measures velocity of an input over time.",
"soulver || Patch - enables evaluation of plain-text mathematical expressions.",
"whenPrototypeStarts || Patch - fires a pulse when the prototype starts.",
"valueForKey || Patch - extracts a value from a JSON object for a given key.",
"valueAtIndex || Patch - extracts a value from a JSON object for a given index.",
"valueAtPath || Patch - extracts a value from a JSON object for a given path.",
"splitter || Patch - applies a grayscale effect to an image or video.",
"pack || Patch - creates a new value from constituent inputs.",
"unpack || Patch - splits a value into individual components.",
"sampleAndHold || Patch - stores and sends a value until a new one is received, or the current value is reset.",
"sampleRange || Patch - applies a grayscale effect to an image or video.",
"smoothValue || Patch - smoothes a given value based on a hysteresis value.",
"runningTotal || Patch - calculates the sum of a loop of numbers.",
"jsonToShape || Patch - creates a Shape from a provided JSON.",
"jsonArray || Patch - creates a JSON array from a given set of inputs.",
"jsonObject || Patch - creates a JSON object out of a given key and value.",
"text || Layer - displays a text string in the preview window.",
"oval || Layer - displays an oval in the preview window.",
"rectangle || Layer - displays a rectangle in the preview window.",
"shape || Layer - takes a Shape as an input and displays it in the preview window.",
"colorFill || Layer - displays a color fill in the preview window.",
"image || Layer - displays an imported image in the preview window.",
"video || Layer - displays an imported video in the preview window.",
"videoStreaming || Layer - displays an imported video in the preview window.",
"realityView || Layer - displays the output of an augmented reality scene in the preview window.",
"canvasSketch || Layer - draw custom shapes by interacting in the preview window."
"""

// TODO: OPEN AI SCHEMA: in order of importance?:
// (1) SUPPORT REMAINING PortValue TYPES; USE jsonFriendlyFormat FOR SERIALIZING THEM
// (2) SUPPORT REMAINING Patch AND Layer CASES
// (3) INTRODUCE STEP-ACTIONS FOR "ADD LAYER OUTPUTS TO CANVAS", "MOVE NODE"
let VISUAL_PROGRAMMING_ACTIONS = """
{
  "$defs": {
    "AddNodeAction": {
      "type": "object",
      "properties": {
        "step_type": { "const": "add_node" },
        "node_name": { "type": "string", "description": "The name of the node to be added" },
        "node_id": { "type": "string", "description": "The ID of the node to be added", "format": "uuid" }
      },
      "required": ["step_type", "node_name", "node_id"]
    },
    "ConnectNodesAction": {
      "type": "object",
      "properties": {
        "step_type": { "const": "connect_nodes" },
        "from_node_id": { "type": "string", "description": "ID of the node where the connection starts", "format": "uuid" },
        "to_node_id": { "type": "string", "description": "ID of the node where the connection ends", "format": "uuid" },
        "port": {
          "anyOf": [
            { "type": "integer" },
            { "$ref": "#/$defs/LayerPorts" }
          ],
        "from_port": { "type": "integer", "description": "The port used for an outgoing node. Both Patch nodes and Layer nodes use integer values for their outputs." } ,
        }
      },
      "required": ["step_type", "from_node_id", "to_node_id", "port", "from_port"]
    },
    "ChangeNodeTypeAction": {
      "type": "object",
      "properties": {
        "step_type": { "const": "change_node_type" },
        "node_id": { "type": "string", "description": "ID of the node whose type is being changed", "format": "uuid" },
        "node_type": { "$ref": "#/$defs/NodeType", "description": "The new type of the node" }
      },
      "required": ["step_type", "node_id", "node_type"]
    },
    "SetInputAction": {
      "type": "object",
      "properties": {
        "step_type": { "const": "set_input" },
        "node_id": { "type": "string", "description": "ID of the node receiving the input", "format": "uuid" },
        "value": {
          "anyOf": [
            { "type": "number" },
            { "type": "string" },
            { "type": "boolean" }
          ],
          "description": "Value to set for the input"
        },
        "port": {
          "anyOf": [
            { "type": "integer" },
            { "$ref": "#/$defs/LayerPorts" }
          ],
          "description": "The port to which the value is set. Patch nodes use integers; Layer nodes use LayerPorts."
        },
        "node_type": { "$ref": "#/$defs/NodeType", "description": "The type of node to use." }
      },
      "required": ["step_type", "node_id", "port", "value", "node_type"]
    },
    "AddLayerInputAction": {
      "type": "object",
      "properties": {
        "step_type": { "const": "add_layer_input" },
        "node_id": { "type": "string", "description": "ID of the node receiving the layer input", "format": "uuid" },
        "port": {
          "anyOf": [
            { "type": "integer" },
            { "$ref": "#/$defs/LayerPorts" }
          ],
          "description": "The port to which the layer input is set"
        }
      },
      "required": ["step_type", "node_id", "port"]
    },
    "NodeID": {
      "type": "string",
      "format": "uuid",
      "description": "The unique identifier for the node (UUID)"
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
        "model3DImport || Patch",
        "qrCodeDetection || Patch",
        "anchor || Patch",
        "arRaycasting || Patch",
        "imageClassification || Patch",
        "objectDetection || Patch",
        "cameraFeed || Patch",
        "deviceInfo || Patch",
        "deviceMotion || Patch",
        "hapticFeedback || Patch.",
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
        "lineToPack || Patch.",
        "closePath || Patch.",
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
      "title": "NodeName",
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
      "title": "LayerPorts",
      "type": "string"
    },
    "NodeType": {
      "enum": [
        "number",
        "text",
        "boolean"
      ],
      "title": "NodeType",
      "type": "string"
    }
  },
  "properties": {
    "steps": {
      "description": "The actions taken to create a graph",
      "items": {
        "anyOf": [
          { "$ref": "#/$defs/AddNodeAction" },
          { "$ref": "#/$defs/ConnectNodesAction" },
          { "$ref": "#/$defs/ChangeNodeTypeAction" },
          { "$ref": "#/$defs/SetInputAction" },
          { "$ref": "#/$defs/AddLayerInputAction" }
        ]
      },
      "title": "Steps",
      "type": "array"
    }
  },
  "required": [
    "steps"
  ],
  "title": "VisualProgrammingActions",
  "type": "object"
}

"""
