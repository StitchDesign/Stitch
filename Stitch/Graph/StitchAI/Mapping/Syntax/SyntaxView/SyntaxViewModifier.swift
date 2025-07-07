//
//  Modifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftSyntax
import SwiftParser


struct SyntaxViewModifier: Equatable, Hashable, Sendable {

    // representation of a SwiftUI view modifier name
    let name: SyntaxViewModifierName
    
    // representation of argument(s) to SwiftUI view modifer
    var arguments: [SyntaxViewArgumentData]
}


/*
 TODO: some arguments to SwiftUI View constructors are void callbacks (= patch logic?) or SwiftUI views (= another ViewNode)
 TODO: `Argument.value` should be `enum ArgumentValue { case value(String), actionClosure(???), viewClosure(ViewNode) }`
 
 Note: per chat with Vatsal, can also ask LLM to rewrite certain SwiftUI View closure-styles into non-closure versions etc. in an additional pass.

 ```swift
 Button(
    action: { ... }, // patch logic?
    label: { ViewNode }
 )
 ```
 */
struct SyntaxViewArgumentData: Equatable, Hashable, Sendable {
    let label: String? //SyntaxViewModifierArgumentLabel
    let value: SyntaxViewModifierArgumentType
}

struct SyntaxViewSimpleData: Hashable, Sendable {
    let value: String
    let syntaxKind: SyntaxArgumentKind
}

struct SyntaxViewModifierComplexType: Equatable, Hashable, Sendable {
    let typeName: String
    
    let arguments: [SyntaxViewArgumentData]
}

/*
 A single given parameter (i.e. a single label)
 could have a complex (more than just string) value or even multiple associated values, e.g.
 
 ```swift
 Rectangle()
     .rotation3DEffect(
        .degrees(90), // unlabeled, with non-string type
        axis: (x: 1, y: 0, z: 0) // labeled, with multiple associated values
    )
 ```
 */
indirect enum SyntaxViewModifierArgumentType: Equatable, Hashable, Sendable {
    
    // e.g. .opacity(5.0)
    case simple(SyntaxViewSimpleData)
    
    case complex(SyntaxViewModifierComplexType)
    
    case tuple([SyntaxViewArgumentData])
    
    case array([SyntaxViewModifierArgumentType])
}

extension SyntaxViewModifierArgumentType {
    var allNestedSimpleValues: [String] {
        switch self {
        case .simple(let syntaxViewSimpleData):
            return [syntaxViewSimpleData.value]
        case .complex(let syntaxViewModifierComplexType):
            return syntaxViewModifierComplexType.arguments
                .flatMap(\.value.allNestedSimpleValues)
        case .tuple(let array):
            return array.flatMap(\.value.allNestedSimpleValues)
        case .array(let array):
            return array.flatMap(\.allNestedSimpleValues)
        }
    }
    
    var simpleValue: String? {
        switch self {
        case .simple(let data):
            return data.value
            
        default:
            return nil
        }
    }
    
    var complexValue: SyntaxViewModifierComplexType? {
        switch self {
        case .complex(let data):
            return data
            
        default:
            return nil
        }
    }
}


// MARK: representation of

// TODO: this list falls very short of being the full list of SwiftUI view modifiers

/// Exhaustive (for now) list of SwiftUI modifiers we actively recognise.
/// (No such list or enum is otherwise already exposed by SwiftUI for us programmatically.)
/// `rawValue` is **always** the textual name of the modifier as it appears in
/// source (e.g. `"fill"`, `"frame"`). Any unknown name is stored using `.custom`.
enum SyntaxViewModifierName: String, Codable, Hashable, Equatable, Sendable {
    case accentColor = "accentColor"
    case accessibilityAction = "accessibilityAction"
    case accessibilityAddTraits = "accessibilityAddTraits"
    case accessibilityAdjustableAction = "accessibilityAdjustableAction"
    case accessibilityElement = "accessibilityElement"
    case accessibilityFocused = "accessibilityFocused"
    case accessibilityHidden = "accessibilityHidden"
    case accessibilityHint = "accessibilityHint"
    case accessibilityIdentifier = "accessibilityIdentifier"
    case accessibilityInputLabels = "accessibilityInputLabels"
    case accessibilityLabel = "accessibilityLabel"
    case accessibilityRemoveTraits = "accessibilityRemoveTraits"
    case accessibilityRepresentation = "accessibilityRepresentation"
    case accessibilityScrollAction = "accessibilityScrollAction"
    case accessibilityShowsLargeContentViewer = "accessibilityShowsLargeContentViewer"
    case accessibilitySortPriority = "accessibilitySortPriority"
    case allowsHitTesting = "allowsHitTesting"
    case allowsTightening = "allowsTightening"
    case animation = "animation"
    case aspectRatio = "aspectRatio"
    case background = "background"
    case badge = "badge"
    case baselineOffset = "baselineOffset"
    case blendMode = "blendMode"
    case blur = "blur"
    case bold = "bold"
    case border = "border"
    case brightness = "brightness"
    case buttonStyle = "buttonStyle"
    case clipped = "clipped"
    case clipShape = "clipShape"
    case colorInvert = "colorInvert"
    case colorMultiply = "colorMultiply"
    case compositingGroup = "compositingGroup"
    case containerRelativeFrame = "containerRelativeFrame"
    case contentShape = "contentShape"
    case contrast = "contrast"
    case controlSize = "controlSize"
    case cornerRadius = "cornerRadius"
    case contextMenu = "contextMenu"
    case disableAutocorrection = "disableAutocorrection"
    case disabled = "disabled"
    case drawingGroup = "drawingGroup"
    case dynamicTypeSize = "dynamicTypeSize"
    case environment = "environment"
    case environmentObject = "environmentObject"
    case exclusiveGesture = "exclusiveGesture"
    case fill = "fill"
    case fixedSize = "fixedSize"
    case focusable = "focusable"
    case focused = "focused"
    case font = "font"
    case fontDesign = "fontDesign"
    case fontWeight = "fontWeight"
    case foregroundColor = "foregroundColor"
    case foregroundStyle = "foregroundStyle"
    case frame = "frame"
    case gesture = "gesture"
    case help = "help"
    case highPriorityGesture = "highPriorityGesture"
    case hoverEffect = "hoverEffect"
    case hueRotation = "hueRotation"
    case id = "id"
    case ignoresSafeArea = "ignoresSafeArea"
    case interactiveDismissDisabled = "interactiveDismissDisabled"
    case italic = "italic"
    case kerning = "kerning"
    case layerId = "layerId"
    case layoutPriority = "layoutPriority"
    case lineLimit = "lineLimit"
    case lineSpacing = "lineSpacing"
    case listRowBackground = "listRowBackground"
    case listRowInsets = "listRowInsets"
    case listRowSeparator = "listRowSeparator"
    case listRowSeparatorTint = "listRowSeparatorTint"
    case listSectionSeparator = "listSectionSeparator"
    case listSectionSeparatorTint = "listSectionSeparatorTint"
    case listSectionSeparatorVisibility = "listSectionSeparatorVisibility"
    case listStyle = "listStyle"
    case mask = "mask"
    case matchedGeometryEffect = "matchedGeometryEffect"
    case menuStyle = "menuStyle"
    case minimumScaleFactor = "minimumScaleFactor"
    case monospaced = "monospaced"
    case monospacedDigit = "monospacedDigit"
    case multilineTextAlignment = "multilineTextAlignment"
    case navigationBarBackButtonHidden = "navigationBarBackButtonHidden"
    case navigationBarHidden = "navigationBarHidden"
    case navigationBarItems = "navigationBarItems"
    case navigationBarTitle = "navigationBarTitle"
    case navigationBarTitleDisplayMode = "navigationBarTitleDisplayMode"
    case navigationDestination = "navigationDestination"
    case navigationTitle = "navigationTitle"
    case offset = "offset"
    case onAppear = "onAppear"
    case onChange = "onChange"
    case onDisappear = "onDisappear"
    case onDrag = "onDrag"
    case onDrop = "onDrop"
    case onHover = "onHover"
    case onLongPressGesture = "onLongPressGesture"
    case onSubmit = "onSubmit"
    case onTapGesture = "onTapGesture"
    case opacity = "opacity"
    case overlay = "overlay"
    case padding = "padding"
    case position = "position"
    case preferredColorScheme = "preferredColorScheme"
    case presentationCornerRadius = "presentationCornerRadius"
    case presentationDetents = "presentationDetents"
    case progressViewStyle = "progressViewStyle"
    case projectionEffect = "projectionEffect"
    case redacted = "redacted"
    case refreshable = "refreshable"
    case rotation3DEffect = "rotation3DEffect"
    case rotationEffect = "rotationEffect"
    case safeAreaInset = "safeAreaInset"
    case saturation = "saturation"
    case scaleEffect = "scaleEffect"
    case scrollClipDisabled = "scrollClipDisabled"
    case scrollDisabled = "scrollDisabled"
    case scrollDismissesKeyboard = "scrollDismissesKeyboard"
    case scrollIndicators = "scrollIndicators"
    case scrollTargetBehavior = "scrollTargetBehavior"
    case searchable = "searchable"
    case sensoryFeedback = "sensoryFeedback"
    case shadow = "shadow"
    case simultaneousGesture = "simultaneousGesture"
    case sliderStyle = "sliderStyle"
    case smallCaps = "smallCaps"
    case strikethrough = "strikethrough"
    case submitLabel = "submitLabel"
    case swipeActions = "swipeActions"
    case symbolEffect = "symbolEffect"
    case symbolRenderingMode = "symbolRenderingMode"
    case tableStyle = "tableStyle"
    case task = "task"
    case textCase = "textCase"
    case textContentType = "textContentType"
    case textFieldStyle = "textFieldStyle"
    case textInputAutocapitalization = "textInputAutocapitalization"
    case textSelection = "textSelection"
    case tint = "tint"
    case toggleStyle = "toggleStyle"
    case toolbar = "toolbar"
    case tracking = "tracking"
    case transformEffect = "transformEffect"
    case transition = "transition"
    case truncationMode = "truncationMode"
    case underline = "underline"
    case uppercaseSmallCaps = "uppercaseSmallCaps"
    case zIndex = "zIndex"
    // …add more as needed …
}

/// Type-erased Encodable wrapper for heterogeneous values
struct AnyEncodable: Encodable {
    private let _encode: (Encoder) throws -> Void

    init<T: Encodable>(_ value: T) {
        self._encode = value.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
}

extension Array where Element == SyntaxViewArgumentData {
    func decode<DecodingType>(_ asType: DecodingType.Type) throws -> DecodingType where DecodingType: Decodable {
        let dict = try self.createValuesDict()
        let data = try JSONEncoder().encode(dict)
        
        let decodedType = try JSONDecoder().decode(asType.self, from: data)
        return decodedType
    }
    
    func createValuesDict() throws -> [String : AnyEncodable] {
        try self.reduce(into: .init()) { result, arg in
            guard let label = arg.label else {
                // Should expect labels for complex types
                throw SwiftUISyntaxError.noLabelFoundForComplexType
            }
            
            switch arg.value {
            case .simple(let value):
                let value = value.value
                    .replacingOccurrences(of: "“", with: "\"")
                    .replacingOccurrences(of: "”", with: "\"")
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
//                    .createEncoding()
                result.updateValue(AnyEncodable(value), forKey: label)
                
            case .complex(let complexData):
                // Get encoding data recursively
                let data = try complexData.arguments.createValuesDict()
                result.updateValue(AnyEncodable(data), forKey: label)
                
            default:
                // TODO: make sure other types are accounted for
                fatalError()
            }
        }
    }
}
