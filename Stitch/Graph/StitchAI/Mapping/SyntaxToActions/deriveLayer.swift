//
//  deriveLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftSyntax

struct LayerDerivationResult {
    let layerData: CurrentAIGraphData.LayerData
    let silentErrors: [SwiftUISyntaxError]
}

struct LayerInputValuesDerivationResult {
    let inputValues: [LayerPortDerivation]
    let silentErrors: [SwiftUISyntaxError]
}

struct LayerPortDerivation {
    var coordinate: CurrentAIGraphData.LayerInputType
    let inputData: [PatchSyntaxResultType]
}

extension Array where Element == PatchSyntaxResultType {
    func createUnpackedEvents(layerInputPort: LayerInputPort) throws -> [LayerPortDerivation] {
        let unpackedPortEvents = self.enumerated().map { portIndex, layerPortEvent in
            guard let unpackedPortIndex = UnpackedPortType(rawValue: portIndex) else {
                return LayerPortDerivation(input: layerInputPort,
                                           inputData: [layerPortEvent])
            }
            
            return LayerPortDerivation(coordinate: .init(
                layerInput: layerInputPort,
                portType: .unpacked(unpackedPortIndex)),
                                       inputData: [layerPortEvent])
            
        }
        
        return unpackedPortEvents
    }
}

struct PortValueDescription {
    let value: any (Codable & Sendable)
    let value_type: AIGraphData_V0.StitchAINodeType
}

extension PortValueDescription {
    init(_ value: PortValue) {
        self.value = value.anyCodable
        self.value_type = .init(value: value.nodeType)
    }
}

struct PrintablePortValueDescription: Encodable {
    let value: AnyEncodable
    let value_type: AIGraphData_V0.StitchAINodeType
}

extension PrintablePortValueDescription {
    init(_ value: PortValue) {
        self.value = .init(value.anyCodable)
        self.value_type = .init(value: value.nodeType)
    }
}

extension PortValue {
    init(from valueDesc: PortValueDescription) throws {
        var fakeMap = [String : UUID]()
        self = try AIGraphData_V0.PortValue
            .decodeFromAI(data: valueDesc.value,
                          valueType: valueDesc.value_type.value,
                          idMap: &fakeMap)
    }
}

extension SyntaxViewModifier {
    func deriveViewModifierEvents(layerId: UUID,
                                  isStreaming: Bool) throws -> [SwiftPatchViewEvent]? {
        guard self.name.isGestureModifier,
              let defaultArgs = self.arguments.defaultArgs else {
            return nil
        }
        
        // A few cases where we extrapolate a view event:
        // 1. The view modifier itself has the closure, like .tapGesture
        // 2. The closure is nested in something like .simultaneousGesture which needs to instantiate a gesture object first
        
        // Nested case
        if self.name.isGestureWithNestedClosure {
            let viewEvents = defaultArgs
                .compactMap { $0.value.viewEvent }
            
            let interactionsResults: [SwiftPatchViewEvent] = try viewEvents
                .compactMap { viewEvent -> SwiftPatchViewEvent? in
                    guard let actions = try viewEvent
                        .deriveViewEventData(layerId: layerId,
                                             isStreaming: isStreaming) else {
                    return nil
                }
                
                return actions
            }
            
            return interactionsResults
        }
        
        // Non-nested case
        else {
            // Get first closure
            let closureData = defaultArgs
                .compactMap { $0.value.closureData }
                .first
            
            guard let closureData = closureData,
                  let viewEvent = self.name.viewEvent else {
                return nil
            }
            
            // Parse script, grab first element with state mutation
            let actionsResult = try SwiftUIViewVisitor
                .parseSwiftUICode(closureData.script,
                                  willParseView: false)
                .bindingDeclarations
                .getSwiftPatchCodeTypes()
                
            return [
                .init(viewEvent: .init(layerId: layerId,
                                       type: viewEvent,
                                       gestureArg: nil),
                      codeStatements: actionsResult)
            ]
        }
    }
}

extension SyntaxViewModifierName {
    // Some modifiers have view events that can be extrapolated from.
    var viewEvent: SyntaxViewEventType? {
        switch self {
        case .onTapGesture:
            return .tapGesture
            
        default:
            return nil
        }
    }
    
    var isGestureModifier: Bool {
        switch self {
        case .onTapGesture, .onLongPressGesture, .simultaneousGesture, .gesture, .exclusiveGesture, .highPriorityGesture:
            return true
        default:
            return false
        }
    }
    
    var isGestureWithNestedClosure: Bool {
        switch self {
        case .gesture, .simultaneousGesture, .exclusiveGesture, .highPriorityGesture:
            return true
        default:
            return false
        }
    }
    
    // May or may not correspond to SwiftUI view modifier's own default argument,
    // e.g. `.clipped`'s default argument is for antialiasing, not whether the view is clipped or not (which is what Stitch's clipped layer-input is about).
    func deriveDefaultPortValueForArgumentlessViewModifier() throws -> CurrentAIGraphData.PortValue? {
        
        // defaultValue
        
        // Start from the default (i.e. false or disabled) value, and modifiy that?
        // Ensure you don't mix up the types?
//        let defaultPortValue = layerInput.getDefaultValueForPatchNodeInput(<#T##Int#>, <#T##NodeInputDefinitions#>, patch: <#T##Patch#>)
        
        switch self {
            
        case .padding:
            return .padding(.init(top: 16, right: 16, bottom: 16, left: 16))
            
        case .clipped:
            return .bool(true)
            
        case .fill:
            return .color(.gray)
            
        case .tint:
            return .color(.blue)
                        
        case .color:
            return .color(.gray)
        
        case .position:
            return .position(.zero)
            
        case .zIndex:
            return .number(.zero)
            
        case .opacity:
            return .number(1)
            
        case .offset:
            return .position(.zero)
            
        case .frame:
            // technically this is deprecated
            return .size(.init(width: .auto, height: .auto))
            
        case .underline:
            return .textDecoration(.underline)
            
        case .strikethrough:
            return .textDecoration(.strikethrough)
            
        case .blendMode:
            return .blendMode(.normal)
            
        case .colorInvert:
            return .bool(true)
            
        case .scrollDisabled:
            // TODO: come back here; .scrollDisabled out to set scroll-enabled x and y BOTH false ?
            return .bool(false)
            
        case .cornerRadius, .blur, .rotationEffect, .rotation3DEffect:
            // MUST have arg for cornerRadius
            throw SwiftUISyntaxError.unsupportedViewModifierCall(self)
                        
        default:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        }
    }
}

extension SyntaxViewName {
    /// Leaf-level mapping for **this** node only
    func deriveLayerData(id: UUID,
                         args: ViewConstructorType?,
                         modifiers: [SyntaxViewModifier],
                         childrenLayers: [CurrentAIGraphData.LayerData],
                         bindingDeclarations: [(String, SwiftParserInitializerType)],
                         isStreaming: Bool) throws -> LayerDerivationResult {
        var silentErrors = [SwiftUISyntaxError]()
        var layerData: CurrentAIGraphData.LayerData
        let layerType: CurrentAIGraphData.Layer
        
        switch args {
            
        case .trackedConstructor(let constructor):
            // Creates view data based on caller/constructor
            
            layerType = constructor.value.layer
            layerData = try constructor
                .value
                .createCustomValueEvents(childrenLayers: childrenLayers,
                                         nodeId: id.description,
                                         isStreaming: isStreaming)
                                        
        case .other, .none:
            let args = args?.defaultArgs ?? []

            // ── Base mapping from SyntaxViewName → Layer ────────────────────────
            (layerType, layerData) = try self
                .deriveLayerAndCustomValuesFromName(id: id,
                                                    args: args,
                                                    childrenLayers: childrenLayers)
            
            let customInputValuesFromViewConstructor = try self
                .deriveInputValuesData(args: args,
                                       id: id,
                                       layerType: layerType,
                                       isStreaming: isStreaming)
                    
            layerData.custom_layer_input_values += customInputValuesFromViewConstructor.inputValues
            silentErrors += customInputValuesFromViewConstructor.silentErrors
        }
        
        // Handle modifiers
        let customInputValuesFromViewModifiers = try modifiers.compactMap { modifier in
            do {
                return try Self.deriveCustomValuesFromViewModifier(
                    id: id,
                    layerType: layerType,
                    modifier: modifier,
                    isStreaming: isStreaming)
            } catch let error as SwiftUISyntaxError {
                silentErrors.append(error)
                return nil
            } catch {
                throw error
            }
        }
        
        // Parse view modifiers
        for modifierEvent in customInputValuesFromViewModifiers {
            switch modifierEvent {
            case .layerInputValues(let valuesList):
                layerData.custom_layer_input_values += valuesList
            case .layerIdAssignment(let string):
                layerData.node_id = string
            }
        }
        
        // Handle view events like drag gestures
        let interactionEvents = modifiers.reduce(into: [SwiftPatchViewEvent]()) { result, modifier in
            do {
                if let actionsResult = try modifier.deriveViewModifierEvents(layerId: id,
                                                                             isStreaming: isStreaming) {
                    result += actionsResult
                }
            } catch let error as SwiftUISyntaxError {
                silentErrors.append(error)
            } catch {
                if !isStreaming {
                    fatalErrorIfDebug(error.localizedDescription)
                }
            }
        }
        
        layerData.view_events = interactionEvents
        
        return .init(layerData: layerData,
                     silentErrors: silentErrors)
    }
    
//    func deriveInputValuesData(viewConstructor: StrictViewConstructor,
//                               id: UUID) throws -> [LayerPortDerivation] {
//        // Handle constructor-arguments
//        // Try to access the SyntaxView.ViewConstructor, if we have one
//        let customInputValues = try viewConstructor.value
//            .createCustomValueEvents()
//        
//        return customInputValues
//    }
    
    func deriveInputValuesData(args: [SyntaxViewArgumentData],
                               id: UUID,
                               layerType: CurrentAIGraphData.Layer,
                               isStreaming: Bool) throws -> LayerInputValuesDerivationResult {
        var silentErrors = [SwiftUISyntaxError]()
        
        // Else fall back to legacy style:
        var values = try args.flatMap { arg -> [LayerPortDerivation] in
            do {
                return try self
                    .deriveCustomValuesFromConstructorArgument(layerType: layerType,
                                                               arg: arg,
                                                               isStreaming: isStreaming)
            } catch let error as SwiftUISyntaxError {
                silentErrors.append(error)
                return []
            } catch {
                throw error
            }
        }
        
        // TODO: remove and rely on ScrollViewConstructor instead
        if args.isEmpty && self == .scrollView {
            values += [
                LayerPortDerivation(id: id,
                                    input: .scrollYEnabled,
                                    value: .bool(true))
            ]
        }
        
        return .init(inputValues: values,
                     silentErrors: silentErrors)
    }
    
    func deriveLayerAndCustomValuesFromName(
        id: UUID,
        args: [SyntaxViewArgumentData],
        childrenLayers: [CurrentAIGraphData.LayerData]
    ) throws -> (CurrentAIGraphData.Layer, CurrentAIGraphData.LayerData) {
        
        var layerType: CurrentAIGraphData.Layer
        var customValues: [LayerPortDerivation] = []
        
        switch self {
        case .rectangle:         layerType = .rectangle
            
            // Note: Swift Circle is a little bit different
        case .circle, .ellipse, .oval:  layerType = .oval
            
            // SwiftUI Text view has different arg-constructors, but those do not change the Layer we return
        case .text: layerType = .text
            
            // SwiftUI TextField view has different arg-constructors, but those do not change the Layer we return
        case .textField: layerType = .textField
            
        case .image:
            if args.first?.label == SyntaxConstructorArgumentLabel.systemName.rawValue {
                layerType = .sfSymbol
            } else {
                layerType = .image
            }
            
        case .map: layerType = .map
            
            // Revisit these
        case .videoPlayer: layerType = .video
        case .model3D: layerType = .model3D
            
        case .linearGradient: layerType = .linearGradient
        case .radialGradient: layerType = .radialGradient
        case .angularGradient: layerType = .angularGradient
        case .material: layerType = .material
            
            // TODO: JUNE 24: what actually is SwiftUI sketch ?
        case .canvas: layerType = .canvasSketch
            
        case .secureField:
            // TODO: JUNE 24: ought to return `(Layer.textField, LayerInputPort.keyboardType, UIKeyboardType.password)` ? ... so a SwiftUI View can correspond to more than just a Layer ?
            layerType = .textField
            
            // TODO: JUNE 24: current Step_V0 doesn't support keyboard ?
            //            customValues.append(
            //                .init(id: id,
            //                      input: .keyboardType,
            //                      value: .keyboardType(.password))
            //            )
            
        case .scrollView:
            // Handled by `ScrollViewViewConstructor` now
            
//            fatalErrorIfDebug()
//            let layerData = try Self
//                .createScrollGroupLayer(args: args,
//                                        childrenLayers: childrenLayers)
//            return (.group, layerData)
            layerType = .group
            
            // MARK: CONTAINER VIEWS
            
        case .hStack, .lazyHStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.horizontal))
            )
            
        case .vStack, .lazyVStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.vertical))
            )
            
        case .zStack:
            layerType = .group
            customValues.append(
                .init(id: id,
                      input: .orientation,
                      value: .orientation(.none))
            )
            
            // TODO: JULY 3: technically, we don't support `LazyHGrid` and `Grid`?
//        case .lazyVGrid, .lazyHGrid, .grid:
//            layerType = .group
//            customValues.append(
//                .init(id: id,
//                      input: .orientation,
//                      value: .orientation(.grid))
//            )
            
            
        case .toggle:
            layerType = .switchLayer
            
        case .progressView:
            layerType = .progressIndicator
            
            // MARK: views / layers we likely want to support ?
        case .spacer:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        case .divider:
            throw SwiftUISyntaxError.unsupportedLayer(self)
            
        case .color:
            throw SwiftUISyntaxError.unsupportedLayer(self) // both Layer.hitArea AND Layer.colorFill
            
            // MARK: views we may never support? Either because inferred or some other dynamic
            
            
        case .capsule,
                .path,
                .label,
                .asyncImage,
                .symbolEffect,
                .geometryReader,
                .alignmentGuide,
                .list,
                .table,
                .outlineGroup,
            
            // Never really supported? Instead just inferred.
                .forEach,
            
            // Just specifies that modifiers on the SwiftUI Group are meant to be applied to every view inside ?
                .group,
                .navigationStack,
                .navigationSplit,
                .navigationLink,
                .tabView,
                .form,
                .section,
                .button,
                .slider,
                .stepper,
                .picker,
                .datePicker,
                .gauge,
                .link,
                .timelineView,
                .anyView,
                .preview,
                .timelineSchedule:
            throw SwiftUISyntaxError.unsupportedLayer(self)
            
        case .roundedRectangle:
            // TODO: come back here
            layerType = .rectangle

        default:
            throw SwiftUISyntaxError.unsupportedLayer(self)
        }
        
        // Final bare layer (children added later)
        var layerNode = CurrentAIGraphData
            .LayerData(node_id: id.description,
                       node_name: .init(value: .layer(layerType)),
                       custom_layer_input_values: customValues)
        
        if !childrenLayers.isEmpty {
            layerNode.children = childrenLayers
        }
        
        return (layerType, layerNode)
    }
    
    func deriveCustomValuesFromConstructorArgument(layerType: CurrentAIGraphData.Layer,
                                                   arg: SyntaxViewArgumentData,
                                                   isStreaming: Bool
    ) throws -> [LayerPortDerivation] {
        
//        if arg.value.allArgumentTypesFlattened.isEmpty && self == .scrollView {
//            return [
//                .init(layer_input_coordinate: .init(layer_id: .init(value: id),
//                                                    input_port_type: .init(value: .scrollYEnabled)),
//                      value: .bool(true))
//            ]
//        }
        
        var result = [LayerPortDerivation]()
        
        for argFlatType in arg.value.allArgumentTypesFlattened {
            guard let port = try SyntaxViewArgumentData.deriveLayerInputPort(
                layerType,
                label: arg.label, // the overall label for the entire argument
                argFlatType: argFlatType,
            ) else {
                continue
            }
            
            // log("SyntaxViewName: deriveCustomValuesFromConstructorArguments: port: \(port)")
            
            let values = try SyntaxViewName.derivePortValues(
                from: argFlatType.toSyntaxViewModifierArgumentType,
                port: port,
                context: .viewConstructor(self, port),
                isStreaming: isStreaming)
            
            // log("SyntaxViewName: deriveCustomValuesFromConstructorArguments: values: \(values)")
            
            result += values
        }
        
        return result
    }
    
    private static func deriveCustomValuesFromViewModifier(id: UUID,
                                                           layerType: CurrentAIGraphData.Layer,
                                                           modifier: SyntaxViewModifier,
                                                           isStreaming: Bool) throws -> LayerInputViewModification? {
        
        
        // TODO: derivation result needs to be used for inferring the value type to decode from some view modifier
        
        let derivationResult = try modifier.name.deriveLayerInputPort(layerType)
        
        switch derivationResult {
        case .none:
            return nil
            
        case .simple(let port):
            let newValues = try Self.derivePortValues(
                from: modifier.arguments.defaultArgs ?? [],
                modifierName: modifier.name,
                port: port,
                layerType: layerType,
                isStreaming: isStreaming)
            
            return .layerInputValues(newValues)
            
        case .positionWithAnchoring(let port, let anchoring):
            // Handle position modifier with explicit anchoring
            var newValues = try Self.derivePortValues(
                from: modifier.arguments.defaultArgs ?? [],
                modifierName: modifier.name,
                port: port,
                layerType: layerType,
                isStreaming: isStreaming)
            
            // Add the anchoring value as an additional layer port derivation
            newValues.append(LayerPortDerivation(input: .anchoring, 
                                               value: .anchoring(anchoring)))
            
            return .layerInputValues(newValues)
                        
        case .layerId:
            guard let rawValue = modifier.arguments.defaultArgs?.first?.value.simpleValue else {
                throw SwiftUISyntaxError.unsupportedLayerIdParsing(modifier.arguments.defaultArgs ?? [])
            }
            // Remove escape characters from any quoted substrings
            let unescaped = rawValue.replacingOccurrences(of: "\\\"", with: "\"")
            // Trim any surrounding quotes
            let cleanString = unescaped.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return .layerIdAssignment(cleanString)
            
//        case .textDecoration, .aspectRatio, .textFont:
//            throws SwiftUISyntaxError.unsupportedViewModifier(<#T##SyntaxViewModifierName#>)
        }
    }

    private static func derivePortValues(
        from arguments: [SyntaxViewArgumentData],
        modifierName: SyntaxViewModifierName,
        port: CurrentAIGraphData.LayerInputPort,
        layerType: CurrentAIGraphData.Layer,
        isStreaming: Bool
    ) throws -> [LayerPortDerivation] {
        // Try to use ViewModifierConstructor for structured parsing first
        if let viewModifierConstructor = createKnownViewModifier(modifierName: modifierName, arguments: arguments) {
            return try viewModifierConstructor.value.createCustomValueEvents(isStreaming: isStreaming)
            
            // // Return the first matching port value for this modifier
            // for customInput in customInputValues {
            //     if customInput.input == port {
            //         return customInput.value
            //     }
            // }
        }
        
        // Note: some modifiers can have no arguments, e.g. `.padding()`, `.clipped()`
        // In such a case, we return a default value for that SwiftUI view modifier.
        guard !arguments.isEmpty else {
            guard let value = try modifierName.deriveDefaultPortValueForArgumentlessViewModifier() else {
                return []
            }
            
            return [
                .init(coordinate: .init(layerInput: port,
                                        portType: .packed),
                      inputData: [.portData(.values([value]))])
            ]
        }
        
        // Convert every argument into a PortValue, later logic determines if we need to pack info
        let portDataFromArgs = try arguments.flatMap {
            try Self.derivePortValues(from: $0.value,
                                      port: port,
                                      context: .viewModifier(port),
                                      isStreaming: isStreaming)
        }
        
        // Scenarios where we assumed packed value or connection
        if arguments.count == 1,
           let argument = arguments.first,
           // Decode PortValue from full arguments data
           let derivedPortData = try Self
            .derivePortValues(from: argument.value,
                              port: port,
                              context: .viewModifier(port),
                              isStreaming: isStreaming).first?.inputData {
            return [
                .init(coordinate: .init(layerInput: port,
                                        portType: .packed),
                      inputData: derivedPortData)
            ]
        }
        
        // Unpacked scenarios
        return portDataFromArgs.enumerated().compactMap { (portIndex, portDataFromArg) -> LayerPortDerivation? in
            guard let unpackedType = UnpackedPortType(rawValue: portIndex) else {
                return nil
            }
            
            return .init(coordinate: .init(layerInput: port,
                                           portType: .unpacked(unpackedType)),
                         inputData: portDataFromArg.inputData)
        }
    }

    // TODO: we should not actually need `context` when calling `derivePortValues` from within the `createCustomValueEvents` method of an explicitly supported view-constructors and view-modifiers (which *just is* the "context");
    // in practice, this function is mostly helpful for handling the PortValueDescriptions returned by our LLM
    static func derivePortValues(from argument: SyntaxViewModifierArgumentType,
                                 port: LayerInputPort,
                                 context: SyntaxArgumentConstructorContext?,
                                 isStreaming: Bool) throws -> [LayerPortDerivation] {
        switch argument {
        case .memberAccess(let memberAccess):
            // need to return PortValue, but need to know which is the relevant type
            // e.g. Color is base name
            // examples: `Color.yellow`, `VerticalAlignment.center`, `EdgeInsets.horizontal`
            // examples 2: `.yellow`, `.center`, `.horizontal`
            // ^^ so need context, e.g. the view modifier, e.g. `.fill` and `.foregroundColor` both take color
            switch context {
            case .none:
                // Edge case behavior needs context
                // fatalErrorIfDebug()
                throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                                
            case .viewConstructor(let viewName, let port):
                switch viewName {
                    
                case .scrollView:
                    // log("SyntaxViewName: derivePortValue: had view constructor for scroll view: port: \(port)")
                    // log("SyntaxViewName: derivePortValue: had view constructor for scroll view: memberAccess.valueText: \(memberAccess.property)")
                    // https://developer.apple.com/documentation/swiftui/scrollview
                    // ScrollView only supports a single un-labeled constructor-argument? The other constructor was deprecated?
                    switch port {
                    case .scrollYEnabled:
                        let portValue = CurrentAIGraphData.PortValue.bool(memberAccess.property == "vertical")
                        return [
                            .init(input: port,
                                  value: portValue)
                        ]
                        
                    case .scrollXEnabled:
                        let portValue = CurrentAIGraphData.PortValue.bool(memberAccess.property == "horizontal")
                        return [
                            .init(input: port,
                                  value: portValue)
                        ]
                        
                    default:
                        throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                    }
                    
                case .vStack, .hStack, .lazyVStack, .lazyHStack:
                    switch port {
                    case .layerGroupAlignment:
                        if let anchoring = Anchoring.fromAlignmentString(memberAccess.property),
                           //                            let migrated = try! anchoring.convert(to: Anchoring_V31.Anchoring.self)
                           let migrated = try? anchoring.convert(to: Anchoring.self) {
                            return [
                                .init(input: port,
                                      value: .anchoring(migrated))
                            ]
                        } else {
                            throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                        }
                        
                    case .spacing:
                        if let n = toNumberBasic(memberAccess.property) {
                            return [
                                .init(input: port,
                                      value: .spacing(.number(n)))]
                        } else {
                            throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                        }
                        
                    default:
                        throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                    }
                    
                default:
                    throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                }
                
            case .viewModifier(let port):
                switch port {
                case .color:
                    // Tricky color case, for Color.systemName etc.
                    let colorStr = memberAccess.property
                    guard let color = Color.fromSystemName(colorStr) else {
                        throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                    }
                    return [
                        .init(input: port,
                              value: .color(color))
                    ]
                    
                default:
                    throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                }
            }
            
        default:
            let values = try Self
                .derivePortValues(from: argument,
                                  varName: nil,
                                  viewEvent: nil,
                                  nodesDict: [:],
                                  isStreaming: isStreaming)
            
            return [
                .init(input: port,
                      inputData: values)
            ]
        }
    }

    static func derivePortValues(from argument: SyntaxViewModifierArgumentType,
                                 varName: String?,
                                 viewEvent: SyntaxViewEvent?,
                                 nodesDict: [UUID: NodeEntity],
                                 nodeType: NodeType? = nil,
                                 isStreaming: Bool) throws -> [PatchSyntaxResultType] {
        if let viewEvent = viewEvent,
           let resultFromViewEvent = try viewEvent
            .derivePatchData(from: argument,
                             varName: varName) {
            return resultFromViewEvent
        }
        
        switch argument {
        
        // Handles types like PortValueDescription
        case .complex(let complexType):
            return try handleComplexArgumentType(complexType,
                                                 varName: varName,
                                                 viewEvent: viewEvent,
                                                 nodesDict: nodesDict)
            
        case .tuple(let tupleArgs):
            return try tupleArgs
                .reorderUnapckedValues(varName: varName,
                                       viewEvent: viewEvent,
                                       nodesDict: nodesDict,
                                       nodeType: nodeType)
            
        case .array(let arrayArgs):
            // Recursively determine PortValue of each arg
            // log("SyntaxViewName: derivePortValue: had array: arrayArgs: \(arrayArgs)")
            return try arrayArgs.flatMap {
                // log("SyntaxViewName: derivePortValue: had array: $0: \($0)")
                // log("SyntaxViewName: derivePortValue: had array: context: \(context)")
                return try Self.derivePortValues(from: $0,
                                                 varName: varName,
                                                 viewEvent: viewEvent,
                                                 nodesDict: nodesDict,
                                                 nodeType: nodeType,
                                                 isStreaming: isStreaming)
            }
            
        case .simple(let data):
            switch data.syntaxKind {
            case .literal(let literaData):
                let valueType = try literaData.getValueType()
                let valueEncoding = try data.createEncoding()
                
                // Create encodable dictionary
                let aiPortValueEncoding = [
                    "value": AnyEncodable(valueEncoding),
                    "value_type": AnyEncodable(valueType.asLLMStepNodeType)
                ]
                
                // Decode dictionary, getting a PortValue
                let data = try JSONEncoder().encode(aiPortValueEncoding)
                let aiPortValue = try JSONDecoder().decode(CurrentAIGraphData.StitchAIPortValue.self, from: data)
                
                return [
                    .portData(.values([aiPortValue.value]))
                ]

            default:
                // log("derivePortValues error: non-literal data found for simple case")
                throw SwiftUISyntaxError.portValueNotFound(argument: argument)
            }
            
        case .stateAccess(let stateAccessRef):
            return [.connectionToLayerInput(stateAccessRef)]

        case .memberAccess, .closure, .viewEvent, .view:
            throw SwiftUISyntaxError.portValueDecodingError(.portValueDecodingError(describe(argument)))
        }
    }
    
    @MainActor
    static func deriveCustomValuesFromRotationLayerInputTranslation(id: UUID,
                                                                    layerType: CurrentAIGraphData.Layer,
                                                                    modifier: SyntaxViewModifier,
                                                                    document: StitchDocumentViewModel,
                                                                    isStreaming: Bool) throws -> [LayerPortDerivation] {
        var customValues = [LayerPortDerivation]()
        
        guard let angleArgument = modifier.arguments.defaultArgs?[safe: 0],
              // TODO: JULY 2: could be degrees OR radians; Stitch currently only supports degrees
              angleArgument.value.complexValue?.typeName.contains(".degrees") ?? false else {
            
            //#if !DEV_DEBUG
            throw SwiftUISyntaxError.incorrectParsing(message: "Unable to parse rotation layer inputs correctly.")
            //#endif
        }
        
        // degrees = *how much* we're rotating the given rotation layer input
        // axes = *which* layer input (rotationX vs rotationY vs rotationZ) we're rotating
        let fn = { (port: CurrentAIGraphData.LayerInputPort, portDerivation: LayerPortDerivation) in
            var portDerivation = portDerivation
            portDerivation.coordinate = .init(layerInput: port,
                                              portType: .packed)
            customValues.append(portDerivation)
        }
        
        // i.e. viewModifier was .rotation3DEffect, since it had an `axis:` argument
        if let axisArgument = modifier.arguments.defaultArgs?[safe: 1],
           axisArgument.label == "axis" {
            let axisPortValues = try Self
                .derivePortValues(from: axisArgument.value,
                                  // port will be ignored
                                  port: .rotationX,
                                  context: nil,  // we can ignore context here
                                  isStreaming: isStreaming)
            guard let xAxis = axisPortValues[safe: 0],
                  let yAxis = axisPortValues[safe: 1],
                  let zAxis = axisPortValues[safe: 2] else {
                throw SwiftUISyntaxError.incorrectParsing(message: "Unable to decode axis arguments for rotation input.")
            }
            
            fn(.rotationX, xAxis)
            fn(.rotationY, yAxis)
            fn(.rotationZ, zAxis)
        }
        
        // i.e. viewModifier was .rotationEffect, since it did not have an `axis:` argument
        else {
            let portValues = try Self.derivePortValues(from: angleArgument.value,
                                                       // port is ignored
                                                       port: .rotationX,
                                                       context: nil,
                                                       isStreaming: isStreaming)
            assertInDebug(portValues.count == 1)
            guard let angleArgumentValue = portValues.first else {
                throw SwiftUISyntaxError.incorrectParsing(message: "Unable to parse PortValue from angle data.")
            }
            
            fn(.rotationZ, angleArgumentValue)
        }
        
        return customValues
    }
}

func handleComplexArgumentType(_ complexType: SyntaxViewModifierComplexType,
                               varName: String?,
                               viewEvent: SyntaxViewEvent?,
                               nodesDict: [UUID: NodeEntity],
                               isStreaming: Bool = false) throws -> [PatchSyntaxResultType] {
    
    let complexTypeName = SyntaxValueName(rawValue: complexType.typeName)
    switch complexTypeName {
    case .none:
        // Default scenario looks for first arg and extracts PortValue data
        guard complexType.arguments.count == 1,
              let firstArg = complexType.arguments.first else {
            throw SwiftUISyntaxError.unsupportedComplexValueType(complexType.typeName)
        }
        
        // Search for simple value recursively
        return try SyntaxViewName
            .derivePortValues(from: firstArg.value,
                              varName: varName,
                              viewEvent: viewEvent,
                              nodesDict: nodesDict,
                              isStreaming: isStreaming)
        
    case .portValueDescription:
        guard let firstArg = complexType.arguments.first else {
            return []
        }
        
        switch firstArg.value {
        case .simple:
            // Only decode PortValue directly if first arg is detected as a simple type
            do {
                let aiPortValue = try complexType.arguments.decode(CurrentAIGraphData.StitchAIPortValue.self)
                return [.portData(.values([aiPortValue.value]))]
            } catch {
                log("PortValue decoding error: \(error)")
                // fatalErrorIfDevDebug()
                throw error
            }
            
        case .memberAccess(let memberAccess):
            guard let viewEvent = viewEvent else {
                return []
            }

            return memberAccess
                .createConnectedPatchData(viewEvent: viewEvent,
                                          varName: varName)
            
        default:
            guard let secondArgString = complexType.arguments[safe: 1]?.value.simpleValue,
                  let nodeType = NodeType(llmString: secondArgString.stripQuotes()) else {
                return []
            }
            
            return try firstArg.value.derivePortValues(viewEvent: viewEvent,
                                                       nodeType: nodeType,
                                                       isStreaming: isStreaming)
        }
    
    case .binding, .color:
        // Do nothing for bindings
        return []
    }
}

extension CurrentAIGraphData.LayerInputPort {
    func getDefaultValue(layerType: CurrentAIGraphData.Layer) throws -> PortValue {
        
#if DEV_DEBUG
        let migratedPort = try! self.convert(to: LayerInputPort.self)
        let migratedLayerType = try! layerType.convert(to: Layer.self)
#else
        let migratedPort = try self.convert(to: LayerInputPort.self)
        let migratedLayerType = try layerType.convert(to: Layer.self)
#endif
        
        // Start with default value for that port
        return migratedPort.getDefaultValue(for: migratedLayerType)
    }
}

extension SyntaxArgumentLiteralKind {
    // Note: intended for simple syntaxKind
    func getValueType() throws -> NodeType {
        switch self {
        case .integer, .float, .prefixOperator:
            return .number
        case .string:
            return .string
        case .boolean:
            return .bool
        case .nilLiteral:
            return .none
        case .array, .dictionary, .tuple, .regex, .colorLiteral, .imageLiteral, .fileLiteral, .memberAccess:
            throw SwiftUISyntaxError.couldNotParseVarBody
        }
    }
}

enum SyntaxArgumentConstructorContext {
    case viewConstructor(SyntaxViewName, CurrentAIGraphData.LayerInputPort)
    case viewModifier(CurrentAIGraphData.LayerInputPort)
}

extension SyntaxViewModifierArgumentType {
    func derivePortValues(viewEvent: SyntaxViewEvent? = nil,
                          nodeType: NodeType? = nil,
                          isStreaming: Bool) throws -> [PatchSyntaxResultType] {
        try SyntaxViewName.derivePortValues(from: self,
                                            varName: nil,
                                            viewEvent: viewEvent,
                                            nodesDict: [:],
                                            nodeType: nodeType,
                                            isStreaming: isStreaming)
    }
}
