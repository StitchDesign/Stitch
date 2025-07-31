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
    let layerData: CurrentAIGraphData.LayerData
    let silentErrors: [SwiftUISyntaxError]
}

struct LayerInputValuesDerivationResult {
    let inputValues: [LayerPortDerivation]
    let silentErrors: [SwiftUISyntaxError]
}

struct LayerPortDerivation {
    let coordinate: CurrentAIGraphData.LayerInputType
    let inputData: LayerPortDerivationType
}

enum LayerPortDerivationType {
    case value(CurrentAIGraphData.PortValue)
    case stateRef(String)
}

extension LayerPortDerivationType {
    var value: CurrentAIGraphData.PortValue? {
        switch self {
        case .value(let value):
            return value
            
        default:
            return nil
        }
    }
}

extension SyntaxViewModifierName {
    // May or may not correspond to SwiftUI view modifier's own default argument,
    // e.g. `.clipped`'s default argument is for antialiasing, not whether the view is clipped or not (which is what Stitch's clipped layer-input is about).
    func deriveDefaultPortValueForArgumentlessViewModifier(
//        layer: CurrentAIGraphData.Layer,
//        layerInput: CurrentLayerInputPort
    ) throws -> CurrentAIGraphData.PortValue? {
        
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
                         args: ViewConstructorType?,
                         modifiers: [SyntaxViewModifier],
                         childrenLayers: [CurrentAIGraphData.LayerData]) throws -> LayerDerivationResult {
        var silentErrors = [SwiftUISyntaxError]()
        var layerData: CurrentAIGraphData.LayerData
        let layerType: CurrentAIGraphData.Layer
        
        switch args {
            
        case .trackedConstructor(let constructor):
            // Creates view data based on caller/constructor
            let customInputValuesFromViewConstructor = try self
                .deriveInputValuesData(viewConstructor: constructor,
                                       id: id)
            layerType = constructor.value.layer
            layerData = .init(node_id: id.description,
                              node_name: .init(value: .layer(constructor.value.layer)),
                              custom_layer_input_values: customInputValuesFromViewConstructor.inputValues)
            
            if !childrenLayers.isEmpty {
                layerData.children = childrenLayers
            }
            
            silentErrors += customInputValuesFromViewConstructor.silentErrors
            
        case .other, .none:
            // Legacy handling
            let args = args?.defaultArgs ?? []
            
            // ── Base mapping from SyntaxViewName → Layer ────────────────────────
            (layerType, layerData) = try self
                .deriveLayerAndCustomValuesFromName(id: id,
                                                    args: args,
                                                    childrenLayers: childrenLayers)
            
            let customInputValuesFromViewConstructor = try self
                .deriveInputValuesData(args: args,
                                       id: id,
                                       layerType: layerType)
                    
            layerData.custom_layer_input_values += customInputValuesFromViewConstructor.inputValues
            silentErrors += customInputValuesFromViewConstructor.silentErrors
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
//        layerData.custom_layer_input_values = layerData.custom_layer_input_values
//            .map { customInputValue in
//                var customInputValue = customInputValue
//                customInputValue.layer_input_coordinate.layer_id = layerData.node_id
//                return customInputValue
//            }
        
        return .init(layerData: layerData,
                     silentErrors: silentErrors)
    }
    
    func deriveInputValuesData(viewConstructor: ViewConstructor,
                               id: UUID) throws -> LayerInputValuesDerivationResult {
        var silentErrors = [SwiftUISyntaxError]()
        let layerType = viewConstructor.value.layer
        
        let values =
        
        // Handle constructor-arguments
        // Try to access the SyntaxView.ViewConstructor, if we have one
        let customInputValues = try viewConstructor.value
            .createCustomValueEvents()
        
//        let values = try customInputValues.map { astInputValue in
//            try CurrentAIGraphData
//                .CustomLayerInputValue(id: id,
//                                       input: astInputValue.input,
//                                       value: astInputValue.value)
//        }
        return .init(inputValues: customInputValues,
                     silentErrors: silentErrors)
    }
    
    func deriveInputValuesData(args: [SyntaxViewArgumentData],
                               id: UUID,
                               layerType: CurrentAIGraphData.Layer) throws -> LayerInputValuesDerivationResult {
        var silentErrors = [SwiftUISyntaxError]()
        
        // Else fall back to legacy style:
        var values = try args.flatMap { arg -> [LayerPortDerivation] in
            do {
                return try self
                    .deriveCustomValuesFromConstructorArgument(layerType: layerType,
                                                               arg: arg)
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
                try LayerPortDerivation(id: id,
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
                                                   arg: SyntaxViewArgumentData
    ) throws -> [LayerPortDerivation] {
        
//        if arg.value.allArgumentTypesFlattened.isEmpty && self == .scrollView {
//            return [
//                .init(layer_input_coordinate: .init(layer_id: .init(value: id),
//                                                    input_port_type: .init(value: .scrollYEnabled)),
//                      value: .bool(true))
//            ]
//        }
        
        return try arg.value.allArgumentTypesFlattened.flatMap { argFlatType -> [LayerPortDerivation] in
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
            
            return values
        }
    }
    
    private static func deriveCustomValuesFromViewModifier(id: UUID,
                                                           layerType: CurrentAIGraphData.Layer,
                                                           modifier: SyntaxViewModifier) throws -> LayerInputViewModification? {
        
        
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
                layerType: layerType)
            
            return .layerInputValues(newValues)
            
        case .rotationScenario:
            // Certain modifiers, e.g. `.rotation3DEffect` correspond to multiple layer-inputs (.rotationX, .rotationY, .rotationZ)
            let newValues = try Self.deriveCustomValuesFromRotationLayerInputTranslation(
                id: id,
                layerType: layerType,
                modifier: modifier)
            
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
    
    // TODO: need to infer the value based on the view modifier, not the port (probably)
    
//    static func deriveCustomValue(
//        from arguments: [SyntaxViewArgumentData],
//        modifierName: SyntaxViewModifierName,
//        id: UUID,
//        port: CurrentAIGraphData.LayerInputPort, // simple because we have a single layer
//        layerType: CurrentAIGraphData.Layer
//    ) throws -> [LayerPortDerivation] {
//        //        let migratedPort = try port.convert(to: LayerInputPort.self)
//        //        let migratedLayerType = try layerType.convert(to: Layer.self)
//        //        let migratedPortValue = migratedPort.getDefaultValue(for: migratedLayerType)
//        
//        //
//        
//        let portValues = try Self.derivePortValues(
//            from: arguments,
//            modifierName: modifierName,
//            port: port,
//            layerType: layerType)
//        
//        // Important: save the `customValue` event *at the end*, after we've iterated over all the arguments to this single modifier
//        return try .init(id: id,
//                         input: port,
//                         value: portValue)
//    }
        
    private static func derivePortValues(
        from arguments: [SyntaxViewArgumentData],
        modifierName: SyntaxViewModifierName,
        port: CurrentAIGraphData.LayerInputPort,
        layerType: CurrentAIGraphData.Layer
    ) throws -> [LayerPortDerivation] {
        // Note: some modifiers can have no arguments, e.g. `.padding()`, `.clipped()`
        // In such a case, we return a default value for that SwiftUI view modifier.
        guard !arguments.isEmpty else {
            guard let value = try modifierName.deriveDefaultPortValueForArgumentlessViewModifier() else {
                return []
            }
            
            return [
                .init(coordinate: .init(layerInput: port,
                                        portType: .packed),
                      inputData: .value(value))
            ]
        }
        
        // Convert every argument into a PortValue, later logic determines if we need to pack info
        let portDataFromArgs = try arguments.flatMap {
            try Self.derivePortValues(from: $0.value,
                                      context: .viewModifier(port))
        }
        
        let portValuesFromArgs = portDataFromArgs.compactMap {
            switch $0.inputData {
            case .value(let value):
                return value
            default:
                return nil
            }
        }
        
        // Scenarios where we assumed packed value or connection
        if arguments.count == 1,
           let argument = arguments.first,
           // Decode PortValue from full arguments data
           let derivedPortData = try Self.derivePortValues(from: argument.value,
                                                           context: .viewModifier(port)).first?.inputData {
            return [
                .init(coordinate: .init(layerInput: port,
                                        portType: .packed),
                      inputData: derivedPortData)
            ]
        }
        
        // Unpacked scenarios
        return portDataFromArgs.enumerated().compactMap { (portIndex, portDataFromArg) -> LayerPortDerivation? in
            guard let unpackedType = UnpackedPortType(rawValue: portIndex) else {
                fatalErrorIfDebug()
                return nil
            }
            
            return .init(coordinate: .init(layerInput: port,
                                           portType: .unpacked(unpackedType)),
                         inputData: portDataFromArg.inputData)
        }
        
    
    
        
//        // Pack all values if each argument is PortValue data
//        else if portValuesFromArgs.count == portDataFromArgs.count {
//            let valueType = try port.getDefaultValue(layerType: layerType).nodeType
//            
//            let migratedValues = try portValuesFromArgs.map {
//                try $0.migrate()
//            }
//            
//            let packedValue = migratedValues.pack(type: valueType)
//            let aiPackedValue = try packedValue.convert(to: CurrentAIGraphData.PortValue.self)
//            return .value(aiPackedValue)
//        }
//        // Unpacked scenario because there's a mix of connections and values for this port
//        else {
//            ...
//        }
        
    }

    static func derivePortValues(from argument: SyntaxViewModifierArgumentType,
                                 context: SyntaxArgumentConstructorContext?) throws -> [LayerPortDerivationType] {
        
        switch argument {
        
        // Handles types like PortValueDescription
        case .complex(let complexType):
            return try handleComplexArgumentType(complexType,
                                                 context: context)
            
        case .tuple(let tupleArgs):
            // Recursively determine PortValue of each arg
            return try tupleArgs.flatMap {
                try Self.derivePortValues(from: $0.value,
                                          context: context)
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
                    return [
                        .init(input: port,
                              value: .color(color))
                    ]
                    
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
            let aiPortValue = try JSONDecoder().decode(CurrentAIGraphData.StitchAIPortValue.self, from: data)
            return [.init(input: port,
                          value: aiPortValue.value)]
            
        case .stateAccess(let varName):
            // TODO: need to pass in connection data here and update all helpers to support edge connections
            
            return [.stateRef(varName)]
        }
    }
    
    static func deriveCustomValuesFromRotationLayerInputTranslation(id: UUID,
                                                                    layerType: CurrentAIGraphData.Layer,
                                                                    modifier: SyntaxViewModifier) throws -> [CurrentAIGraphData.CustomLayerInputValue] {
        var customValues = [CurrentAIGraphData.CustomLayerInputValue]()
        
        guard let angleArgument = modifier.arguments.defaultArgs?[safe: 0],
              // TODO: JULY 2: could be degrees OR radians; Stitch currently only supports degrees
              angleArgument.value.complexValue?.typeName.contains(".degrees") ?? false else {
            
            //#if !DEV_DEBUG
            throw SwiftUISyntaxError.incorrectParsing(message: "Unable to parse rotation layer inputs correctly.")
            //#endif
        }
        
        // degrees = *how much* we're rotating the given rotation layer input
        // axes = *which* layer input (rotationX vs rotationY vs rotationZ) we're rotating
        let fn = { (port: CurrentAIGraphData.LayerInputPort, portValue: CurrentAIGraphData.PortValue) in
            customValues.append(try .init(id: id, input: port, value: portValue))
        }
        
        // i.e. viewModifier was .rotation3DEffect, since it had an `axis:` argument
        if let axisArgument = modifier.arguments.defaultArgs?[safe: 1],
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

func handleComplexArgumentType(_ complexType: SyntaxViewModifierComplexType,
                               context: SyntaxArgumentConstructorContext?) throws -> [LayerPortDerivationType] {
    
    let complexTypeName = SyntaxValueName(rawValue: complexType.typeName)
    switch complexTypeName {
    case .none:
        // Default scenario looks for first arg and extracts PortValue data
        guard complexType.arguments.count == 1,
              let firstArg = complexType.arguments.first else {
            throw SwiftUISyntaxError.unsupportedComplexValueType(complexType.typeName)
        }
        
        // Search for simple value recursively
        return try SyntaxViewName.derivePortValues(from: firstArg.value, context: context)
        
    case .portValueDescription:
        do {
            let aiPortValue = try complexType.arguments.decode(CurrentAIGraphData.StitchAIPortValue.self)
            return [.value(aiPortValue.value)]
        } catch {
            print("PortValue decoding error: \(error)")
            throw error
        }
    
    case .binding:
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
    case viewConstructor(SyntaxViewName, CurrentAIGraphData.LayerInputPort)
    case viewModifier(CurrentAIGraphData.LayerInputPort)
}

extension SyntaxViewModifierArgumentType {
    func derivePortValues() throws -> [LayerPortDerivationType] {
        try SyntaxViewName.derivePortValues(from: self,
                                            context: nil)
    }
}
