//
//  deriveSyntaxFromLayerInput.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftSyntax

enum SwiftUISyntaxError: Error, Hashable, Sendable {
    case unexpectedEdgeDataFound
    case viewNodeNotFound
    case couldNotParseVarBody
    case unsupportedViewModifier(SyntaxViewModifierName)
    
    // Decoding from string
    case unsupportedSyntaxArgumentKind(ExprSyntax)
    case unsupportedSyntaxArgument(String?)
    case unsupportedSyntaxViewName(String)
    case unsupportedSyntaxViewModifierName(String)
    case unsupportedSyntaxViewModifierArgumentName(String)
    case unsupportedComplexValueType(String)
    case unsupportedPortValueTypeDecoding(SyntaxArgumentLiteralKind)
    
    case unsupportedLayer(SyntaxViewName)
//    case unsupportedConstructorArgument(SyntaxViewArgumentData)
    case unsupportedSyntaxFromLayerInput(CurrentStep.LayerInputPort)
    case unsupportedSyntaxViewLayer(CurrentStep.Layer)
    
    case unsupportedLayerIdParsing([SyntaxViewArgumentData])
    case layerUUIDDecodingFailed(String)
    
    case incorrectParsing(message: String)
    case groupLayerDecodingFailed
    case layerDecodingFailed
    case unexpectedPatchFound(CurrentStep.PatchOrLayer)
    case portValueDataDecodingFailure
    
    // Value decoding
    case noLabelFoundForComplexType
    case invalidIntegerLiteral(String)
    case invalidFloatLiteral(String)
    case invalidBooleanLiteral(String)
    case invalidJSONLiteral(String)
    case unsupportedSimpleLiteralDecoding(SyntaxViewSimpleData)
    case syntaxValueDecodingFailed(SyntaxArgumentKind)
}

extension SwiftUISyntaxError {
    /// Errors that should allow request to continue.
    var shouldFailSilently: Bool {
        switch self {
        case .unsupportedSyntaxArgumentKind,
                .unsupportedSyntaxArgument,
                .unsupportedSyntaxViewName,
                .unsupportedSyntaxViewModifierName,
                .unsupportedSyntaxViewModifierArgumentName,
                .unsupportedLayer,
                .unsupportedSyntaxFromLayerInput,
                .unsupportedSyntaxViewLayer,
                .unsupportedComplexValueType:
            return true
            
        default:
            return false
        }
    }
}

extension CurrentStep.LayerInputPort {
    
    // MARK: 7/5 update: commenting out as we should be able to create PortValueDescription payloads into SwiftUI, which is how code-gen works
//    func toSwiftUISyntax(valueOrEdge: StitchValueOrEdge, // loops? should pass in `value` ?
//                         layer: CurrentStep.Layer) throws -> FromLayerInputToSyntax {
//        
//        guard let value = valueOrEdge.getValue else {
//            fatalErrorIfDebug("Incoming edges not yet handled")
//            throw SwiftUISyntaxError.unexpectedEdgeDataFound
//        }
//        
//        // TODO: JUNE 24: ASSUMES SINGLE-PARAMETER PORT VALUE, i.e. can handle .opacity but not .frame
//        let buildSingleFieldUnlabeledModifier = { (name: SyntaxViewModifierName) -> SyntaxViewModifier in
//            SyntaxViewModifier(name: name,
//                     arguments: [
//                        SyntaxViewModifierArgument(
//                            label: nil, // assumes unlabeled
////                            value: try valueOrEdge.asSwiftUILiteralOrVariable(),
////                            syntaxKind: valueOrEdge.asSwiftSyntaxKind
//                            value: .simple(SyntaxViewModifierArgumentData(value: try valueOrEdge.asSwiftUILiteralOrVariable(),
//                                                                          syntaxKind: valueOrEdge.asSwiftSyntaxKind))
//                        )
//                        
//                     ])
//        }
//        
//        let buildMultifieldModifier = { (name: SyntaxViewModifierName) -> FromLayerInputToSyntax in
//            if let modifier = value.deriveSyntaxViewModifierForMultifieldPortValue(name) {
//                return .modifier(modifier)
//            } else {
//                fatalErrorIfDebug("Failed to handle layer input \(self) with value \(value) for modifier \(name)")
//                throw SwiftUISyntaxError.unsupportedViewModifier(name)
//            }
//        }
//        
//        // We switch on `self` because we want to cover all LayerInput cases
//        switch self {
//            
//        case .anchoring:
//            // TODO: JUNE 24: handle `functions`
//            return .function(.anchoring)
//            
//        case .text:
//            // return .constructorArgument(.text(.noLabel))
//            let value = try valueOrEdge.asSwiftUILiteralOrVariable()
//            let syntaxKind = valueOrEdge.asSwiftSyntaxKind
//            return .constructorArgument(.init(
//                label: .noLabel,
//                values: [
//                    SyntaxViewConstructorArgumentValue(
//                        value: value,
//                        syntaxKind: syntaxKind
//                    )
//                ]
//            ))
//                        
//        case .sfSymbol:
//            let value = try valueOrEdge.asSwiftUILiteralOrVariable()
//            let syntaxKind = valueOrEdge.asSwiftSyntaxKind
//            return .constructorArgument(.init(
//                label: .systemName,
//                values: [
//                    SyntaxViewConstructorArgumentValue(
//                        value: value,
//                        syntaxKind: syntaxKind
//                    )
//                ]
//            ))
//            
//            
//        // TODO: JULY 1: orientation + LayerGroup become either ZStack or VStack or HStack etc.
//        // So there's not a simple mapping of "this layer input becomes a constructor-arg / view-modifier"
//        case .orientation:
//            // return .modifier(try buildSingleFieldUnlabeledModifier(.orientation))
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//            
//            
//        // TODO: JULY 1: handle how .scrollXEnabled and .scrollYEnabled are two different layer input ports that become a "single constructor-arg with two values" for the `syntax -> code`
//        // i.e. `ScrollView([.horizontal, .vertical]) ;
//        // can you reuse any logic elsewhere?
//        case .scrollXEnabled:
//            let value = try valueOrEdge.asSwiftUILiteralOrVariable()
//            let syntaxKind = valueOrEdge.asSwiftSyntaxKind
//            return .constructorArgument(.init(
//                label: .noLabel,
//                values: [
//                    SyntaxViewConstructorArgumentValue(value: value, syntaxKind: syntaxKind)
//                ]
//            ))
//            
//        case .scrollYEnabled:
//            let value = try valueOrEdge.asSwiftUILiteralOrVariable()
//            let syntaxKind = valueOrEdge.asSwiftSyntaxKind
//            return .constructorArgument(.init(
//                label: .noLabel,
//                values: [
//                    SyntaxViewConstructorArgumentValue(value: value, syntaxKind: syntaxKind)
//                ]
//            ))
//            
//            
//        // TODO: JUNE 24: how to handle PortValue.position(CGPoint) as a SwiftUI `.position(x:y:)` modifier? ... But also, this particular mapping is much more complicated, and Stitch only ever relies on the SwiftUI `.offset(width:height:)` modifier.
//        case .position:
//            return try buildMultifieldModifier(.position)
//            
//        // Stitch's LayerInputPort.offsetInGroup *always* becomes SwiftUI .offset modifier
//        case .offsetInGroup:
//            return try buildMultifieldModifier(.offset)
//            
//        case .size:
//            return try buildMultifieldModifier(.frame)
//        
//        // TODO: JUNE 23: .fill for Layer.rectangle, Layer.oval etc.; but .foregroundColor for Layer.text
//        case .color:
//            switch layer {
//            case .text, .textField:
//                return .modifier(try buildSingleFieldUnlabeledModifier(.foregroundColor))
//            default: // case .rectangle, .oval:
//                return .modifier(try buildSingleFieldUnlabeledModifier(.fill))
//            }
//
//        case .rotationX, .rotationY, .rotationZ:
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//            // MORE COMPLICATED
//            // return .modifier(buildModifier(.rotation3DEffect, nil))
//            
//        case .scale:                       return .modifier(try buildSingleFieldUnlabeledModifier(.scaleEffect))
//        case .opacity:                     return .modifier(try buildSingleFieldUnlabeledModifier(.opacity))
//        case .zIndex:                      return .modifier(try buildSingleFieldUnlabeledModifier(.zIndex))
//        case .blur, .blurRadius:           return .modifier(try buildSingleFieldUnlabeledModifier(.blur))
//        case .blendMode:                   return .modifier(try buildSingleFieldUnlabeledModifier(.blendMode))
//        case .brightness:                  return .modifier(try buildSingleFieldUnlabeledModifier(.brightness))
//        case .colorInvert:                 return .modifier(try buildSingleFieldUnlabeledModifier(.colorInvert))
//        case .contrast:                    return .modifier(try buildSingleFieldUnlabeledModifier(.contrast))
//        case .hueRotation:                 return .modifier(try buildSingleFieldUnlabeledModifier(.hueRotation))
//        case .saturation:                  return .modifier(try buildSingleFieldUnlabeledModifier(.saturation))
//        case .enabled:                     return .modifier(try buildSingleFieldUnlabeledModifier(.disabled))
//        case .backgroundColor:             return .modifier(try buildSingleFieldUnlabeledModifier(.background))
//        case .isClipped, .clipped:         return .modifier(try buildSingleFieldUnlabeledModifier(.clipped))
//        case .padding:                     return .modifier(try buildSingleFieldUnlabeledModifier(.padding))
//        case .cornerRadius:                return .modifier(try buildSingleFieldUnlabeledModifier(.cornerRadius))
//        case .fontSize, .textFont:         return .modifier(try buildSingleFieldUnlabeledModifier(.font))
//        case .textAlignment:               return .modifier(try buildSingleFieldUnlabeledModifier(.multilineTextAlignment))
//        case .textDecoration:              return .modifier(try buildSingleFieldUnlabeledModifier(.underline))
////        case .keyboardType:                return .modifier(try buildSingleFieldUnlabeledModifier(.keyboardType))
////        case .isSpellCheckEnabled:         return .modifier(try buildSingleFieldUnlabeledModifier(.disableAutocorrection))
//
//        
//        // TODO: JUNE 23: complicatd: size, minSize, maxSize are actually a combination of arguments to the SwiftUI .frame view modifier
//        case .minSize, .maxSize:           return .modifier(try buildSingleFieldUnlabeledModifier(.frame))
//                    
//        // TODO: JUNE 23: complicated; all of these correspond to different arguments *on the same SwiftUI .shadow view modifier*
//        case .shadowColor, .shadowOpacity, .shadowRadius, .shadowOffset:
//            // return ".shadow"
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//                    
//        // TODO: JUNE 23: complicated: can be constructor-arg to a stack OR Spacers within a ForEach
//        case .spacing:
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//            // return ".padding"
//        
//        // TODO: JUNE 23: complicated: the LayerInputPort.masks is actually just a boolean that determines whether we'll mask or not; the SwiftUI x.masks(y) view modifier is more-so determined by layer positioning
//        case .masks:
//            // this is just a boolean, actually?
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//        
//        // TODO: JUNE 23: complicated: lots and lots of business logic here
//        case .isPinned, .pinTo, .pinAnchor, .pinOffset:
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//            
//            // What is this for? It's the 3D Model?
//        case .isAnimating:
//            // return ".animation"
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//        case .fitStyle:
//            // return ".aspectRatio"
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//                        
//            // ── No SwiftUI analogue ────────────────────────────────────
//            // Explicitly unsupported ports (no SwiftUI equivalent)
//        case .lineColor,
//                .lineWidth,
//                .pivot,
//            
//            // layer group
//                .layerGroupAlignment,
//            
//            // hit area
//                .setupMode,
//            
//            // camera
//                .cameraDirection,
//                .isCameraEnabled,
//            
//            // 3D
//                .model3D,
//                .isShadowsEnabled,
//                .transform3D,
//                .anchorEntity,
//                .isEntityAnimating,
//                .translation3DEnabled,
//                .rotation3DEnabled,
//                .scale3DEnabled,
//                .size3D,
//                .radius3D,
//                .height3D,
//                .isMetallic,
//            
//            // shapes and their strokes
//                .shape,
//                .strokePosition,
//                .strokeWidth,
//                .strokeColor,
//                .strokeStart,
//                .strokeEnd,
//                .strokeLineCap,
//                .strokeLineJoin,
//                .coordinateSystem,
//            
//            // canvas sketch
//                .canvasLineColor,
//                .canvasLineWidth,
//                
//            // text
//                .verticalAlignment,
//            
//            // text field
//                .placeholderText,
////                .beginEditing,
////                .endEditing,
////                .setText,
////                .textToSet,
////                .isSecureEntry,
//            
//            // media
//                .image,
//                .video,
//                .videoURL,
//                .volume,
//            
//            // preview view
//                .progressIndicatorStyle,
//                .progress,
//            
//            // map
//                .mapType,
//                .mapLatLong,
//                .mapSpan,
//            
//            // toggle-switch
//                .isSwitchToggled,
//            
//            // gradients
//                .startColor,
//                .endColor,
//                .startAnchor,
//                .endAnchor,
//                .centerAnchor,
//                .startAngle,
//                .endAngle,
//                .startRadius,
//                .endRadius,
//                
//                
//            // Have SwiftUI grid equivalents? Arguments for the creation of the LazyVGrid ?
//                .spacingBetweenGridColumns,
//                .spacingBetweenGridRows,
//                .itemAlignmentWithinGridCell,
//            
//            // sizing
//                .sizingScenario,
//                .widthAxis,
//                .heightAxis,
//                .contentMode,
//                
//            // for children of a layer group
//                .layerPadding,
//                .layerMargin,
//            
//            // material
//                .materialThickness,
//            
//            // ??
//                .deviceAppearance,
//            
//            // layer group scrolling
//                .scrollContentSize,
//                .isScrollAuto,
//                
//                .scrollJumpToXStyle,
//                .scrollJumpToX,
//                .scrollJumpToXLocation,
//
//                .scrollJumpToYStyle,
//                .scrollJumpToY,
//                .scrollJumpToYLocation:
//            
//            throw SwiftUISyntaxError.unsupportedSyntaxFromLayerInput(self)
//        }
//    }
}


extension CurrentStep.PortValue {
    
    var isMultifield: Bool {
        guard let migratedValue = try? self.migrate() else {
            fatalErrorIfDebug()
            return false
        }
        return migratedValue.unpackValues().isDefined
    }
    
    // from the port value ALONE, will you know the modifier's arguments ?
    // CGSize is an easy one -- but what about abstractly ?
    
    // really, this is only needed for multifield PortValues -- all other cases can basically use strings ?
    
    //
//    func deriveSyntaxViewModifierForMultifieldPortValue(_ name: SyntaxViewModifierName) -> SyntaxViewModifier? {
//        
//        let inputValue = self
//        
//        // TODO: isn't there some typed way to retrieve a
//        guard inputValue.isMultifield else {
//            fatalErrorIfDebug("Called incorrectly")
//            return nil
//        }
//                        
//        switch inputValue {
//            
//        case .position(let x):
//            return SyntaxViewModifier(
//                name: name,
//                arguments: x.deriveSyntaxViewModifierArguments()
//            )
//
//        case .size(let x):
//            return SyntaxViewModifier(
//                // PortValue.size could be for either SwiftUI .frame modifier or .offset modifier, hence why we have to pass in the modifier name we already derived
//                name: name,
//                arguments: x.deriveSyntaxViewModifierArguments()
//            )
//            
//        case .point3D, .point4D, .padding, .transform:
//            return nil
//            
//        default:
//            fatalErrorIfDebug("Called incorrectly, should not have ")
//            return nil
//            
//            
//        } // switch value
//    }
}

//extension CGPoint {
//    func deriveSyntaxViewModifierArguments() -> [SyntaxViewModifierArgument] {
//        let x = CurrentStep.PortValue.number(self.x)
//        let y = CurrentStep.PortValue.number(self.y)
//        return [
//            SyntaxViewModifierArgument(
//                label: .x,
//                value: .simple(SyntaxViewModifierArgumentData(
//                    value: self.x.description,
//                    syntaxKind: x.asSwiftSyntaxKind
//                ))
//            ),
//            SyntaxViewModifierArgument(
//                label: .y,
//                value: .simple(SyntaxViewModifierArgumentData(
//                    value: self.y.description,
//                    syntaxKind: y.asSwiftSyntaxKind
//                ))
//            )
//        ]
//    }
//}

//extension CurrentStitchAIPortValue.LayerSize {
//    func deriveSyntaxViewModifierArguments() -> [SyntaxViewModifierArgument] {
//        let width = CurrentStep.PortValue.layerDimension(self.width)
//        let height = CurrentStep.PortValue.layerDimension(self.height)
//        
//        // TODO: may need to use different labels, e.g. `.minWidth` ?
//        return [
//            SyntaxViewModifierArgument(
//                label: .width,
//                value: .simple(SyntaxViewModifierArgumentData(
//                    value: self.width.description,
//                    syntaxKind: width.asSwiftSyntaxKind
//                ))
//            ),
//            SyntaxViewModifierArgument(
//                label: .height,
//                value: .simple(SyntaxViewModifierArgumentData(
//                    value: self.height.description,
//                    syntaxKind: height.asSwiftSyntaxKind
//                ))
//            )
//        ]
//    }
//}
