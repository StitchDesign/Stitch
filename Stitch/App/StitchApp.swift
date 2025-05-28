//
//  StitchApp.swift
//  Stitch
//
//  Created by cjc on 11/1/20.
//

import SwiftUI
import StitchSchemaKit
import Sentry
import FirebaseCore
import FirebaseAnalytics
import TipKit

@main @MainActor
struct StitchApp: App {
    @Environment(\.dismissWindow) private var dismissWindow
    
    // MARK: VERY important to pass the store StateObject into each view for perf
    @State private var store = StitchStore()
    
    private static var isFirebaseConfigValid: Bool {
        guard
            let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
            let options = FirebaseOptions(contentsOfFile: url.path)
        else { return false }

        return [
            options.apiKey?.isEmpty,
            options.googleAppID.isEmpty,
            options.projectID?.isEmpty
        ].allSatisfy { $0 == false }
    }
    
    private static func configureFirebaseIfPossible() {
        guard FirebaseApp.app() == nil else { return }
        guard isFirebaseConfigValid else {
            print("⚠️  Firebase configuration skipped – incomplete GoogleService-Info.plist")
            return
        }
        FirebaseApp.configure()
    }
//    
//    var body: some Scene {
//        WindowGroup {
//            JsonStreamTest()
//        }
//    }
    
    
    var body: some Scene {
        WindowGroup {
            ResponsesAPITestView()
        }
    }
    
    
//    var body: some Scene {
//        WindowGroup {
//            // iPad uses StitchRouter to use the project zoom in/out animation
//            StitchRootView(store: self.store)
//                .onAppear {
////                    do {
////                        // For 4o
////                        try StitchAITrainingData.validateTrainingData(from: "stitch-training")
////    
////                        // For o4-mini
////                        try StitchAIReasoningTrainingData.validateTrainingData(from: "stitch-v0.1.17-RFT-VALIDATION")
////                    } catch {
////                        print("StitchAITrainingData error: \(error)")
////                    }
//                    
//                    // Load and configure the state of all the tips of the app
//                    try? Tips.configure()
//                    
//                    // For testing
//                    #if DEV_DEBUG
//                    try? Tips.resetDatastore()
//                    #endif
//                    
//                    dispatch(DirectoryUpdatedOnAppOpen())
//                    
//                    SentrySDK.start { options in
//                        guard let secrets = try? Secrets() else {
//                            return
//                        }
//                        
//                        options.dsn = secrets.sentryDSN
//                        options.enableMetricKit = true
//                        options.enableMetricKitRawPayload = true
//                        options.debug = false
//                    }
//                    
//                    #if !DEBUG
//                    Self.configureFirebaseIfPossible()
//                    #endif
//
//                    // Close mac sharing window in case open
//                    #if targetEnvironment(macCatalyst)
//                    dismissWindow(id: RecordingView.windowId)
//                    #endif
//
//                }
//                .environment(self.store)
//                .environment(self.store.environment)
//                .environment(self.store.environment.fileManager)
//            // Inject theme as environment variable
//                .environment(\.appTheme, self.store.appTheme)
//                .environment(\.edgeStyle, self.store.edgeStyle)
//                .environment(\.isOptionRequiredForShortcut, self.store.isOptionRequiredForShortcut)
//        }
//        
//
//        // TODO: why does XCode complain about `.windowStyle not available on iOS` even when using `#if targetEnvironment(macCatalyst)`?
//        // TODO: why do `!os(iOS)` or `os(macOS)` statements not seem to run?
//        // #if targetEnvironment(macCatalyst)
//        // #if os(macOS)
//        // #if !os(iOS)
//        //        .windowStyle(HiddenTitleBarWindowStyle())
//        //        .windowStyle(.hiddenTitleBar)
//        //        #endif
//        .commands {
//            StitchCommands(store: store,
//                           activeReduxFocusedField: store.currentDocument?.reduxFocusedField)
//          
//        }
//        
//        #if targetEnvironment(macCatalyst)
//        WindowGroup("Screen Sharing", id: "mac-screen-sharing") {
//            MacScreenSharingView(store: store)
//        }
//        #endif
//    }
}



// should contain keys ike `type`, `properties`, `required`, `additionalProperties`
struct ResponseAPISchema: Encodable {
    var type: String = "object"
    var properties = StitchAIStepsSchema()
    
    // add a key for `defs`
    // needs to be encoded as "$defs" not just "defs"
    var defs = StitchAIStructuredOutputsDefinitions()
    
    var required: [String] = ["steps"]
    var additionalProperties: Bool = false
    var title: String = "VisualProgrammingActions"

    enum CodingKeys: String, CodingKey {
        case type
        case properties
        case defs = "$defs"
        case required
        case additionalProperties
        case title
    }
}

struct ResponsesAPITestView: View {
    var body: some View {
        
        Text("Will launch stream response")
            .onAppear {
                
                // what does our full schema look like, as a json string ?
//                log("ENCODED_OPEN_AI_STRUCTURED_OUTPUTS: \n \(ENCODED_OPEN_AI_STRUCTURED_OUTPUTS)")
                
                let responseSchema = try! ResponseAPISchema().encodeToPrintableString()
                
                log("ResponseAPISchema(): \n \(responseSchema)")
                
                // — Example usage —
                Task(priority: .high) {  // call from some async context
                    do {
                        try await streamResponseWithReasoning(
                            apiKey: "",
                            userPrompt: "make a green animating rect."
                        )
                    } catch {
                        print("Error while streaming:", error)
                    }
                }
            } // .onAppear
        
    }
}

import Foundation

// MARK: – Models

/// A single message in the `input` array.
struct ChatMessage: Codable {
    let role: String      // e.g. "system" or "user"
    let content: String
}

/// The POST body for the Responses “create” call.
struct ResponsesCreateRequest: Encodable {
    let model: String                  // e.g. "o4-mini-2025-04-16"
    let input: [ChatMessage]           // system+user messages
    let reasoning: ReasoningOptions    // how much effort & summary style
    let text: TextOptions              // text formatting options
    let stream: Bool                   // true for SSE

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case reasoning
        case text
        case stream
    }

    struct ReasoningOptions: Codable {
        let effort: String             // e.g. "medium"
        let summary: String            // e.g. "detailed"
    }
}
/// Configuration for text output formatting.
struct TextOptions: Encodable {
    let format: TextFormat
}

/// Specifies the format type, naming, strictness, and schema.
struct TextFormat: Encodable {
    let type: String         // e.g. "json_schema"
    let name: String         // e.g. "ui"
    let strict: Bool
    let schema: JSON
    // let schema: ResponseAPISchema // StitchAIStructuredOutputsPayload //JSONSchema
}

/// A JSON schema definition.
struct JSONSchema: Codable {
    let type: String
    let properties: [String: JSONSchemaProperty]
    let required: [String]
    let additionalProperties: Bool
}

/// A property definition within a JSON schema.
struct JSONSchemaProperty: Codable {
    let type: String?
    let enumValues: [String]?
    let items: JSONSchemaItems?
    let properties: [String: JSONSchemaProperty]?
    let required: [String]?
    let additionalProperties: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case enumValues = "enum"
        case items
        case properties
        case required
        case additionalProperties
    }
}

/// Reference to another schema definition.
struct JSONSchemaItems: Codable {
    let ref: String

    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
    }
}

/// Each streamed SSE chunk from the Responses API.
struct ResponseStreamChunk: Codable {
    let token: String
    let done: Bool
    let model: String
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case token, done, model
        case finishReason = "finish_reason"
    }
}

/// A streamed SSE chunk carrying a reasoning summary.
struct ReasoningSummaryChunk: Codable {
    let summary: String
}

// MARK: – Streaming Function

/// Streams tokens (plus reasoning) from the Responses API.

@MainActor
func streamResponseWithReasoning(
    apiKey: String,
    userPrompt: String
) async throws {
    // 1️⃣ Build the JSON payload
    let messages = [
        ChatMessage(role: "system", content: try StitchAIManager.systemPrompt(graph: .createEmpty())),
        ChatMessage(role: "user",   content: userPrompt)
    ]
    let payload = ResponsesCreateRequest(
//        model: "o4-mini-2025-04-16",
        model: "ft:o4-mini-2025-04-16:ve::BaQU8UVH",
        input: messages,
        reasoning: .init(effort: "medium", summary: "detailed"),
        text: TextOptions(
            format: TextFormat(
                type: "json_schema",
                name: "ui",
                strict: true,
//                schema: HARDCODED_SCHEMA_JSON
                schema: JSON(rawValue: try? StitchAIStructuredOutputsPayload().encodeToData()) ?? "" // StitchAIStructuredOutputsPayload()
            )
        ),
        stream: true
    )
    
    let encodedPayload: Data = try JSONEncoder().encode(payload)
    
    let jsonOfEncodedPayload = try JSON.init(data: encodedPayload)
    log("encoded payload, as json: \(try jsonOfEncodedPayload.encodeToPrintableString())")
    
    
    // 2️⃣ Configure URLRequest
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)",                forHTTPHeaderField: "Authorization")
    request.setValue("application/json",                forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream",               forHTTPHeaderField: "Accept")
    request.httpBody = encodedPayload

    // 3️⃣ Open the byte-stream
    let (stream, _) = try await URLSession.shared.bytes(for: request)

    // 4️⃣ Parse SSE “data:” lines as they arrive
    var buffer = ""
    for try await byte in stream {
//        log("had byte: \(byte)")
        buffer.append(Character(UnicodeScalar(byte)))
        if buffer.hasSuffix("\n") {
             log("had new line suffix")
            let line = buffer.trimmingCharacters(in: .newlines)
            buffer = ""

            // skip empty lines
            guard !line.isEmpty else {
                continue
            }
            
             log("had non-empty line")

            // extract JSON text: drop "data:" prefix if present, otherwise use the whole line
            let jsonText: String
            if line.hasPrefix("data:") {
                log("found data prefix")
                // remove "data:" and any following whitespace
                let startIndex = line.index(line.startIndex, offsetBy: 5)
                jsonText = line[startIndex...].trimmingCharacters(in: .whitespaces)
                log("found data prefix: jsonText is now: \(jsonText)")
            } else {
                jsonText = line
                log("did not find data prefix: jsonText is now: \(jsonText)")
            }

            // end-of-stream
            if jsonText == "[DONE]" {
                print("\n🏁 Stream complete.")
                break
            }

            let jsonData = Data(jsonText.utf8)
            // First attempt to decode a token chunk
            if let tokenChunk = try? JSONDecoder().decode(ResponseStreamChunk.self, from: jsonData) {
                log("found tokenChunk: \(tokenChunk)")
                print(tokenChunk.token, terminator: "")
            }
            // Next attempt to decode a reasoning summary chunk
            else if let summaryChunk = try? JSONDecoder().decode(ReasoningSummaryChunk.self, from: jsonData) {
                log("found summaryChunk: \(summaryChunk)")
                print("\n💡 Reasoning hint: \(summaryChunk.summary)\n")
            }
            // Otherwise ignore unknown chunks
        }
//        else {
//            log("no new line suffix")
//        }
        
        
        
    } // for try await byte in stream
    
    log("STREAM ENDED")
    
}

// MARK: – Example Invocation

//struct Demo {
//    static func main() async {
//        do {
//            try await streamResponseWithReasoning(
//                apiKey:     "<YOUR_API_KEY>",
//                userPrompt: "Create a JSON schema for a registration form."
//            )
//        } catch {
//            print("Error while streaming:", error)
//        }
//    }
//}

import SwiftyJSON

@MainActor
let HARDCODED_SCHEMA_JSON: JSON = parseJSON(HARDCODED_SCHEMA_STRING)!

@MainActor
let HARDCODED_SCHEMA_STRING = """
 {
  "$defs" : {
    "AddNodeAction" : {
      "additionalProperties" : false,
      "properties" : {
        "node_id" : {
          "type" : "string"
        },
        "node_name" : {
          "$ref" : "#/$defs/NodeName"
        },
        "step_type" : {
          "const" : "add_node",
          "type" : "string"
        }
      },
      "required" : [
        "step_type",
        "node_id",
        "node_name"
      ],
      "type" : "object"
    },
    "ChangeValueTypeAction" : {
      "additionalProperties" : false,
      "properties" : {
        "node_id" : {
          "type" : "string"
        },
        "step_type" : {
          "const" : "change_value_type",
          "type" : "string"
        },
        "value_type" : {
          "$ref" : "#/$defs/ValueType"
        }
      },
      "required" : [
        "node_id",
        "value_type",
        "step_type"
      ],
      "type" : "object"
    },
    "ConnectNodesAction" : {
      "additionalProperties" : false,
      "properties" : {
        "from_node_id" : {
          "type" : "string"
        },
        "from_port" : {
          "type" : "integer"
        },
        "port" : {
          "anyOf" : [
            {
              "type" : "integer"
            },
            {
              "$ref" : "#/$defs/LayerPorts"
            }
          ]
        },
        "step_type" : {
          "const" : "connect_nodes",
          "type" : "string"
        },
        "to_node_id" : {
          "type" : "string"
        }
      },
      "required" : [
        "from_port",
        "from_node_id",
        "to_node_id",
        "step_type",
        "port"
      ],
      "type" : "object"
    },
    "LayerPorts" : {
      "enum" : [
        "Position",
        "Size",
        "Scale",
        "Anchoring",
        "Opacity",
        "Z Index",
        "Masks",
        "Color",
        "Rotation X",
        "Rotation Y",
        "Rotation Z",
        "Line Color",
        "Line Width",
        "Blur",
        "Blend Mode",
        "Brightness",
        "Color Invert",
        "Contrast",
        "Hue Rotation",
        "Saturation",
        "Pivot",
        "Enable",
        "Blur Radius",
        "Background Color",
        "Clipped",
        "Layout",
        "Padding",
        "Setup Mode",
        "Animating",
        "Camera Direction",
        "Camera Enabled",
        "Shadows Enabled",
        "3D Transform",
        "Anchor Entity",
        "Animating",
        "Translation",
        "Rotation",
        "Scale",
        "Size 3D",
        "Radius",
        "Height",
        "Shape",
        "Position",
        "Width",
        "Color",
        "Start",
        "End",
        "Line Cap",
        "Line Join",
        "Coordinate System",
        "Corner Radius",
        "Metallic",
        "Line Color",
        "Line Width",
        "Text",
        "Placeholder",
        "Font Size",
        "Alignment",
        "Vertical Align.",
        "Decoration",
        "Font",
        "Image",
        "Video",
        "3D Model",
        "Fit Style",
        "Clipped",
        "Style",
        "Progress",
        "Map Style",
        "Lat/Long",
        "Span",
        "Toggle",
        "Start Color",
        "End Color",
        "Start Anchor",
        "End Anchor",
        "Center Anchor",
        "Start Angle",
        "End Angle",
        "Start Radius",
        "End Radius",
        "Color",
        "Opacity",
        "Radius",
        "Offset",
        "SF Symbol",
        "Video URL",
        "Volume",
        "Column Spacing",
        "Row Spacing",
        "Cell Anchoring",
        "Sizing",
        "Width Axis",
        "Height Axis",
        "Content Mode",
        "Min Size",
        "Max Size",
        "Spacing",
        "Pinned",
        "Pin To",
        "Anchor",
        "Offset",
        "Padding",
        "Margin",
        "Offset",
        "Alignment",
        "Material",
        "Appearance",
        "Content",
        "Auto Scroll",
        "Scroll X Enabled",
        "Jump Style X",
        "Jump to X",
        "Jump Position X",
        "Scroll Y Enabled",
        "Jump Style Y",
        "Jump to Y",
        "Jump Position Y"
      ],
      "type" : "string"
    },
    "NodeID" : {
      "description" : "The unique identifier for the node (UUID)",
      "type" : "string"
    },
    "NodeIdSet" : {
      "description" : "Array of node UUIDs",
      "items" : {
        "anyOf" : [
          {
            "type" : "string"
          }
        ]
      },
      "type" : "array"
    },
    "NodeName" : {
      "enum" : [
        "value || Patch",
        "add || Patch",
        "convertPosition || Patch",
        "dragInteraction || Patch",
        "pressInteraction || Patch",
        "legacyScrollInteraction || Patch",
        "repeatingPulse || Patch",
        "delay || Patch",
        "pack || Patch",
        "unpack || Patch",
        "counter || Patch",
        "switch || Patch",
        "multiply || Patch",
        "optionPicker || Patch",
        "loop || Patch",
        "time || Patch",
        "deviceTime || Patch",
        "location || Patch",
        "random || Patch",
        "greaterOrEqual || Patch",
        "lessThanOrEqual || Patch",
        "equals || Patch",
        "restartPrototype || Patch",
        "divide || Patch",
        "hslColor || Patch",
        "or || Patch",
        "and || Patch",
        "not || Patch",
        "springAnimation || Patch",
        "popAnimation || Patch",
        "bouncyConverter || Patch",
        "optionSwitch || Patch",
        "pulseOnChange || Patch",
        "pulse || Patch",
        "classicAnimation || Patch",
        "cubicBezierAnimation || Patch",
        "curve || Patch",
        "cubicBezierCurve || Patch",
        "repeatingAnimation || Patch",
        "loopBuilder || Patch",
        "loopInsert || Patch",
        "imageClassification || Patch",
        "objectDetection || Patch",
        "transition || Patch",
        "imageImport || Patch",
        "cameraFeed || Patch",
        "raycasting || Patch",
        "arAnchor || Patch",
        "sampleAndHold || Patch",
        "grayscale || Patch",
        "loopSelect || Patch",
        "videoImport || Patch",
        "sampleRange || Patch",
        "soundImport || Patch",
        "speaker || Patch",
        "microphone || Patch",
        "networkRequest || Patch",
        "valueForKey || Patch",
        "valueAtIndex || Patch",
        "loopOverArray || Patch",
        "setValueForKey || Patch",
        "jsonObject || Patch",
        "jsonArray || Patch",
        "arrayAppend || Patch",
        "arrayCount || Patch",
        "arrayJoin || Patch",
        "arrayReverse || Patch",
        "arraySort || Patch",
        "getKeys || Patch",
        "indexOf || Patch",
        "subArray || Patch",
        "valueAtPath || Patch",
        "deviceMotion || Patch",
        "deviceInfo || Patch",
        "smoothValue || Patch",
        "velocity || Patch",
        "clip || Patch",
        "max || Patch",
        "mod || Patch",
        "absoluteValue || Patch",
        "round || Patch",
        "progress || Patch",
        "reverseProgress || Patch",
        "wirelessBroadcaster || Patch",
        "wirelessReceiver || Patch",
        "rgbColor || Patch",
        "arcTan2 || Patch",
        "sine || Patch",
        "cosine || Patch",
        "hapticFeedback || Patch",
        "imageToBase64 || Patch",
        "base64ToImage || Patch",
        "onPrototypeStart || Patch",
        "soulver || Patch",
        "optionEquals || Patch",
        "subtract || Patch",
        "squareRoot || Patch",
        "length || Patch",
        "min || Patch",
        "power || Patch",
        "equalsExactly || Patch",
        "greaterThan || Patch",
        "lessThan || Patch",
        "colorToHsl || Patch",
        "colorToHex || Patch",
        "colorToRgb || Patch",
        "hexColor || Patch",
        "splitText || Patch",
        "textEndsWith || Patch",
        "textLength || Patch",
        "textReplace || Patch",
        "textStartsWith || Patch",
        "textTransform || Patch",
        "trimText || Patch",
        "dateAndTimeFormatter || Patch",
        "stopwatch || Patch",
        "optionSender || Patch",
        "any || Patch",
        "loopCount || Patch",
        "loopDedupe || Patch",
        "loopFilter || Patch",
        "loopOptionSwitch || Patch",
        "loopRemove || Patch",
        "loopReverse || Patch",
        "loopShuffle || Patch",
        "loopSum || Patch",
        "loopToArray || Patch",
        "runningTotal || Patch",
        "layerInfo || Patch",
        "triangleShape || Patch",
        "circleShape || Patch",
        "ovalShape || Patch",
        "roundedRectangleShape || Patch",
        "union || Patch",
        "keyboard || Patch",
        "jsonToShape || Patch",
        "shapeToCommands || Patch",
        "commandsToShape || Patch",
        "mouse || Patch",
        "sizePack || Patch",
        "sizeUnpack || Patch",
        "positionPack || Patch",
        "positionUnpack || Patch",
        "point3DPack || Patch",
        "point3DUnpack || Patch",
        "point4DPack || Patch",
        "point4DUnpack || Patch",
        "transformPack || Patch",
        "transformUnpack || Patch",
        "closePath || Patch",
        "moveToPack || Patch",
        "lineToPack || Patch",
        "curveToPack || Patch",
        "curveToUnpack || Patch",
        "mathExpression || Patch",
        "qrCodeDetection || Patch",
        "delay1 || Patch",
        "durationAndBounceConverter || Patch",
        "responseAndDampingRatioConverter || Patch",
        "settlingDurationAndDampingRatioConverter || Patch",
        "text || Layer",
        "oval || Layer",
        "rectangle || Layer",
        "image || Layer",
        "group || Layer",
        "video || Layer",
        "3dModel || Layer",
        "realityView || Layer",
        "shape || Layer",
        "colorFill || Layer",
        "hitArea || Layer",
        "canvasSketch || Layer",
        "textField || Layer",
        "map || Layer",
        "progressIndicator || Layer",
        "toggleSwitch || Layer",
        "linearGradient || Layer",
        "radialGradient || Layer",
        "angularGradient || Layer",
        "sfSymbol || Layer",
        "videoStreaming || Layer",
        "material || Layer",
        "box || Layer",
        "sphere || Layer",
        "cylinder || Layer",
        "cone || Layer"
      ],
      "type" : "string"
    },
    "SetInputAction" : {
      "additionalProperties" : false,
      "properties" : {
        "node_id" : {
          "type" : "string"
        },
        "port" : {
          "anyOf" : [
            {
              "type" : "integer"
            },
            {
              "$ref" : "#/$defs/LayerPorts"
            }
          ]
        },
        "step_type" : {
          "const" : "set_input",
          "type" : "string"
        },
        "value" : {
          "anyOf" : [
            {
              "type" : "number"
            },
            {
              "type" : "string"
            },
            {
              "type" : "boolean"
            },
            {
              "type" : "object",
              "additionalProperties": false,
              "properties": {}
            }
          ]
        },
        "value_type" : {
          "$ref" : "#/$defs/ValueType"
        }
      },
      "required" : [
        "port",
        "value",
        "value_type",
        "step_type",
        "node_id"
      ],
      "type" : "object"
    },
    "SidebarGroupCreatedAction" : {
      "additionalProperties" : false,
      "properties" : {
        "children" : {
          "$ref" : "#/$defs/NodeIdSet"
        },
        "node_id" : {
          "type" : "string"
        },
        "step_type" : {
          "const" : "sidebar_group_created",
          "type" : "string"
        }
      },
      "required" : [
        "step_type",
        "node_id",
        "children"
      ],
      "type" : "object"
    },
    "ValueType" : {
      "enum" : [
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
        "anchor",
        "cameraDirection",
        "layer",
        "scrollMode",
        "textHorizontalAlignment",
        "textVerticalAlignment",
        "fit",
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
        "imageCrop&Scale",
        "textDecoration",
        "textFont",
        "blendMode",
        "mapType",
        "progressStyle",
        "hapticStyle",
        "contentMode",
        "spacing",
        "padding",
        "sizingScenario",
        "pinToId",
        "deviceAppearance",
        "materializeThickness",
        "anchorEntity"
      ],
      "type" : "string"
    }
  },
  "additionalProperties" : false,
  "properties" : {
    "steps" : {
      "description" : "The actions taken to create a graph",
      "items" : {
        "anyOf" : [
          {
            "$ref" : "#/$defs/AddNodeAction"
          },
          {
            "$ref" : "#/$defs/ConnectNodesAction"
          },
          {
            "$ref" : "#/$defs/ChangeValueTypeAction"
          },
          {
            "$ref" : "#/$defs/SetInputAction"
          },
          {
            "$ref" : "#/$defs/SidebarGroupCreatedAction"
          }
        ]
      },
      "type" : "array"
    }
  },
  "required" : [
    "steps"
  ],
  "title" : "VisualProgrammingActions",
  "type" : "object"
}

"""
