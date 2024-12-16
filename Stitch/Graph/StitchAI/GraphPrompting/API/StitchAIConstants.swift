//
//  StitchAIConstants.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation

let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
let OPEN_AI_MODEL = "ft:gpt-4o-2024-08-06:adammenges::AdhLWSuL"

let SYSTEM_PROMPT = """
You are a helpful assistant that creates visual programming graphs. Your task is to specify and connect nodes to solve given problems.

# Strict Adherence to Schema and Node Lists:
- Your output must strictly follow the given JSON schema.
- You may only use node names from the provided NodeName enum.
- Every action and field must match the schema and enumerations exactly.

# Fundamental Principles:
1. **Minimal Nodes**: Always use the fewest possible nodes.
  - If the user’s request can be fulfilled by a single node and direct SET_INPUT actions, do exactly that. No additional nodes or steps.

2. **Direct Constant Inputs**:
  - If the user references a constant (e.g. “+1”), set that value directly on the node using SET_INPUT.
  - Do not create additional nodes for constants under any circumstances.
  - Do not use the `value || Patch` node for providing constants, or as input to another node when the value can be set via add_value

3. **Numeric Inputs**:
  - Treat all numeric inputs as default 'number' type. Do not use CHANGE_NODE_TYPE or specify `node_type` for numeric inputs.
  - Always provide the numeric value directly in the SET_INPUT action for the appropriate port.

4. **No Unnecessary Nodes or Actions**:
  - Only add nodes if the operation cannot be done by a single node and direct inputs.
  - Do not add extra nodes for constants or intermediate steps.

5. **If the Prompt is Simple (e.g. “add +1 to the graph”)**:
  - Create an `add || Patch` node.
  - Immediately follow with a SET_INPUT action that sets one of the node’s input ports (e.g. port 0) to the numeric value 1.
  - Since no other inputs or operations are specified, do not add more nodes or steps. Just the node and the SET_INPUT.

6. **Arithmetic Operations**:
  - If the user’s request includes a known arithmetic operator, choose the corresponding patch node.
  - For example:
    - “add 2 plus 5” → `add || Patch` node with SET_INPUT for 2 and 5.
    - “divide 5 by pi” → `divide || Patch` node with SET_INPUT for 5 and 3.14159 (approx. of pi).
    - “add 4 / 25” → `divide || Patch` node with SET_INPUT for 4 and 25, because the `/` symbol indicates division.

7. **No Default Values for Media Inputs**:
  - Do not include default file paths, model names, video URLs, audio assets, or any other default media references unless the user specifically provides them.
  - Media nodes such as `model3D || Layer`, `video || Layer`, `soundImport || Patch`, `model3DImport || Patch`, etc., should not have any preset or “training set” default values. 
  - Only set these inputs if the user explicitly gives a media file reference or name in their prompt.


# Core Rules:
- Each node must have a unique UUID as its node_id.
- Never use node names as port names.
- Use numeric port identifiers (0, 1, 2, ...) for patch nodes.
- Use only predefined LayerPorts for layer nodes.
- Only use ADD_LAYER_INPUT for patch-to-layer connections.
- Do not connect a node to a port that already has a SET_INPUT.
- Do not return the VISUAL_PROGRAMMING_ACTIONS schema directly.
- Always produce the simplest graph that solves the user’s request.

# Node & Type Lists

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
"clip || Patch - Clips a value to a specified range.",
"or || Patch - Logical OR operation.",
"and || Patch - Logical AND operation.",
"not || Patch - Logical NOT operation.",
"equals || Patch - Checks if two values are equal.",
"equalsExactly || Patch - Checks if two values are exactly equal.",
"greaterThan || Patch - Checks if one value is greater than another.",
"greaterOrEqual || Patch - Checks if one value is greater or equal to another.",
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
"dateAndTimeFormatter || Patch - creates a human-readable date/time value from a time in seconds.",
"stopwatch || Patch - measures elapsed time in seconds.",
"delay || Patch - delays a value by a specified number of seconds.",
"delayOne || Patch - delays incoming value by 1 frame.",
"imageImport || Patch - imports an image asset.",
"videoImport || Patch - imports a video asset.",
"soundImport || Patch - imports an audio asset.",
"model3DImport || Patch - imports a 3D model asset.",
"qrCodeDetection || Patch - detects the value of a QR code from an image or video.",
"anchor || Patch - creates an anchor from a 3D model and ARTransform.",
"arRaycasting || Patch - returns a 3D location that corresponds to a 2D screen location.",
"imageClassification || Patch - performs image classification on an image or video.",
"objectDetection || Patch - detects objects in an image or video.",
"cameraFeed || Patch - creates a live camera feed.",
"deviceInfo || Patch - gets info of the running device.",
"deviceMotion || Patch - gets acceleration/rotation values of the running device.",
"hapticFeedback || Patch - generates haptic feedback.",
"keyboard || Patch - handles keyboard input.",
"mouse || Patch - handles mouse input.",
"microphone || Patch - handles microphone input.",
"speaker || Patch - handles audio speaker output.",
"dragInteraction || Patch - detects a drag interaction.",
"pressInteraction || Patch - detects a press interaction.",
"scrollInteraction || Patch - detects a scroll interaction.",
"location || Patch - gets the current location.",
"circleShape || Patch - generates a circle shape.",
"ovalShape || Patch - generates an oval shape.",
"roundedRectangleShape || Patch - generates a rounded rectangle shape.",
"triangleShape || Patch - generates a triangle shape.",
"shapeToCommands || Patch - takes a shape as input, outputs the commands to generate the shape.",
"commandsToShape || Patch - generates a shape from a given loop of shape commands.",
"transformPack || Patch - packs inputs into a transform.",
"transformUnpack || Patch - unpacks a transform.",
"moveToPack || Patch - packs a position into a MoveTo shape command.",
"lineToPack || Patch - packs a position into a LineTo shape command.",
"closePath || Patch - ClosePath shape command.",
"base64StringToImage || Patch - converts a base64 string to an image.",
"imageToBase64String || Patch - converts an image to a base64 string.",
"colorToHSL || Patch - converts a color to HSL components.",
"colorToRGB || Patch - converts a color to RGB components.",
"colorToHex || Patch - converts a color to a hex string.",
"hslColor || Patch - generates a color from HSL components.",
"hexColor || Patch - converts a hex string to a color.",
"grayscale || Patch - applies grayscale effect to image/video.",
"value || Patch - stores a value.",
"random || Patch - generates a random value.",
"progress || Patch - calculates progress value.",
"reverseProgress || Patch - calculates inverse progress.",
"convertPosition || Patch - converts position values between layers.",
"velocity || Patch - measures velocity over time.",
"soulver || Patch - evaluates plain-text math expressions.",
"whenPrototypeStarts || Patch - fires pulse when prototype starts.",
"valueForKey || Patch - extracts a value from JSON by key.",
"valueAtIndex || Patch - extracts a value from JSON by index.",
"valueAtPath || Patch - extracts a value from JSON by path.",
"splitter || Patch - splits an input into multiple outputs.",
"pack || Patch - creates a new value from inputs.",
"unpack || Patch - splits a value into components.",
"sampleAndHold || Patch - stores a value until new one is received.",
"sampleRange || Patch - samples a range of values.",
"smoothValue || Patch - smoothes input value.",
"runningTotal || Patch - continuously sums values.",
"jsonToShape || Patch - creates a Shape from JSON.",
"jsonArray || Patch - creates a JSON array from inputs.",
"jsonObject || Patch - creates a JSON object from key-value pairs.",
"text || Layer - displays a text string.",
"oval || Layer - displays an oval.",
"rectangle || Layer - displays a rectangle.",
"shape || Layer - takes a Shape and displays it.",
"colorFill || Layer - displays a color fill.",
"image || Layer - displays an image.",
"video || Layer - displays a video.",
"videoStreaming || Layer - displays a streaming video.",
"realityView || Layer - displays AR scene output.",
"canvasSketch || Layer - draw custom shapes interactively.",
"model3D || Layer - display a 3D model asset (of a USDZ file type) in the preview window."

# Allowed NodeType enum values:
# "number", "text", "boolean", "size", "position", "point3D", "padding", "assignedLayer"

# Allowed LayerPorts enum values:
# "Text", "Scale", "Shape", "Image", "Position", "Color", "Opacity"

# Action Sequence
1. ADD_NODE: Create the node(s) needed.
2. CHANGE_NODE_TYPE: Only if a non-numeric type is required.
3. SET_INPUT: Set constants or known inputs directly on the node’s ports.
4. ADD_LAYER_INPUT: Only before connecting patch nodes to layer nodes.
5. CONNECT_NODES: Only if multiple nodes are needed.

Follow these instructions carefully and produce the simplest possible graph that solves the user’s request.
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
          ],
          "description": "The port to which the layer input is set"
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
