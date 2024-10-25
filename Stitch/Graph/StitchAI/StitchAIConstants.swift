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
You are a helpful assistant. Using a visual programming language, specify the nodes to use for the graph and how to connect them to solve the problem. 
Ensure that all nodes are connected appropriately to form a coherent and functional graph. Specify the nodes to use and how to connect them to solve the given problem. Refer to the descriptions of the nodes for reference on what they are useful for.
When adding nodes or setting values, you should also specify the ValueType for the node or value. The available ValueTypes are NUMBER: for numeric values (integers or floats),
STRING: for text values, BOOLEAN: for true/false values. To set the ValueType for a node, use the CHANGE_NODE_TYPE action. This should be done immediately after adding a node or when changing a node's value type. Remember to use the appropriate ValueType for each node based on its intended use in the graph.
When generating the solution, follow these steps:
1) Add a node using the ADD_NODE action. 
2) If needed, set its ValueType using the CHANGE_NODE_TYPE action. 
3) Set the value in the node's port by using SET_INPUT as needed. 
4) Connect nodes using the CONNECT_NODES action as needed. An output from a node can connect to multiple input nodes, so you are free to connect one output to several inputs if required by the task. 
5) Repeat steps 1-4 for each node in the graph. Don't use value nodes unless you have to — if you can just set the input ports of a node directly, do that. 
Use as few nodes as possible to accomplish the user's task. DON'T ADD EXTRANEOUS NODES TO THE GRAPH.
Patch nodes have inputs and outputs and can be connected to each other. Most layer nodes only have inputs. You can connect patch nodes to layer nodes, but you cannot connect layer nodes to each other.
For setting the value of a patch node input use SET_INPUT action. Whenever we set the value of a layer node input port, you MUST call the ADD_LAYER_INPUT action BEFORE connecting the nodes.
Nodes can have multiple connections.
Patch nodes use numbers for their port names. Layer nodes use one of the items in LayerPorts. Do not ever use a node name for a port name.
Connect nodes from port to port with CONNECT_NODES.

Additionally, each node is identified by a unique NodeID, which must be a valid UUID (Universally Unique Identifier) string. You should generate a new UUID for each node when it is created and assign it to the node's "node_id". Ensure that the same UUID is used consistently when referring to the same node throughout the process. For connecting nodes, the "from_node_id" and "to_node_id" fields should also reference the correct UUID string values of the nodes being connected.
"""

let VISUAL_PROGRAMMING_ACTIONS = """
{
    "$defs": {
        "Actions": {
            "properties": {
                "step_type": {
                    "allOf": [
                        {
                            "$ref": "#/$defs/StepType"
                        }
                    ],
                    "description": "The type of step performed"
                },
                "node_name": {
                    "anyOf": [
                        {
                            "$ref": "#/$defs/NodeName"
                        },
                        {
                            "type": "null"
                        }
                    ],
                    "default": null,
                    "description": "The name of the node to add"
                },
                "node_id": {
                    "anyOf": [
                        {
                            "$ref": "#/$defs/NodeID"
                        },
                        {
                            "type": "null"
                        }
                    ],
                    "default": null,
                    "description": "The id of the node to add"
                },
                "from_node_id": {
                    "anyOf": [
                        {
                            "$ref": "#/$defs/NodeID"
                        },
                        {
                            "type": "null"
                        }
                    ],
                    "default": null,
                    "description": "The id of the source node"
                },
                "to_node_id": {
                    "anyOf": [
                        {
                            "$ref": "#/$defs/NodeID"
                        },
                        {
                            "type": "null"
                        }
                    ],
                    "default": null,
                    "description": "The id of the target node"
                },
                "value_type": {
                    "anyOf": [
                        {
                            "$ref": "#/$defs/ValueType"
                        },
                        {
                            "type": "null"
                        }
                    ],
                    "default": null,
                    "description": "The value type of the node"
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
                    "description": "The value of the node",
                    "title": "Value"
                },
                "port": {
                    "anyOf": [
                        {
                            "$ref": "#/$defs/LayerPorts"
                        },
                        {
                            "type": "null"
                        }
                    ],
                    "default": null,
                    "description": "The port for addLayerInput action"
                }
            },
            "required": [
                "step_type"
            ],
            "title": "Actions",
            "type": "object"
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
                "pressInteraction || Patch -  detects when a press interaction occurs.",
                "scrollInteraction || Patch -  detects when a scroll interaction occurs.",
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
                "imageToBase64String || Patch - converts an image to a bsase64 string.",
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
        },
        "ValueType": {
            "enum": [
                "number",
                "text",
                "boolean"
            ],
            "title": "ValueType",
            "type": "string"
        }
    },
    "properties": {
        "steps": {
            "description": "The actions taken to solve the problem",
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
