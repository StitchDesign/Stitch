//
//  deriveLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI

struct LayerDerivationResult {
    let layerData: CurrentAIPatchBuilderResponseFormat.LayerData
    let silentErrors: [SwiftUISyntaxError]
}

extension SyntaxViewModifierName {
    // May or may not correspond to SwiftUI view modifier's own default argument,
    // e.g. `.clipped`'s default argument is for antialiasing, not whether the view is clipped or not (which is what Stitch's clipped layer-input is about).
    func deriveDefaultPortValueForArgumentlessViewModifier(
//        layer: CurrentStep.Layer,
//        layerInput: CurrentLayerInputPort
    ) throws -> CurrentStep.PortValue? {
        
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
            fatalErrorIfDebug()
            return .bool(false)
            
        case .cornerRadius, .blur, .rotationEffect, .rotation3DEffect:
            // MUST have arg for cornerRadius
            throw SwiftUISyntaxError.unsupportedViewModifierCall(self)
                        
        default:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
//            
//        case .accentColor:
//            <#code#>
//        case .accessibilityAction:
//            <#code#>
//        case .accessibilityAddTraits:
//            <#code#>
//        case .accessibilityAdjustableAction:
//            <#code#>
//        case .accessibilityElement:
//            <#code#>
//        case .accessibilityFocused:
//            <#code#>
//        case .accessibilityHidden:
//            <#code#>
//        case .accessibilityHint:
//            <#code#>
//        case .accessibilityIdentifier:
//            <#code#>
//        case .accessibilityInputLabels:
//            <#code#>
//        case .accessibilityLabel:
//            <#code#>
//        case .accessibilityRemoveTraits:
//            <#code#>
//        case .accessibilityRepresentation:
//            <#code#>
//        case .accessibilityScrollAction:
//            <#code#>
//        case .accessibilityShowsLargeContentViewer:
//            <#code#>
//        case .accessibilitySortPriority:
//            <#code#>
//        case .allowsHitTesting:
//            <#code#>
//        case .allowsTightening:
//            <#code#>
//        case .animation:
//            <#code#>
//        case .aspectRatio:
//            <#code#>
//        case .background:
//            <#code#>
//        case .backgroundColor:
//            <#code#>
//        case .badge:
//            <#code#>
//        case .baselineOffset:
//            <#code#>
//        case .bold:
//            <#code#>
//        case .border:
//            <#code#>
//        case .brightness:
//            <#code#>
//        case .buttonStyle:
//            <#code#>
//        case .clipShape:
//            <#code#>
//        case .colorMultiply:
//            <#code#>
//        case .compositingGroup:
//            <#code#>
//        case .containerRelativeFrame:
//            <#code#>
//        case .contentShape:
//            <#code#>
//        case .contrast:
//            <#code#>
//        case .controlSize:
//            <#code#>
//        case .contextMenu:
//            <#code#>
//        case .disableAutocorrection:
//            <#code#>
//        case .disabled:
//            <#code#>
//        case .drawingGroup:
//            <#code#>
//        case .dynamicTypeSize:
//            <#code#>
//        case .environment:
//            <#code#>
//        case .environmentObject:
//            <#code#>
//        case .exclusiveGesture:
//            <#code#>
//        case .fixedSize:
//            <#code#>
//        case .focusable:
//            <#code#>
//        case .focused:
//            <#code#>
//        case .font:
//            <#code#>
//        case .fontDesign:
//            <#code#>
//        case .fontWeight:
//            <#code#>
//        case .foregroundColor:
//            <#code#>
//        case .foregroundStyle:
//            <#code#>
//        case .gesture:
//            <#code#>
//        case .help:
//            <#code#>
//        case .highPriorityGesture:
//            <#code#>
//        case .hoverEffect:
//            <#code#>
//        case .hueRotation:
//            <#code#>
//        case .id:
//            <#code#>
//        case .ignoresSafeArea:
//            <#code#>
//        case .interactiveDismissDisabled:
//            <#code#>
//        case .italic:
//            <#code#>
//        case .kerning:
//            <#code#>
//        case .layerId:
//            <#code#>
//        case .layoutPriority:
//            <#code#>
//        case .lineLimit:
//            <#code#>
//        case .lineSpacing:
//            <#code#>
//        case .listRowBackground:
//            <#code#>
//        case .listRowInsets:
//            <#code#>
//        case .listRowSeparator:
//            <#code#>
//        case .listRowSeparatorTint:
//            <#code#>
//        case .listSectionSeparator:
//            <#code#>
//        case .listSectionSeparatorTint:
//            <#code#>
//        case .listSectionSeparatorVisibility:
//            <#code#>
//        case .listStyle:
//            <#code#>
//        case .mask:
//            <#code#>
//        case .matchedGeometryEffect:
//            <#code#>
//        case .menuStyle:
//            <#code#>
//        case .minimumScaleFactor:
//            <#code#>
//        case .monospaced:
//            <#code#>
//        case .monospacedDigit:
//            <#code#>
//        case .multilineTextAlignment:
//            <#code#>
//        case .navigationBarBackButtonHidden:
//            <#code#>
//        case .navigationBarHidden:
//            <#code#>
//        case .navigationBarItems:
//            <#code#>
//        case .navigationBarTitle:
//            <#code#>
//        case .navigationBarTitleDisplayMode:
//            <#code#>
//        case .navigationDestination:
//            <#code#>
//        case .navigationTitle:
//            <#code#>
//        case .onAppear:
//            <#code#>
//        case .onChange:
//            <#code#>
//        case .onDisappear:
//            <#code#>
//        case .onDrag:
//            <#code#>
//        case .onDrop:
//            <#code#>
//        case .onHover:
//            <#code#>
//        case .onLongPressGesture:
//            <#code#>
//        case .onSubmit:
//            <#code#>
//        case .onTapGesture:
//            <#code#>
//        case .overlay:
//            <#code#>
//        case .preferredColorScheme:
//            <#code#>
//        case .presentationCornerRadius:
//            <#code#>
//        case .presentationDetents:
//            <#code#>
//        case .progressViewStyle:
//            <#code#>
//        case .projectionEffect:
//            <#code#>
//        case .redacted:
//            <#code#>
//        case .refreshable:
//            <#code#>
//        case .safeAreaInset:
//            <#code#>
//        case .saturation:
//            <#code#>
//        case .scaleEffect:
//            <#code#>
//        case .scrollClipDisabled:
//            <#code#>
//        case .scrollDisabled:
//            <#code#>
//        case .scrollDismissesKeyboard:
//            <#code#>
//        case .scrollIndicators:
//            <#code#>
//        case .scrollTargetBehavior:
//            <#code#>
//        case .searchable:
//            <#code#>
//        case .sensoryFeedback:
//            <#code#>
//        case .shadow:
//            <#code#>
//        case .simultaneousGesture:
//            <#code#>
//        case .sliderStyle:
//            <#code#>
//        case .smallCaps:
//            <#code#>
//        case .submitLabel:
//            <#code#>
//        case .swipeActions:
//            <#code#>
//        case .symbolEffect:
//            <#code#>
//        case .symbolRenderingMode:
//            <#code#>
//        case .tableStyle:
//            <#code#>
//        case .task:
//            <#code#>
//        case .textCase:
//            <#code#>
//        case .textContentType:
//            <#code#>
//        case .textFieldStyle:
//            <#code#>
//        case .textInputAutocapitalization:
//            <#code#>
//        case .textSelection:
//            <#code#>
//        case .toolbar:
//            <#code#>
//        case .tracking:
//            <#code#>
//        case .transformEffect:
//            <#code#>
//        case .transition:
//            <#code#>
//        case .truncationMode:
//            <#code#>
//        case .underline:
//            <#code#>
//        case .uppercaseSmallCaps:
//            <#code#>
        }
        
    }
}

extension SyntaxViewName {
    
    /// Leaf-level mapping for **this** node only
    func deriveLayerData(id: UUID,
                         viewConstructor: ViewConstructor?,
                         args: [SyntaxViewArgumentData],
                         modifiers: [SyntaxViewModifier],
                         childrenLayers: [CurrentAIPatchBuilderResponseFormat.LayerData]) throws -> LayerDerivationResult {
        var silentErrors = [SwiftUISyntaxError]()

        // ── Base mapping from SyntaxViewName → Layer ────────────────────────
        var (layerType, layerData) = try self
            .deriveLayerAndCustomValuesFromName(id: id,
                                                args: args,
                                                childrenLayers: childrenLayers)

        
        // Handle constructor-arguments
        
        var customInputValuesFromViewConstructor = [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]()

        // Try to access the SyntaxView.ViewConstructor, if we have one
        if let customInputValues = try viewConstructor?.getCustomValueEvents(id: id) {
            customInputValuesFromViewConstructor = customInputValues
        }
        
        // Else fall back to legacy style:
        else {
            customInputValuesFromViewConstructor = try args.flatMap { arg in
                do {
                    
                    return try self
                        .deriveCustomValuesFromConstructorArgument(id: id,
                                                                   layerType: layerType,
                                                                   arg: arg)
                } catch let error as SwiftUISyntaxError {
                    silentErrors.append(error)
                    return []
                } catch {
                    throw error
                }
            }
        }
        
        
        
        // TODO: remove and rely on ScrollViewConstructor instead
        if args.isEmpty && self == .scrollView {
            customInputValuesFromViewConstructor += [
                try .init(id: id,
                          input: .scrollYEnabled,
                          value: .bool(true))
            ]
        }
        
        
        // Handle modifiers
        let customInputValuesFromViewModifiers = try modifiers.compactMap { modifier in
            do {
                return try Self.deriveCustomValuesFromViewModifier(
                    id: id,
                    layerType: layerType,
                    modifier: modifier)
            } catch let error as SwiftUISyntaxError {
                silentErrors.append(error)
                return nil
            } catch {
                throw error
            }
        }
        
        layerData.custom_layer_input_values += customInputValuesFromViewConstructor
        
        // Parse view modifier events
        for modifierEvent in customInputValuesFromViewModifiers {
            switch modifierEvent {
            case .layerInputValues(let valuesList):
                layerData.custom_layer_input_values += valuesList
            case .layerIdAssignment(let string):
                layerData.node_id = string
            }
        }
        
        // Re-map all node IDs after processing layerIdAssignment
        layerData.custom_layer_input_values = layerData.custom_layer_input_values
            .map { customInputValue in
                var customInputValue = customInputValue
                customInputValue.layer_input_coordinate.layer_id = layerData.node_id
                return customInputValue
            }
        
        return .init(layerData: layerData,
                     silentErrors: silentErrors)
    }
    
    func deriveLayerAndCustomValuesFromName(
        id: UUID,
        args: [SyntaxViewArgumentData],
        childrenLayers: [CurrentAIPatchBuilderResponseFormat.LayerData]
    ) throws -> (CurrentStep.Layer, CurrentAIPatchBuilderResponseFormat.LayerData) {
        
        var layerType: CurrentStep.Layer
        var customValues: [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] = []
        
        switch self {
        case .rectangle:         layerType = .rectangle
            
            // Note: Swift Circle is a little bit different
        case .circle, .ellipse:  layerType = .oval
            
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
            let layerData = try Self
                .createScrollGroupLayer(args: args,
                                        childrenLayers: childrenLayers)
            return (.group, layerData)
            
            // MARK: CONTAINER VIEWS
            
        case .hStack, .lazyHStack:
            layerType = .group
            customValues.append(
                try .init(id: id,
                          input: .orientation,
                          value: .orientation(.horizontal))
            )
            
        case .vStack, .lazyVStack:
            layerType = .group
            customValues.append(
                try .init(id: id,
                          input: .orientation,
                          value: .orientation(.vertical))
            )
            
        case .zStack:
            layerType = .group
            customValues.append(
                try .init(id: id,
                          input: .orientation,
                          value: .orientation(.none))
            )
            
            // TODO: JULY 3: technically, we don't support `LazyHGrid` and `Grid`?
        case .lazyVGrid, .lazyHGrid, .grid:
            layerType = .group
            customValues.append(
                try .init(id: id,
                          input: .orientation,
                          value: .orientation(.grid))
            )
            
            
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
        var layerNode = CurrentAIPatchBuilderResponseFormat
            .LayerData(node_id: id.description,
                       node_name: .init(value: .layer(layerType)),
                       custom_layer_input_values: customValues)
        
        if !childrenLayers.isEmpty {
            layerNode.children = childrenLayers
        }
        
        return (layerType, layerNode)
    }
    
    func deriveCustomValuesFromConstructorArgument(id: UUID,
                                                   layerType: CurrentStep.Layer,
                                                   arg: SyntaxViewArgumentData
    ) throws -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
        
//        if arg.value.allArgumentTypesFlattened.isEmpty && self == .scrollView {
//            return [
//                .init(layer_input_coordinate: .init(layer_id: .init(value: id),
//                                                    input_port_type: .init(value: .scrollYEnabled)),
//                      value: .bool(true))
//            ]
//        }
        
        return try arg.value.allArgumentTypesFlattened.flatMap { argFlatType -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] in
            guard let port = try SyntaxViewArgumentData.deriveLayerInputPort(
                layerType,
                label: arg.label, // the overall label for the entire argument
                argFlatType: argFlatType,
            ) else {
                return []
            }
            
            // log("SyntaxViewName: deriveCustomValuesFromConstructorArguments: port: \(port)")
            
            let values = try SyntaxViewName.derivePortValues(
                from: argFlatType.toSyntaxViewModifierArgumentType,
                context: .viewConstructor(self, port))
            
            // log("SyntaxViewName: deriveCustomValuesFromConstructorArguments: values: \(values)")
            
            return try values.map { value in
                try .init(id: id,
                          input: port,
                          value: value)
            }
        }
    }
    
    private static func deriveCustomValuesFromViewModifier(id: UUID,
                                                           layerType: CurrentStep.Layer,
                                                           modifier: SyntaxViewModifier) throws -> LayerInputViewModification? {
        
        
        // TODO: derivation result needs to be used for inferring the value type to decode from some view modifier
        
        let derivationResult = try modifier.name.deriveLayerInputPort(layerType)
        
        switch derivationResult {
        case .none:
            return nil
            
        case .simple(let port):
            guard let newValue = try Self.deriveCustomValue(
                from: modifier.arguments,
                modifierName: modifier.name,
                id: id,
                port: port,
                layerType: layerType) else {
                // Valid nil scenarios for edges, variables etc
                return nil
            }
            
            return .layerInputValues([newValue])
            
        case .rotationScenario:
            // Certain modifiers, e.g. `.rotation3DEffect` correspond to multiple layer-inputs (.rotationX, .rotationY, .rotationZ)
            let newValues = try Self.deriveCustomValuesFromRotationLayerInputTranslation(
                id: id,
                layerType: layerType,
                modifier: modifier)
            
            return .layerInputValues(newValues)
            
        case .layerId:
            guard let rawValue = modifier.arguments.first?.value.simpleValue else {
                throw SwiftUISyntaxError.unsupportedLayerIdParsing(modifier.arguments)
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
    
    // TODO: need to infer the value based on the view modifier, not the port (probably)
    
    static func deriveCustomValue(
        from arguments: [SyntaxViewArgumentData],
        modifierName: SyntaxViewModifierName,
        id: UUID,
        port: CurrentStep.LayerInputPort, // simple because we have a single layer
        layerType: CurrentStep.Layer
    ) throws -> CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue? {
        //        let migratedPort = try port.convert(to: LayerInputPort.self)
        //        let migratedLayerType = try layerType.convert(to: Layer.self)
        //        let migratedPortValue = migratedPort.getDefaultValue(for: migratedLayerType)
        
        //
        
        guard let portValue = try Self.derivePortValue(
            from: arguments,
            modifierName: modifierName,
            port: port,
            layerType: layerType) else {
            return nil
        }
        
        // Important: save the `customValue` event *at the end*, after we've iterated over all the arguments to this single modifier
        return try .init(id: id,
                         input: port,
                         value: portValue)
    }
        
    private static func derivePortValue(
        from arguments: [SyntaxViewArgumentData],
        modifierName: SyntaxViewModifierName,
        port: CurrentStep.LayerInputPort,
        layerType: CurrentStep.Layer
    ) throws -> CurrentStep.PortValue? {
        // Note: some modifiers can have no arguments, e.g. `.padding()`, `.clipped()`
        // In such a case, we return a default value for that SwiftUI view modifier.
        guard !arguments.isEmpty else {
            return try modifierName.deriveDefaultPortValueForArgumentlessViewModifier()
        }
        
        // Convert every argument into a PortValue, later logic determines if we need to pack info
        let portValuesFromArgs = try arguments.flatMap {
            try Self.derivePortValues(from: $0.value,
                                      context: .viewModifier(port))
        }
        
        // TODO: MAYBE NOT QUITE CORRECT?, SINCE E.G. CERTAIN CONSTRUCTOR ARGUMENTS CAN BE e.g. `ScrollView([.horizontal, .vertical])`
        if arguments.count == 1,
           let argument = arguments.first {
            // Decode PortValue from full arguments data
            let derivedPortValues = try Self.derivePortValues(from: argument.value,
                                                              context: .viewModifier(port))
            return derivedPortValues.first
        }
        
        // Packing case
        else {
            let valueType = try port.getDefaultValue(layerType: layerType).nodeType
            
            let migratedValues = try portValuesFromArgs.map {
                try PortValueVersion.migrate(entity: $0,
                                             version: ._V31)
            }
            
            let packedValue = migratedValues.pack(type: valueType)
            let aiPackedValue = try packedValue.convert(to: CurrentStep.PortValue.self)
            return aiPackedValue
        }
    }

    static func derivePortValues(from argument: SyntaxViewModifierArgumentType,
                                 context: SyntaxArgumentConstructorContext?) throws -> [CurrentStep.PortValue] {
        
        switch argument {
        
        // Handles types like PortValueDescription
        case .complex(let complexType):
            let complexTypeName = SyntaxValueName(rawValue: complexType.typeName)
            switch complexTypeName {
            case .none:
                // Default scenario looks for first arg and extracts PortValue data
                guard complexType.arguments.count == 1,
                      let firstArg = complexType.arguments.first else {
                    throw SwiftUISyntaxError.unsupportedComplexValueType(complexType.typeName)
                }
                
                // Search for simple value recursively
                return try Self.derivePortValues(from: firstArg.value, context: context)
                
            case .portValueDescription:
                do {
                    let aiPortValue = try complexType.arguments.decode(StitchAIPortValue.self)
                    return [aiPortValue.value]
                } catch {
                    print("PortValue decoding error: \(error)")
                    throw error
                }
            
            case .binding:
                // Do nothing for bindings
                return []
            }
            
        case .tuple(let tupleArgs):
            // Recursively determine PortValue of each arg
            return try tupleArgs.flatMap {
                try Self.derivePortValues(from: $0.value, context: context)
            }
            
        case .array(let arrayArgs):
            // Recursively determine PortValue of each arg
            log("SyntaxViewName: derivePortValue: had array: arrayArgs: \(arrayArgs)")
            return try arrayArgs.flatMap {
                log("SyntaxViewName: derivePortValue: had array: $0: \($0)")
                log("SyntaxViewName: derivePortValue: had array: context: \(context)")
                return try Self.derivePortValues(from: $0, context: context)
            }
            
        case .memberAccess(let memberAccess):
            // need to return PortValue, but need to know which is the relevant type
            // e.g. Color is base name
            // examples: `Color.yellow`, `VerticalAlignment.center`, `EdgeInsets.horizontal`
            // examples 2: `.yellow`, `.center`, `.horizontal`
            // ^^ so need context, e.g. the view modifier, e.g. `.fill` and `.foregroundColor` both take color
            switch context {
            case .none:
                // Edge case behavior needs context
                fatalErrorIfDebug()
                throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                                
            case .viewConstructor(let viewName, let port):

                switch viewName {

                case .scrollView:
                    log("SyntaxViewName: derivePortValue: had view constructor for scroll view: port: \(port)")
                    log("SyntaxViewName: derivePortValue: had view constructor for scroll view: memberAccess.valueText: \(memberAccess.property)")
                    // https://developer.apple.com/documentation/swiftui/scrollview
                    // ScrollView only supports a single un-labeled constructor-argument? The other constructor was deprecated?
                    switch port {
                    case .scrollYEnabled:
                        return [.bool(memberAccess.property == "vertical")]
                    case .scrollXEnabled:
                        return [.bool(memberAccess.property == "horizontal")]
                    default:
                        throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                    }
                    
                case .vStack, .hStack, .lazyVStack, .lazyHStack:
                    switch port {
                    case .layerGroupAlignment:
                        if let anchoring = Anchoring.fromAlignmentString(memberAccess.property),
//                            let migrated = try! anchoring.convert(to: Anchoring_V31.Anchoring.self)
                           let migrated = try? anchoring.convert(to: Anchoring.PreviousCodable.self) {
                            return [.anchoring(migrated)]
                        } else {
                            throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                        }
                    
                    case .spacing:
                        if let n = toNumberBasic(memberAccess.property) {
                            return [.spacing(.number(n))]
                        } else {
                            throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                        }
                        
                    default:
                        throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                    }
                    
                default:
                    throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                }
                
//                let string = memberAccess.valueText
//                
//                // View constructor support needed
//                throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                
            case .viewModifier(let port):
                switch port {
                case .color:
                    // Tricky color case, for Color.systemName etc.
                    let colorStr = memberAccess.property
                    guard let color = Color.fromSystemName(colorStr) else {
                        throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                    }
                    return [.color(color)]
                    
                default:
                    throw SwiftUISyntaxError.unsupportedPortValueTypeDecoding(argument)
                }
            }
            
            
        case .simple(let data):
            let valueType = try data.syntaxKind.getValueType()
            let valueEncoding = try data.createEncoding()
            
            // Create encodable dictionary
            let aiPortValueEncoding = [
                "value": AnyEncodable(valueEncoding),
                "value_type": AnyEncodable(valueType.asLLMStepNodeType)
            ]
            
            // Decode dictionary, getting a PortValue
            let data = try JSONEncoder().encode(aiPortValueEncoding)
            let aiPortValue = try JSONDecoder().decode(StitchAIPortValue.self, from: data)
            return [aiPortValue.value]
        }
    }
    
    static func deriveCustomValuesFromRotationLayerInputTranslation(id: UUID,
                                                                    layerType: CurrentStep.Layer,
                                                                    modifier: SyntaxViewModifier) throws -> [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue] {
        var customValues = [CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue]()
        
        guard let angleArgument = modifier.arguments[safe: 0],
              // TODO: JULY 2: could be degrees OR radians; Stitch currently only supports degrees
              angleArgument.value.complexValue?.typeName.contains(".degrees") ?? false else {
            
            //#if !DEV_DEBUG
            throw SwiftUISyntaxError.incorrectParsing(message: "Unable to parse rotation layer inputs correctly.")
            //#endif
        }
        
        // degrees = *how much* we're rotating the given rotation layer input
        // axes = *which* layer input (rotationX vs rotationY vs rotationZ) we're rotating
        let fn = { (port: CurrentStep.LayerInputPort, portValue: CurrentStep.PortValue) in
            customValues.append(try .init(id: id, input: port, value: portValue))
        }
        
        // i.e. viewModifier was .rotation3DEffect, since it had an `axis:` argument
        if let axisArgument = modifier.arguments[safe: 1],
           axisArgument.label == "axis" {
            let axisPortValues = try Self.derivePortValues(from: axisArgument.value,
                                                           context: nil)  // we can ignore context here
            guard let xAxis = axisPortValues[safe: 0],
                  let yAxis = axisPortValues[safe: 1],
                  let zAxis = axisPortValues[safe: 2] else {
                throw SwiftUISyntaxError.incorrectParsing(message: "Unable to decode axis arguments for rotation input.")
            }
            
            try fn(.rotationX, xAxis)
            try fn(.rotationY, yAxis)
            try fn(.rotationZ, zAxis)
        }
        
        // i.e. viewModifier was .rotationEffect, since it did not have an `axis:` argument
        else {
            let portValues = try Self.derivePortValues(from: angleArgument.value,
                                                       context: nil)
            assertInDebug(portValues.count == 1)
            guard let angleArgumentValue = portValues.first else {
                throw SwiftUISyntaxError.incorrectParsing(message: "Unable to parse PortValue from angle data.")
            }
            
            try fn(.rotationZ, angleArgumentValue)
        }
        
        return customValues
    }
}

extension CurrentStep.LayerInputPort {
    func getDefaultValue(layerType: CurrentStep.Layer) throws -> PortValue {
        
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
        case .integer, .float:
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
    case viewConstructor(SyntaxViewName, CurrentStep.LayerInputPort)
    case viewModifier(CurrentStep.LayerInputPort)
}
