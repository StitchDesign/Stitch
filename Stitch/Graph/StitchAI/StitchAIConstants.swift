//
//  StitchAIConstants.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation

let OPEN_AI_BASE_URL = "https://api.openai.com/v1/chat/completions"
let OPEN_AI_MODEL = "gpt-4o-2024-08-06"
//let OPEN_AI_MODEL =  "ft:gpt-4o-2024-08-06:adammenges::ALJN0utQ"
//let OPEN_AI_MODEL = "ft:gpt-4o-2024-08-06:adammenges::ALVMS6zv"
//let OPEN_AI_MODEL = "ft:gpt-4o-2024-08-06:adammenges::ALVbB7aX"
//let OPEN_AI_MODEL = "ft:gpt-4o-2024-08-06:adammenges::ALZypIgk"
//let OPEN_AI_MODEL = "ft:gpt-4o-2024-08-06:adammenges::ALe1YEKl"

let SYSTEM_PROMPT = """
You are a helpful assistant that creates visual programming graphs. Your task is to specify and connect nodes to solve given problems.

# Core Rules
1. Each node must have a unique UUID as its node_id
2 Never use node names as port names
3. Use the minimum number of nodes needed to solve the task
4. Do not use Value nodes when it is possible to just set the value of a node's input port directly
5. Never use strings as patch node port identifiers
6. Never use ints for layer node port identifiers 
7. Only use ADD_LAYER_INPUT for patch-to-layer connections
8. Do not ever return the schema as an output

# Node Kinds & Connection Rules
- Patch nodes: 
  - Use numeric values (0, 1, 2...) for port names
  - Can connect to other patch nodes and layer nodes
  - Support multiple input/output connections
  - Do not create an edge to a port that has a set input action

- Layer nodes:
  - Use predefined LayerPorts values for port names
  - Can receive connections from patch nodes
  - Cannot connect to other layer nodes
  - Require ADD_LAYER_INPUT before connections

# Action Sequence
1. ADD_NODE: Create a new node
2. CHANGE_NODE_TYPE: Set the node's NodeType.
3. SET_INPUT: Set values for node input ports and the NodeType of the node. Do this only after adding a node.
4. CONNECT_NODES: Link nodes via their ports
   - For patch-to-patch connections: Default to port 0
   - For patch-to-layer connections: Call ADD_LAYER_INPUT first

"""

//NODE TYPE IS OVERALL PORT VALUE TYPE OF THE NODE
//SUPPOSE YOU HAVE AN ADD NODE WHOSE TYPE IS TEXT
//IN THAT CASE, THE NODE KIND IS PATCH.ADDNODE, AND THE NODE TYPE IS TEXT/STRING
//NODE KIND IS PATCH VS LAYER (and which patch / layer)

let VISUAL_PROGRAMMING_ACTIONS = """
{
  "$defs": {
    "Actions": {
      "properties": {
        "step_type": {
          "enum": [
            "add_node",
            "connect_nodes",
            "change_node_type",
            "set_input",
            "add_layer_input"
          ],
          "description": "The type of step performed"
        },
        "node_name": {
          "anyOf": [
            {
              "$ref": "#/$defs/NodeName"
            }
          ],
          "default": null,
          "description": "The name of the node to add"
        },
        "node_id": {
          "anyOf": [
            {
              "$ref": "#/$defs/NodeID"
            }
          ],
          "default": null,
          "description": "The id of the node to add"
        },
        "from_node_id": {
          "anyOf": [
            {
              "$ref": "#/$defs/NodeID"
            }
          ],
          "default": null,
          "description": "The id of the source node"
        },
        "to_node_id": {
          "anyOf": [
            {
              "$ref": "#/$defs/NodeID"
            }
          ],
          "default": null,
          "description": "The id of the target node"
        },
        "node_type": {
          "$ref": "#/$defs/NodeType",
          "default": null,
          "description": "The node type of the node"
        },
        "value": {
          "anyOf": [
            {
              "type": "number"
            },
            {
              "type": "string"
            },
            {
              "type": "boolean"
            }
          ],
          "default": null,
          "description": "The value of the node"
        },
        "port": {
          "anyOf": [
            {
              "$ref": "#/$defs/LayerPorts"
            },
            {
              "type": "integer",
              "minimum": 0
            }
          ],
          "default": null,
          "description": "The port for connections. Use integers for patch nodes, and LayerPorts for layer nodes"
        }
      },
      "required": [
        "step_type"
      ],
      "allOf": [
        {
          "if": {
            "properties": {
              "step_type": {
                "const": "add_node"
              }
            }
          },
          "then": {
            "required": ["node_name", "node_id"],
            "properties": {
              "node_name": {
                "description": "The name of the node to be added",
                "type": "string"
              },
              "node_id": {
                "description": "The ID of the node to be added",
                "type": "string"
              }
            }
          }
        },
        {
          "if": {
            "properties": {
              "step_type": {
                "const": "connect_nodes"
              }
            }
          },
          "then": {
            "required": ["from_node_id", "to_node_id", "port"],
            "properties": {
              "from_node_id": {
                "description": "ID of the node where the connection starts",
                "type": "string"
              },
              "to_node_id": {
                "description": "ID of the node where the connection ends",
                "type": "string"
              },
              "port": {
                "description": "The port to use for the connection. Patch nodes use integers; Layer nodes use a selection from #/$defs/LayerPorts.",
                "anyOf": [
                  {
                    "type": "integer"
                  },
                  {
                    "$ref": "#/$defs/LayerPorts"
                  }
                ]
              }
            }
          }
        },
        {
          "if": {
            "properties": {
              "step_type": {
                "const": "change_node_type"
              }
            }
          },
          "then": {
            "required": ["node_id", "node_type"],
            "properties": {
              "node_id": {
                "description": "ID of the node whose type is being changed",
                "type": "string"
              },
              "node_type": {
                "$ref": "#/$defs/NodeType",
                "description": "The new type of the node"
              }
            }
          }
        },
        {
          "if": {
            "properties": {
              "step_type": {
                "const": "set_input"
              }
            }
          },
          "then": {
            "required": ["node_id", "port", "value", "node_type"],
            "properties": {
              "node_id": {
                "description": "ID of the node receiving the input",
                "type": "string"
              },
              "value": {
                "description": "Value to set for the input",
                "anyOf": [
                  {
                    "type": "number"
                  },
                  {
                    "type": "string"
                  },
                  {
                    "type": "boolean"
                  }
                ]
              },
              "port": {
                "description": "The port to which the value is set. Patch nodes use integers; Layer nodes use a selection from #/$defs/LayerPorts.",
                "anyOf": [
                  {
                    "type": "integer"
                  },
                  {
                    "$ref": "#/$defs/LayerPorts"
                  }
                ]
              },
              "node_type": {
                "$ref": "#/$defs/NodeType",
                "description": "The type of node to use."
              }
            }
          }
        },
        {
          "if": {
            "properties": {
              "step_type": {
                "const": "add_layer_input"
              }
            }
          },
          "then": {
            "required": ["node_id", "layer_type", "port"],
            "properties": {
              "node_id": {
                "description": "ID of the node receiving the layer input",
                "type": "string"
              },
              "layer_type": {
                "description": "Type of layer input being added",
                "enum": [
                  "Text",
                  "Image",
                  "Shape",
                  "Color"
                ]
              },
              "port": {
                "description": "The port to which the layer input is set",
                "anyOf": [
                  {
                    "type": "integer"
                  },
                  {
                    "$ref": "#/$defs/LayerPorts"
                  }
                ]
              }
            }
          }
        }
      ]
    },
    "NodeID": {
      "type": "string",
      "format": "uuid",
      "description": "The unique identifier for the node (UUID)"
    },
    "NodeName": {
      "enum": [
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
    },
    "StepType": {
      "enum": [
        "add_node",
        "connect_nodes",
        "change_node_type",
        "set_input",
        "add_layer_input"
      ],
      "title": "StepType",
      "type": "string"
    }
  },
  "properties": {
    "steps": {
      "description": "The actions taken to create a graph",
      "items": {
        "$ref": "#/$defs/Actions"
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
