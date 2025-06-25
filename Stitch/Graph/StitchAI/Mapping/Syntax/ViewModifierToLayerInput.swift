//
//  ViewModifierToLayerInputMapping.swift
//  Stitch
//
//  Created on 6/23/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI


// TODO: combine these functions, so that you can make sure you capture or handle ALL `LayerInputPort` cases? i.e. what is important here

struct EdgeOrigin: Equatable, Codable, Hashable {
    let id: NodeId
    let port: Int
}

enum StitchValueOrEdge: Equatable {
    // a manually-set, always-scalar value
    case value(PortValue)
    
    // an incoming edge
    case edge(NodeId, Int) // `from node id + from port`
    
    var asSwiftUILiteralOrVariable: String {
        switch self {
        case .value(let x):
            return x.asSwiftUILiteral
        case .edge(let x, let y):
            // TODO: JUNE 24: probably will use edge.origin's NodeId and Int to ... what? look up a proper variable name? ... Can see how Elliot does it?
            return "x"
        }
    }
    
    var asSwiftSyntaxKind: ArgumentKind {
        switch self {
        case .value:
            // TODO: JUNE 24: Do you need all these different individual syntax-literal types? ... if so, then should map on
            return ArgumentKind.literal(.string)
        case .edge(let x, let y):
            // TODO: JUNE 24: do we always want to treat an incoming edge as a variable ? ... a variable is just an evaluated expression ?
            return ArgumentKind.variable(.identifier) // `x`
        }
    }
}

extension PortValue {
    // TODO: JUNE 24: should return a Codable ? ... How do you map between Swift/SwiftUI types and Stitch's PortValue types ? ... see note in `LayerInputPort.toSwiftUI`
    var asSwiftUILiteral: String {
        switch self {
        case .number(let x):
            return x.description
        case .string(let x):
            return x.string
        default:
            return "IMPLEMENT ME: \(self.display)"
        }
    }
}

// TODO: JUNE 24: how to handle loops? ... note: this is not used anywhere yet
extension LayerInputPort {
    func toSwiftUI(_ viewNode: ViewNode,
                   port: StitchValueOrEdge, // loops? should pass in `value` ?
                   layer: Layer) -> FromLayerInputToSwiftUI {
        
        // TODO: JUNE 24: ASSUMES SINGLE-PARAMETER PORT VALUE, i.e. .opacity but not .size
        let buildModifier = { (kind: ModifierKind) -> Modifier in
            Modifier(kind: kind,
                     arguments: [
                        Argument(label: nil, // assumes unlabeled
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
            return .modifier(Modifier(kind: .position,
                                      arguments: [
                                        // NOT CORRECT?: discrepancy between
                                        Argument(label: "x",
                                                 // NEED TO UNPACK THE PORT VALUE ?
                                                 value: port.asSwiftUILiteralOrVariable,
                                                 syntaxKind: port.asSwiftSyntaxKind),
                                        Argument(label: "y",
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

extension ConstructorArgument {
    func toLayerInput(_ layer: Layer) -> LayerInputPort? {
        switch self.label {
            
        case .systemName:
            return .sfSymbol
            
        // TODO: JUNE 24: *many* SwiftUU
        case .unlabeled:
            switch layer {
            case .text, .textField:
                return .text
            default:
                return nil
            }
            
            
        case .unsupported:
            return nil
        }
    }
}

extension ModifierKind {
    func toLayerInput(_ layer: Layer) -> LayerInputPort? {
        switch (self, layer) {
            // Universal modifiers (same for every layer)
        case (.scaleEffect, _):
            return .scale
        case (.opacity, _):
            return .opacity
        case (.offset, _):
            return .position
        case (.rotationEffect, _):
            return .rotationZ
        case (.rotation3DEffect, _):
            // Depending on the axis specified in the arguments
            // This would need argument extraction to determine X, Y, or Z
            return .rotationZ // Default to Z rotation
        case (.blur, _):
            return .blurRadius
        case (.blendMode, _):
            return .blendMode
        case (.brightness, _):
            return .brightness
        case (.colorInvert, _):
            return .colorInvert
        case (.contrast, _):
            return .contrast
        case (.hueRotation, _):
            return .hueRotation
        case (.saturation, _):
            return .saturation
        
        case (.fill, _): // fill is always color
            return .color
            
            //    case (.font, .text):
            //        return .font
            
            //    case (.fontWeight, _):
            //        //            return .fontWeight
            //        return nil
            
            //    case (.lineSpacing, _):
            //        return nil // return .lineSpacing
            
        case (.cornerRadius, _):
            return .cornerRadius
            
            //    case (.shadow, _):
            //        // Shadow would need to be broken down into multiple inputs:
            //        // .shadowColor, .shadowRadius, .shadowOffset, .shadowOpacity
            //        return .shadowRadius
            
        case (.position, _): return .position
            
        // TODO: JUNE 23: .frame modifier is actually several different LayerInputPort cases: .size, .minSize, .maxSize
        case (.frame, _):
            return .size
            
        case (.padding, _):
            return .padding // vs .layerPadding ?!
            
        case (.zIndex, _):
            return .zIndex
        
        case (.foregroundColor, let kind) where kind != .text && kind != .textField:
            return .color

        case (.foregroundColor, _):
            return .color

            //        case (.backgroundColor, _):
            //            return .color
                        
        case (.disabled, _): return nil
        case (.background, _): return nil
        case (.font, _): return nil
        case (.multilineTextAlignment, _): return nil
        case (.underline, _): return nil
        case (.keyboardType, _): return .keyboardType
        case (.disableAutocorrection, _): return nil
        case (.clipped, _): return .clipped // return .isClipped
        case (.custom(_), _): return nil
        }
    }
}

/// Maps ModifierKind cases to LayerInputPort cases based on the Layer type
/// Returns the appropriate LayerInputPort for a given ModifierKind and Layer combination
/// - Parameters:
///   - modifier: The ModifierKind to map
///   - layer: The Layer type to map for
/// - Returns: The corresponding LayerInputPort if a mapping exists, nil otherwise
func mapModifierToLayerInput(modifier: ModifierKind,
                             layer: Layer) -> LayerInputPort? {
    
    switch (modifier, layer) {
        // Universal modifiers (same for every layer)
    case (.scaleEffect, _):
        return .scale
    case (.opacity, _):
        return .opacity
    case (.offset, _):
        return .position
    case (.rotationEffect, _):
        return .rotationZ
    case (.rotation3DEffect, _):
        // Depending on the axis specified in the arguments
        // This would need argument extraction to determine X, Y, or Z
        return .rotationZ // Default to Z rotation
    case (.blur, _):
        return .blurRadius
    case (.blendMode, _):
        return .blendMode
    case (.brightness, _):
        return .brightness
    case (.colorInvert, _):
        return .colorInvert
    case (.contrast, _):
        return .contrast
    case (.hueRotation, _):
        return .hueRotation
    case (.saturation, _):
        return .saturation
        
        // Layer-specific modifiers
    case (.foregroundColor, .text):
        return .color
        
    case (.foregroundColor, let kind) where kind != .text:
        return .color
        
    case (.fill, _): // fill is always color
        return .color
        
        //    case (.font, .text):
        //        return .font
        
        //    case (.fontWeight, _):
        //        //            return .fontWeight
        //        return nil
        
        //    case (.lineSpacing, _):
        //        return nil // return .lineSpacing
        
    case (.cornerRadius, _):
        return .cornerRadius
        
        //    case (.shadow, _):
        //        // Shadow would need to be broken down into multiple inputs:
        //        // .shadowColor, .shadowRadius, .shadowOffset, .shadowOpacity
        //        return .shadowRadius
        
    default:
        return nil
    }
}
