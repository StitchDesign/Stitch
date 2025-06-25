//
//  deriveSyntaxFromLayerInput.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation


// TODO: JUNE 24: how to handle loops? ... note: this is not used anywhere yet
extension LayerInputPort {
    func toSwiftUISyntax(port: StitchValueOrEdge, // loops? should pass in `value` ?
                         layer: Layer) -> FromLayerInputToSyntax {
        
        // TODO: JUNE 24: ASSUMES SINGLE-PARAMETER PORT VALUE, i.e. can handle .opacity but not .frame
        let buildModifier = { (kind: SyntaxViewModifierName) -> SyntaxViewModifier in
            SyntaxViewModifier(kind: kind,
                     arguments: [
                        SyntaxViewModifierArgument(label: nil, // assumes unlabeled
                                 value: port.asSwiftUILiteralOrVariable,
                                 syntaxKind: port.asSwiftSyntaxKind)
                     ])
        }
        
        // We switch on `self` because we want to cover all LayerInput cases
        switch self {
            
        case .anchoring:
            // TODO: JUNE 24: handle `functions`
            return .function(.anchoring)
            
        case .text:
            // return .constructorArgument(.text(.noLabel))
            return .constructorArgument(.init(
                
                label: .unlabeled,
                
                // TODO: JUNE 24: tricky: how to go from a VPL literal or edge to SwiftUI code contained with a
                // `value` is either a literal (manually-set value) or an expression (incoming edge);
                // if manually-set PortValue, then will be a Swift type literal (e.g. `5`, `"love"`, `CGSize(width: 50, height: 100)`
                // if incoming-edge, then will be a Swift declared-constant
                value: port.asSwiftUILiteralOrVariable,
                
                syntaxKind: port.asSwiftSyntaxKind))
            
            
        case .sfSymbol:
            return .constructorArgument(.init(
                label: .systemName,
                value: port.asSwiftUILiteralOrVariable,
                syntaxKind: port.asSwiftSyntaxKind))
            
            
            // TODO: JUNE 24: how to handle PortValue.position(CGPoint) as a SwiftUI `.position(x:y:)` modifier? ... But also, this particular mapping is much more complicated, and Stitch only ever relies on the SwiftUI `.offset(width:height:)` modifier.
        case .position:
            // return .modifier(.position)
            return .modifier(SyntaxViewModifier(kind: .position,
                                      arguments: [
                                        // NOT CORRECT?: discrepancy between
                                        SyntaxViewModifierArgument(label: "x",
                                                 // NEED TO UNPACK THE PORT VALUE ?
                                                 value: port.asSwiftUILiteralOrVariable,
                                                 syntaxKind: port.asSwiftSyntaxKind),
                                        SyntaxViewModifierArgument(label: "y",
                                                 value: port.asSwiftUILiteralOrVariable,
                                                 syntaxKind: port.asSwiftSyntaxKind)
                                      ]))
            

            
        
        // TODO: JUNE 23: .fill for Layer.rectangle, Layer.oval etc.; but .foregroundColor for Layer.text
        case .color:
            switch layer {
            case .text, .textField:
                return .modifier(buildModifier(.foregroundColor))
            default: // case .rectangle, .oval:
                return .modifier(buildModifier(.fill))
            }
            
        case .rotationX, .rotationY, .rotationZ:
            return .unsupported // MORE COMPLICATED
            // return .modifier(buildModifier(.rotation3DEffect, nil))
            
        case .scale:                       return .modifier(buildModifier(.scaleEffect))
        case .opacity:                     return .modifier(buildModifier(.opacity))
        case .zIndex:                      return .modifier(buildModifier(.zIndex))
        case .blur, .blurRadius:           return .modifier(buildModifier(.blur))
        case .blendMode:                   return .modifier(buildModifier(.blendMode))
        case .brightness:                  return .modifier(buildModifier(.brightness))
        case .colorInvert:                 return .modifier(buildModifier(.colorInvert))
        case .contrast:                    return .modifier(buildModifier(.contrast))
        case .hueRotation:                 return .modifier(buildModifier(.hueRotation))
        case .saturation:                  return .modifier(buildModifier(.saturation))
        case .enabled:                     return .modifier(buildModifier(.disabled))
        case .backgroundColor:             return .modifier(buildModifier(.background))
        case .isClipped, .clipped:         return .modifier(buildModifier(.clipped))
        case .padding:                     return .modifier(buildModifier(.padding))
        case .cornerRadius:                return .modifier(buildModifier(.cornerRadius))
        case .fontSize, .textFont:         return .modifier(buildModifier(.font))
        case .textAlignment:               return .modifier(buildModifier(.multilineTextAlignment))
        case .textDecoration:              return .modifier(buildModifier(.underline))
        case .keyboardType:                return .modifier(buildModifier(.keyboardType))
        case .isSpellCheckEnabled:         return .modifier(buildModifier(.disableAutocorrection))

        
        // TODO: JUNE 23: complicatd: size, minSize, maxSize are actually a combination of arguments to the SwiftUI .frame view modifier
        case .size:                        return .modifier(buildModifier(.frame))
        case .minSize, .maxSize:           return .modifier(buildModifier(.frame))
            
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
