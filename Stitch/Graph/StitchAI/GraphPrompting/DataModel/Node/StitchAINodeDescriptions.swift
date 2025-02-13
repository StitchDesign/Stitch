//
//  StitchAINodeDescriptions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/13/25.
//

import SwiftUI
import StitchSchemaKit

extension Patch: NodeKindDescribable {
    static let titleDisplay = "Patch"
    
    var aiNodeDescription: String {
        switch self {
        case .add:
            return "Adds two numbers together."
        case .subtract:
            return "Subtracts one number from another."
        case .multiply:
            return "Multiplies two numbers together."
        case .divide:
            return "Divides one number by another."
        case .mod:
            return "Calculates the remainder of a division."
        case .power:
            return "Raises a number to the power of another."
        case .squareRoot:
            return "Calculates the square root of a number."
        case .absoluteValue:
            return "Finds the absolute value of a number."
        case .round:
            return "Rounds a number to the nearest integer."
        case .max:
            return "Finds the maximum of two numbers."
        case .min:
            return "Finds the minimum of two numbers."
        case .length:
            return "Calculates the length of a collection."
        case .arcTan2:
            return "Calculates the arctangent of a quotient."
        case .sine:
            return "Calculates the sine of an angle."
        case .cosine:
            return "Calculates the cosine of an angle."
        case .clip:
            return "Clips a value to a specified range."
        case .or:
            return "Logical OR operation."
        case .and:
            return "Logical AND operation."
        case .not:
            return "Logical NOT operation."
        case .equals:
            return "Checks if two values are equal."
        case .equalsExactly:
            return "Checks if two values are exactly equal."
        case .greaterThan:
            return "Checks if one value is greater than another."
        case .greaterOrEqual:
            return "Checks if one value is greater or equal to another."
        case .lessThan:
            return "Checks if one value is less than another."
        case .lessThanOrEqual:
            return "Checks if one value is less than or equal to another."
        case .splitText:
            return "Splits text into parts."
        case .textLength:
            return "Calculates the length of a text string."
        case .textReplace:
            return "Replaces text within a string."
        case .textStartsWith:
            return "Checks if text starts with a specific substring."
        case .textEndsWith:
            return "Checks if text ends with a specific substring."
        case .textTransform:
            return "Transforms text into a different format."
        case .trimText:
            return "Removes whitespace from the beginning and end of a text string."
        case .time:
            return "Returns number of seconds and frames since a prototype started."
        case .dateAndTimeFormatter:
            return "creates a human-readable date/time value from a time in seconds."
        case .stopwatch:
            return "measures elapsed time in seconds."
        case .delay:
            return "delays a value by a specified number of seconds."
        case .delayOne:
            return "delays incoming value by 1 frame."
        case .imageImport:
            return "imports an image asset."
        case .videoImport:
            return "imports a video asset."
        case .soundImport:
            return "imports an audio asset."
        case .qrCodeDetection:
            return "detects the value of a QR code from an image or video."
        case .coreMLClassify:
            return "performs image classification on an image or video."
        case .coreMLDetection:
            return "detects objects in an image or video."
        case .cameraFeed:
            return "creates a live camera feed."
        case .deviceInfo:
            return "gets info of the running device."
        case .hapticFeedback:
            return "generates haptic feedback."
        case .keyboard:
            return "handles keyboard input."
        case .mouse:
            return "handles mouse input."
        case .microphone:
            return "handles microphone input."
        case .speaker:
            return "handles audio speaker output."
        case .dragInteraction:
            return "detects a drag interaction."
        case .pressInteraction:
            return "detects a press interaction."
        case .location:
            return "gets the current location."
        case .circleShape:
            return "generates a circle shape."
        case .ovalShape:
            return "generates an oval shape."
        case .roundedRectangleShape:
            return "generates a rounded rectangle shape."
        case .triangleShape:
            return "generates a triangle shape."
        case .shapeToCommands:
            return "takes a shape as input, outputs the commands to generate the shape."
        case .commandsToShape:
            return "generates a shape from a given loop of shape commands."
        case .transformPack:
            return "packs inputs into a transform."
        case .transformUnpack:
            return "unpacks a transform."
        case .moveToPack:
            return "packs a position into a MoveTo shape command."
        case .lineToPack:
            return "packs a position into a LineTo shape command."
        case .closePath:
            return "ClosePath shape command."
        case .base64StringToImage:
            return "converts a base64 string to an image."
        case .imageToBase64String:
            return "converts an image to a base64 string."
        case .colorToHSL:
            return "converts a color to HSL components."
        case .colorToRGB:
            return "converts a color to RGB components."
        case .colorToHex:
            return "converts a color to a hex string."
        case .hslColor:
            return "generates a color from HSL components."
        case .hexColor:
            return "converts a hex string to a color."
        case .grayscale:
            return "applies grayscale effect to image/video."
        case .splitter:
            return "stores a value."
        case .random:
            return "generates a random value."
        case .progress:
            return "calculates progress value."
        case .reverseProgress:
            return "calculates inverse progress."
        case .convertPosition:
            return "converts position values between layers."
        case .velocity:
            return "measures velocity over time."
        case .soulver:
            return "evaluates plain-text math expressions."
        case .whenPrototypeStarts:
            return "fires pulse when prototype starts."
        case .valueForKey:
            return "extracts a value from JSON by key."
        case .valueAtIndex:
            return "extracts a value from JSON by index."
        case .valueAtPath:
            return "extracts a value from JSON by path."
        case .pack:
            return "creates a new value from inputs."
        case .unpack:
            return "splits a value into components."
        case .sampleAndHold:
            return "stores a value until new one is received."
        case .sampleRange:
            return "samples a range of values."
        case .smoothValue:
            return "smoothes input value."
        case .runningTotal:
            return "continuously sums values."
        case .jsonToShape:
            return "creates a Shape from JSON."
        case .jsonArray:
            return "creates a JSON array from inputs."
        case .jsonObject:
            return "creates a JSON object from key-value pairs."
        case .bouncyConverter:
            return "Converts bounce and duration values to spring animation parameters."
        case .loopBuilder:
            return "Creates a new loop with specified values."
        case .loopFilter:
            return "Filters elements in a loop based on a condition."
        case .loopSelect:
            return "Selects specific elements from a loop."
        case .loopCount:
            return "Counts the number of elements in a loop."
        case .loopDedupe:
            return "Removes duplicate elements from a loop."
        case .loopOptionSwitch:
            return "Switches between different loop options."
        case .loopOverArray:
            return "Iterates over elements in an array."
        case .loopToArray:
            return "Converts a loop into an array."
        case .transition:
            return "Controls transitions between states."
        case .optionEquals:
            return "Checks if an option equals a specific value."
        case .curve:
            return "Defines an animation curve."
        case .cubicBezierCurve:
            return "Creates a cubic bezier curve for animations."
        case .any:
            return "Returns true if any input is true."
        case .rgba:
            return "Creates a color from RGBA components."
        case .arrayJoin:
            return "Joins array elements into a string."
        case .getKeys:
            return "Gets all keys from an object."
        case .indexOf:
            return "Gets the index of an element in an array."
        case .positionUnpack:
            return "Unpacks a position into X and Y components."
        case .point3DUnpack:
            return "Unpacks a 3D point into X, Y, and Z components."
        case .point4DUnpack:
            return "Unpacks a 4D point into X, Y, Z, and W components."
        case .mathExpression:
            return "Evaluates a mathematical expression."
        case .setValueForKey:
            return "Sets a value for a specified key in an object."
        case .springAnimation:
            return "Creates an animation based off of the physical model of a spring"
        case .popAnimation:
            return " Animates a value using a spring effect."
        case .classicAnimation:
            return "Animates a number using a standard animation curve."
        case .cubicBezierAnimation:
            return "Creates custom animation curves by defining two control points"
        case .repeatingAnimation:
            return "Repeatedly animates a number."
        case .pulse:
            return "Outputs a pulse event when it's toggled on or off."
        case .pulseOnChange:
            return "The Pulse On Change node outputs a pulse if an input value comes in that i different from the specified value."
        case .repeatingPulse:
            return "A node that will fire a pulse at a defined interval."
        case .union:
            return "Combines two or more shapes to generate a new shape."
        case .arrayAppend:
            return " This node appends to the end of the provided array."
        case .arrayCount:
            return "This node returns the number of items in an array."
        case .subarray:
            return "Returns a subarray from a given array."
        case .arraySort:
            return "This node sorts the array in ascending order."
        case .arrayReverse:
            return "This node reverses the order of the items in the array."
        case .scrollInteraction:
            return "Adds scroll interaction to a specified layer."
        case .arAnchor:
            return "Creates an AR anchor from a 3D model and an ARTransform. Represents the positio and orientation of a 3D item in the physical environment."
        case .arRaycasting:
            return "Returns a 3D location in physical space that corresponds to a given 2D location o the screen."
        case .deviceTime:
            return "Returns the current time of the device your prototype is running on."
        case .deviceMotion:
            return "Returns the acceleration and rotation values of the device the patch is running on."
        case .wirelessBroadcaster:
            return "Sends a value to a selected Wireless Receiver node. Useful for organizing large complicated projects by replacing cables between patches."
        case .wirelessReceiver:
            return "-Used with the Wireless Broadcaster node to route values across the graph. Useful fo organizing large, complicated projects."
        case .restartPrototype:
            return "A node that will restart the state of your prototype. All inputs and outputs of th nodes on your graph will be reset."
        case .optionPicker:
            return "The Option Picker node lets you cycle through and select one of N inputs to use a the output. Multiple inputs can be added and removed from the node, and it can be configured to work with a variety of node types."
        case .optionSender:
            return "Used to pick an output to send a value to. Multiple value types can be used wit this node."
        case .optionSwitch:
            return "Used to control two or more states with an index value. N number of inputs can b added to the node."
        case .counter:
            return "Counter that can be incremented, decremented, or set to a specified value. Starts at 0."
        case .flipSwitch:
            return "A node that will flip between an On and Off state whenever a pulse is received."
        case .loop:
            return "Generate a loop of indices. For example, an input of 3 outputs a loop of [0, 1, 2]."
        case .loopInsert:
            return "Insert a new value at a particular index in a loop."
        case .networkRequest:
            return "The Network Request node allows you to make HTTP GET and POST requests to an endpoint. Results are returned as JSON."
        case .loopRemove:
            return "Removes a value from a specified index in a loop."
        case .loopReverse:
            return "Reverse the order of the values in a loop"
        case .loopShuffle:
            return "Randomly reorders the values in a loop."
        case .loopSum:
            return "Calculates the sum of every value in a loop."
        case .layerInfo:
            return "Returns information about a specified layer."
        case .sizePack:
            return "Packs two Layer Dimension inputs to a single Layer Size output."
        case .sizeUnpack:
            return "Unpacks a single Layer Size input to two Layer Size outputs."
        case .positionPack:
            return "Packs two Number inputs to a single Position output."
        case .point3DPack:
            return "Packs three Number inputs to a single Point3D output."
        case .point4DPack:
            return "Packs four Number inputs to a single Point4D output."
        case .curveToPack:
            return "Packs Point, CurveTo and CurveFrom position inputs into a CurveTo ShapeCommand."
        case .curveToUnpack:
            return "Unpack packs CurveTo ShapeCommand into a Point, CurveTo and CurveFrom position outputs."
        case .springFromDurationAndBounce:
            return "Convert duration and bounce values to mass, stiffness and damping for a Spring Animation node."
        case .springFromResponseAndDampingRatio:
            return "Convert response and damping ratio to mass, stiffness and damping for a Spring Animation node."
        case .springFromSettlingDurationAndDampingRatio:
            return "Convert settling duration and damping ratio to mass, stiffness and damping for a Spring Animation node."
        }
    }
}

extension Layer: NodeKindDescribable {
    static let titleDisplay = "Layer"
    
    var aiNodeDescription: String {
        switch self {
        case .text:
            return "displays a text string."
        case .oval:
            return "displays an oval."
        case .rectangle:
            return "displays a rectangle."
        case .shape:
            return "takes a Shape and displays it."
        case .colorFill:
            return "displays a color fill."
        case .image:
            return "displays an image."
        case .video:
            return "displays a video."
        case .videoStreaming:
            return "displays a streaming video."
        case .realityView:
            return "displays AR scene output."
        case .canvasSketch:
            return "draw custom shapes interactively."
        case .model3D:
            return "Layer - display a 3D model asset (of a USDZ file type) in the preview window."
        case .box:
            return "A box 3D shape, which can be used inside a Reality View."
        case .sphere:
            return "A sphere 3D shape, which can be used inside a Reality View."
        case .cylinder:
            return "A cylinder 3D shape, which can be used inside a Reality View."
        case .cone:
            return "A cylinder 3D shape, which can be used inside a Reality View."
        case .group:
            return "A container layer that can hold multiple child layers."
        case .hitArea:
            return "A layer that defines an interactive area for touch input."
        case .textField:
            return "An editable text input field."
        case .progressIndicator:
            return "Displays a progress indicator or loading state."
        case .switchLayer:
            return "A toggle switch control layer."
        case .linearGradient:
            return "Creates a linear gradient."
        case .radialGradient:
            return "-Creates a radial gradient."
        case .angularGradient:
            return "Creates an angular gradient."
        case .material:
            return "A Material Effect layer."
        case .map:
            return "The Map node will display an Apple Maps UI in the preview window."
        case .sfSymbol:
            return "Creates an SF Symbol."
        }
    }
}
