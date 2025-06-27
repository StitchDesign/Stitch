//
//  deriveSyntaxFromLayerInput.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation


extension LayerInputPort {
    
    func toSwiftUISyntax(valueOrEdge: StitchValueOrEdge, // loops? should pass in `value` ?
                         layer: Layer) -> FromLayerInputToSyntax {
        
        guard let value: PortValue = valueOrEdge.getValue else {
            fatalErrorIfDebug("Incoming edges not yet handled")
            return .unsupported
        }
        
        // TODO: JUNE 24: ASSUMES SINGLE-PARAMETER PORT VALUE, i.e. can handle .opacity but not .frame
        let buildSingleFieldUnlabeledModifier = { (name: SyntaxViewModifierName) -> SyntaxViewModifier in
            SyntaxViewModifier(name: name,
                     arguments: [
                        SyntaxViewModifierArgument(label: .noLabel, // assumes unlabeled
                                 value: valueOrEdge.asSwiftUILiteralOrVariable,
                                 syntaxKind: valueOrEdge.asSwiftSyntaxKind)
                     ])
        }
        
        let buildMultifieldModifier = { (name: SyntaxViewModifierName) -> FromLayerInputToSyntax in
            if let modifier = value.deriveSyntaxViewModifierForMultifieldPortValue(name) {
                return .modifier(modifier)
            } else {
                fatalErrorIfDebug("Failed to handle layer input \(self) with value \(value) for modifier \(name)")
                return .unsupported
            }
        }
        
        // We switch on `self` because we want to cover all LayerInput cases
        switch self {
            
        case .anchoring:
            // TODO: JUNE 24: handle `functions`
            return .function(.anchoring)
            
        case .text:
            // return .constructorArgument(.text(.noLabel))
            return .constructorArgument(.init(
                
                label: .noLabel,
                
                // TODO: JUNE 24: tricky: how to go from a VPL literal or edge to SwiftUI code contained with a
                // `value` is either a literal (manually-set value) or an expression (incoming edge);
                // if manually-set PortValue, then will be a Swift type literal (e.g. `5`, `"love"`, `CGSize(width: 50, height: 100)`
                // if incoming-edge, then will be a Swift declared-constant
                value: valueOrEdge.asSwiftUILiteralOrVariable,
                
                syntaxKind: valueOrEdge.asSwiftSyntaxKind))
            
            
        case .sfSymbol:
            return .constructorArgument(.init(
                label: .systemName,
                value: valueOrEdge.asSwiftUILiteralOrVariable,
                syntaxKind: valueOrEdge.asSwiftSyntaxKind))
            
            
            // TODO: JUNE 24: how to handle PortValue.position(CGPoint) as a SwiftUI `.position(x:y:)` modifier? ... But also, this particular mapping is much more complicated, and Stitch only ever relies on the SwiftUI `.offset(width:height:)` modifier.
        case .position:
            return buildMultifieldModifier(.position)
            
        // Stitch's LayerInputPort.offsetInGroup *always* becomes SwiftUI .offset modifier
        case .offsetInGroup:
            return buildMultifieldModifier(.offset)
            
        case .size:
            return buildMultifieldModifier(.frame)
        
        // TODO: JUNE 23: .fill for Layer.rectangle, Layer.oval etc.; but .foregroundColor for Layer.text
        case .color:
            switch layer {
            case .text, .textField:
                return .modifier(buildSingleFieldUnlabeledModifier(.foregroundColor))
            default: // case .rectangle, .oval:
                return .modifier(buildSingleFieldUnlabeledModifier(.fill))
            }
            
        case .rotationX, .rotationY, .rotationZ:
            return .unsupported // MORE COMPLICATED
            // return .modifier(buildModifier(.rotation3DEffect, nil))
            
        case .scale:                       return .modifier(buildSingleFieldUnlabeledModifier(.scaleEffect))
        case .opacity:                     return .modifier(buildSingleFieldUnlabeledModifier(.opacity))
        case .zIndex:                      return .modifier(buildSingleFieldUnlabeledModifier(.zIndex))
        case .blur, .blurRadius:           return .modifier(buildSingleFieldUnlabeledModifier(.blur))
        case .blendMode:                   return .modifier(buildSingleFieldUnlabeledModifier(.blendMode))
        case .brightness:                  return .modifier(buildSingleFieldUnlabeledModifier(.brightness))
        case .colorInvert:                 return .modifier(buildSingleFieldUnlabeledModifier(.colorInvert))
        case .contrast:                    return .modifier(buildSingleFieldUnlabeledModifier(.contrast))
        case .hueRotation:                 return .modifier(buildSingleFieldUnlabeledModifier(.hueRotation))
        case .saturation:                  return .modifier(buildSingleFieldUnlabeledModifier(.saturation))
        case .enabled:                     return .modifier(buildSingleFieldUnlabeledModifier(.disabled))
        case .backgroundColor:             return .modifier(buildSingleFieldUnlabeledModifier(.background))
        case .isClipped, .clipped:         return .modifier(buildSingleFieldUnlabeledModifier(.clipped))
        case .padding:                     return .modifier(buildSingleFieldUnlabeledModifier(.padding))
        case .cornerRadius:                return .modifier(buildSingleFieldUnlabeledModifier(.cornerRadius))
        case .fontSize, .textFont:         return .modifier(buildSingleFieldUnlabeledModifier(.font))
        case .textAlignment:               return .modifier(buildSingleFieldUnlabeledModifier(.multilineTextAlignment))
        case .textDecoration:              return .modifier(buildSingleFieldUnlabeledModifier(.underline))
        case .keyboardType:                return .modifier(buildSingleFieldUnlabeledModifier(.keyboardType))
        case .isSpellCheckEnabled:         return .modifier(buildSingleFieldUnlabeledModifier(.disableAutocorrection))

        
        // TODO: JUNE 23: complicatd: size, minSize, maxSize are actually a combination of arguments to the SwiftUI .frame view modifier
        case .minSize, .maxSize:           return .modifier(buildSingleFieldUnlabeledModifier(.frame))
            
        // TODO: JUNE 23: complicated; all of these correspond to different arguments *on the same SwiftUI .shadow view modifier*
        case .shadowColor, .shadowOpacity, .shadowRadius, .shadowOffset:
            return .unsupported // return ".shadow"
                    
        // TODO: JUNE 23: complicated: can be constructor-arg to a stack OR Spacers within a ForEach
        case .spacing:
            return .unsupported // return ".padding"
        
        // TODO: JUNE 23: complicated: the LayerInputPort.masks is actually just a boolean that determines whether we'll mask or not; the SwiftUI x.masks(y) view modifier is more-so determined by layer positioning
        case .masks:
            return .unsupported // this is just a boolean, actually?
        
        // TODO: JUNE 23: complicated: lots and lots of business logic here
        case .isPinned, .pinTo, .pinAnchor, .pinOffset:
            return .unsupported
            
            // What is this for? It's the 3D Model?
        case .isAnimating:
            return .unsupported // return ".animation"
        case .fitStyle:
            return .unsupported // return ".aspectRatio"
            
            // ── No SwiftUI analogue ────────────────────────────────────
            // Explicitly unsupported ports (no SwiftUI equivalent)
        case .lineColor,
                .lineWidth,
                .pivot,
            
            // layer group
                .orientation,
                .layerGroupAlignment,
            
            // hit area
                .setupMode,
            
            // camera
                .cameraDirection,
                .isCameraEnabled,
            
            // 3D
                .model3D,
                .isShadowsEnabled,
                .transform3D,
                .anchorEntity,
                .isEntityAnimating,
                .translation3DEnabled,
                .rotation3DEnabled,
                .scale3DEnabled,
                .size3D,
                .radius3D,
                .height3D,
                .isMetallic,
            
            // shapes and their strokes
                .shape,
                .strokePosition,
                .strokeWidth,
                .strokeColor,
                .strokeStart,
                .strokeEnd,
                .strokeLineCap,
                .strokeLineJoin,
                .coordinateSystem,
            
            // canvas sketch
                .canvasLineColor,
                .canvasLineWidth,
                
            // text
                .verticalAlignment,
            
            // text field
                .placeholderText,
                .beginEditing,
                .endEditing,
                .setText,
                .textToSet,
                .isSecureEntry,
            
            // media
                .image,
                .video,
                .videoURL,
                .volume,
            
            // preview view
                .progressIndicatorStyle,
                .progress,
            
            // map
                .mapType,
                .mapLatLong,
                .mapSpan,
            
            // toggle-switch
                .isSwitchToggled,
            
            // gradients
                .startColor,
                .endColor,
                .startAnchor,
                .endAnchor,
                .centerAnchor,
                .startAngle,
                .endAngle,
                .startRadius,
                .endRadius,
                
                
            // Have SwiftUI grid equivalents? Arguments for the creation of the LazyVGrid ?
                .spacingBetweenGridColumns,
                .spacingBetweenGridRows,
                .itemAlignmentWithinGridCell,
            
            // sizing
                .sizingScenario,
                .widthAxis,
                .heightAxis,
                .contentMode,
                
            // for children of a layer group
                .layerPadding,
                .layerMargin,
                .offsetInGroup,
            
            // material
                .materialThickness,
            
            // ??
                .deviceAppearance,
            
            // layer group scrolling
                .scrollContentSize,
                .isScrollAuto,
                .scrollXEnabled,
                .scrollJumpToXStyle,
                .scrollJumpToX,
                .scrollJumpToXLocation,
                .scrollYEnabled,
                .scrollJumpToYStyle,
                .scrollJumpToY,
                .scrollJumpToYLocation:
            
            return .unsupported
        }
    }
}


extension PortValue {
    
    var isMultifield: Bool {
        self.unpackValues().isDefined
    }
    
    // from the port value ALONE, will you know the modifier's arguments ?
    // CGSize is an easy one -- but what about abstractly ?
    
    // really, this is only needed for multifield PortValues -- all other cases can basically use strings ?
    
    //
    func deriveSyntaxViewModifierForMultifieldPortValue(_ name: SyntaxViewModifierName) -> SyntaxViewModifier? {
        
        let inputValue: PortValue = self
        
        // TODO: isn't there some typed way to retrieve a
        guard inputValue.isMultifield else {
            fatalErrorIfDebug("Called incorrectly")
            return nil
        }
                        
        switch inputValue {
            
        case .position(let x):
            return SyntaxViewModifier(
                name: name,
                arguments: x.deriveSyntaxViewModifierArguments()
            )

        case .size(let x):
            return SyntaxViewModifier(
                // PortValue.size could be for either SwiftUI .frame modifier or .offset modifier, hence why we have to pass in the modifier name we already derived
                name: name,
                arguments: x.deriveSyntaxViewModifierArguments()
            )
            
        case .point3D, .point4D, .padding, .transform:
            return nil
            
        default:
            fatalErrorIfDebug("Called incorrectly, should not have ")
            return nil
            
            
        } // switch value
    }
}

extension CGPoint {
    func deriveSyntaxViewModifierArguments() -> [SyntaxViewModifierArgument] {
        let x = PortValue.number(self.x)
        let y = PortValue.number(self.y)
        return [
            SyntaxViewModifierArgument(label: .x,
                                       value: x.display,
                                       syntaxKind: x.asSwiftSyntaxKind),
            SyntaxViewModifierArgument(label: .y,
                                       value: y.display,
                                       syntaxKind: y.asSwiftSyntaxKind)
        ]
    }
}

extension LayerSize {
    func deriveSyntaxViewModifierArguments() -> [SyntaxViewModifierArgument] {
        let width = PortValue.layerDimension(self.width)
        let height = PortValue.layerDimension(self.height)
        
        // TODO: may need to use different labels, e.g. `.minWidth` ?
        return [
            SyntaxViewModifierArgument(label: .width,
                                       value: width.display,
                                       syntaxKind: width.asSwiftSyntaxKind),
            SyntaxViewModifierArgument(label: .height,
                                       value: height.display,
                                       syntaxKind: height.asSwiftSyntaxKind)
        ]
    }
}
