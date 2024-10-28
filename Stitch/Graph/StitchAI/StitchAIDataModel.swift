//
//  StitchAIDataModel.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation

struct OpenAIResponse: Codable {
    var choices: [Choice]
}

struct Choice: Codable {
    var message: MessageStruct
}

struct MessageStruct: Codable {
    var content: String
    
    func parseContent() throws -> ContentJSON {
        guard let contentData = content.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Invalid content data"))
        }
        return try JSONDecoder().decode(ContentJSON.self, from: contentData)
    }
}

struct ContentJSON: Codable {
    var steps: [Step]
}

struct Step: Codable {
    var stepType: String
    var nodeId: String?
    var nodeName: String?
    var port: StringOrNumber?  // Updated to handle String or Int
    var fromNodeId: String?
    var toNodeId: String?
    var value: StringOrNumber?  // Updated to handle String or Int
    var nodeType: String?
    
    enum CodingKeys: String, CodingKey {
        case stepType = "step_type"
        case nodeId = "node_id"
        case nodeName = "node_name"
        case port
        case fromNodeId = "from_node_id"
        case toNodeId = "to_node_id"
        case value
        case nodeType = "node_type"
    }
}

struct StringOrNumber: Codable {
    let value: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self.value = String(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = String(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self.value = stringValue
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String, Int, or Double"))
        }
    }
}


struct LLMActionData: Codable {
    let action: String
    let node: String?
    let nodeType: String?
    let port: String?
    let from: EdgePoint?
    let to: EdgePoint?
    let field: EdgePoint?
    let value: String?

    enum CodingKeys: String, CodingKey {
        case action, node, nodeType, port, from, to, field, value
    }
}

struct EdgePoint: Codable {
    let node: String
    let port: String
}

struct NodeInfoData {
    var type: String
    var inputPortCount: Int = 0
    var nodeType: String?
}

enum ActionType: String {
    case addNode = "Add Node"
    case addLayerInput = "Add Layer Input"
    case addEdge = "Add Edge"
    case changeNodeType = "Change Node Type"
    case setInput = "Set Input"
}

enum StepType: String, Codable {
    case addNode = "add_node"
    case addLayerInput = "add_layer_input"
    case connectNodes = "connect_nodes"
    case changeNodeType = "change_node_type"
    case setInput = "set_input"
}


// Node Types
enum StitchAINodeKinds: String, CaseIterable {
    // Mathematical Operations
    case add = "Add"
    case subtract = "Subtract"
    case multiply = "Multiply"
    case divide = "Divide"
    case mod = "Mod"
    case power = "Power"
    case squareRoot = "SquareRoot"
    case absoluteValue = "AbsoluteValue"
    case round = "Round"
    case max = "Max"
    case min = "Min"
    case length = "Length"
    case arcTan2 = "ArcTan2"
    case sine = "Sine"
    case cosine = "Cosine"
    case mathExpression = "MathExpression"
    case clip = "Clip"

    // Logical Operations
    case or = "Or"
    case and = "And"
    case not = "Not"
    case equals = "Equals"
    case equalsExactly = "EqualsExactly"
    case greaterThan = "GreaterThan"
    case greaterOrEqual = "GreaterOrEqual"
    case lessThan = "LessThan"
    case lessThanOrEqual = "LessThanOrEqual"

    // Text Operations
    case splitText = "SplitText"
    case textLength = "TextLength"
    case textReplace = "TextReplace"
    case textStartsWith = "TextStartsWith"
    case textEndsWith = "TextEndsWith"
    case textTransform = "TextTransform"
    case trimText = "TrimText"

    // Time and Date
    case time = "Time"
    case deviceTime = "DeviceTime"
    case dateAndTimeFormatter = "DateAndTimeFormatter"
    case stopwatch = "Stopwatch"
    case delay = "Delay"
    case delayOne = "DelayOne"

    // Media
    case imageImport = "ImageImport"
    case videoImport = "VideoImport"
    case soundImport = "SoundImport"
    case model3DImport = "Model3DImport"
    case qrCodeDetection = "QRCodeDetection"
    case arAnchor = "ARAnchor"
    case arRaycasting = "ARRaycasting"
    case imageClassification = "ImageClassification"
    case objectDetection = "ObjectDetection"

    // Device and Interaction
    case cameraFeed = "CameraFeed"
    case deviceInfo = "DeviceInfo"
    case deviceMotion = "DeviceMotion"
    case hapticFeedback = "HapticFeedback"
    case keyboard = "Keyboard"
    case mouse = "Mouse"
    case microphone = "Microphone"
    case speaker = "Speaker"
    case dragInteraction = "DragInteraction"
    case pressInteraction = "PressInteraction"
    case scrollInteraction = "ScrollInteraction"
    case location = "Location"

    // Graphics and Shapes
    case circleShape = "CircleShape"
    case ovalShape = "OvalShape"
    case roundedRectangleShape = "RoundedRectangleShape"
    case triangleShape = "TriangleShape"
    case shapeToCommands = "ShapeToCommands"
    case commandsToShape = "CommandsToShape"
    case transformPack = "TransformPack"
    case transformUnpack = "TransformUnpack"
    case moveToPack = "MoveToPack"
    case lineToPack = "LineToPack"
    case closePath = "ClosePath"

    // Color and Image
    case base64StringToImage = "Base64StringToImage"
    case imageToBase64String = "ImageToBase64String"
    case colorToHSL = "ColorToHSL"
    case colorToRGB = "ColorToRGB"
    case colorToHex = "ColorToHex"
    case hslColor = "HSLColor"
    case hexColor = "HexColor"
    case grayscale = "Grayscale"

    // Utility Functions
    case value = "Value"
    case random = "Random"
    case progress = "Progress"
    case reverseProgress = "ReverseProgress"
    case convertPosition = "ConvertPosition"
    case velocity = "Velocity"
    case soulver = "Soulver"
    case whenPrototypeStarts = "WhenPrototypeStarts"

    // Data Processing
    case valueForKey = "ValueForKey"
    case valueAtIndex = "ValueAtIndex"
    case valueAtPath = "ValueAtPath"
    case splitter = "Splitter"
    case pack = "Pack"
    case unpack = "Unpack"
    case sampleAndHold = "SampleAndHold"
    case sampleRange = "SampleRange"
    case smoothValue = "SmoothValue"
    case runningTotal = "RunningTotal"
    case jsonToShape = "JsonToShape"
    case jsonArray = "JsonArray"
    case jsonObject = "JsonObject"

    // Layer Nodes
    case text = "Text"
    case oval = "Oval"
    case rectangle = "Rectangle"
    case shape = "Shape"
    case colorFill = "ColorFill"
    case image = "Image"
    case video = "Video"
    case videoStreaming = "VideoStreaming"
    case realityView = "RealityView"
    case canvasSketch = "CanvasSketch"

    var stringValue: String {
        return rawValue.lowercased()
    }
}

// Layer Ports
enum LayerPort: String, CaseIterable {
    case text = "Text"
    case scale = "Scale"
    case size = "Size"
    case position = "Position"
    case opacity = "Opacity"
}

// Value Types
enum StitchAINodeType: String, CaseIterable {
    case number = "Number"
    case text = "Text"
    case boolean = "Boolean"
}

// Helper struct to manage all types
struct VisualProgrammingTypes {
    static let validNodeKinds: [String: StitchAINodeKinds] = Dictionary(uniqueKeysWithValues: StitchAINodeKinds.allCases.map { ($0.stringValue, $0) })
    static let validLayerPorts: [String: LayerPort] = Dictionary(uniqueKeysWithValues: LayerPort.allCases.map { ($0.rawValue.lowercased(), $0) })
    static let validStitchAINodeTypes: [String: StitchAINodeType] = Dictionary(uniqueKeysWithValues: StitchAINodeType.allCases.map { ($0.rawValue, $0) })
}
