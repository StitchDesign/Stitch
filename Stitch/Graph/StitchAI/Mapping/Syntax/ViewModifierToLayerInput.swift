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

// it's probably more important to make sure we map all existing LayerInputs to SOME kind of ViewNode constructor-arg(s) or modifier(s)
// Adapted from `toSwiftUIViewModifier`
extension LayerInputPort {
    func toSwiftUI(_ viewNode: ViewNode, layer: Layer) -> FromLayerInputToSwiftUI {
        
        // We switch on `self` because we want to cover all LayerInput cases
        switch self {
            
        case .text: return .constructorArgument(.text(.noLabel))
            
            // ── Required geometry & layout ──────────────────────────────
        case .position:                    return .modifier(.position)
                    
        case .scale:                       return .modifier(.scaleEffect)
        case .anchoring:                   return .function(.anchoring)
        case .opacity:                     return .modifier(.opacity)
        case .zIndex:                      return .modifier(.zIndex)
            
            // ── Common appearance modifiers ─────────────────────────────
        
        // TODO: JUNE 23: .fill for Layer.rectangle, Layer.oval etc.; but .foregroundColor for Layer.text
        case .color:
            switch layer {
            case .text, .textField:
                return .modifier(.foregroundColor)
            default: // case .rectangle, .oval:
                return .modifier(.fill)
            }
            
        case .rotationX, .rotationY, .rotationZ:
            return .modifier(.rotation3DEffect)
            
        case .blur, .blurRadius:           return .modifier(.blur)
        case .blendMode:                   return .modifier(.blendMode)
        case .brightness:                  return .modifier(.brightness)
        case .colorInvert:                 return .modifier(.colorInvert)
        case .contrast:                    return .modifier(.contrast)
        case .hueRotation:                 return .modifier(.hueRotation)
        case .saturation:                  return .modifier(.saturation)
        case .enabled:                     return .modifier(.disabled)
        case .backgroundColor:             return .modifier(.background)
        case .isClipped, .clipped:         return .modifier(.clipped)
        case .padding:                     return .modifier(.padding)
        case .cornerRadius:                return .modifier(.cornerRadius)
        case .fontSize, .textFont:         return .modifier(.font)
        case .textAlignment:               return .modifier(.multilineTextAlignment)
        case .textDecoration:              return .modifier(.underline)
        case .keyboardType:                return .modifier(.keyboardType)
        case .isSpellCheckEnabled:         return .modifier(.disableAutocorrection)

        case .sfSymbol:                    return .constructorArgument(.image(.systemName))
            
            // TODO: JUNE 23: complicatd: size, minSize, maxSize are actually
        case .size:                        return .modifier(.frame)
        case .minSize, .maxSize:           return .modifier(.frame)
            
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
        case .isAnimating:                 return .unsupported // return ".animation"
        case .fitStyle:                    return .unsupported // return ".aspectRatio"
            
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

extension ConstructorArgumentLabel {
    var toLayerInput: LayerInputPort? {
        switch self {
            
        case .image(let imageConstructorArgument):
            switch imageConstructorArgument {
            case .systemName:
                return .sfSymbol
            }
        
        case .text(let textConstructorArgument):
            switch textConstructorArgument {
            case .noLabel:
                return .text
            }
        
        case .unsupported(let argument):
            return nil
        }
    }
}

extension ModifierKind {
    func toLayerInput(layer: Layer) -> LayerInputPort? {
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
