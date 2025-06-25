//
//  deriveViewModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation


extension LayerInputPort {

    /// A typed equivalent of `swiftUIModifier`.
    /// Returns `nil` when there is no direct SwiftUI modifier match.
    var toSwiftUIViewModifier: SyntaxViewModifierName? {
        switch self {
        // ── Required geometry & layout ──────────────────────────────
        case .position:                    return .custom("position")
        case .size:                        return .frame
        case .scale:                       return .scaleEffect
        case .anchoring:                   return nil
        case .opacity:                     return .opacity
        case .zIndex:                      return .zIndex

        // ── Common appearance modifiers ─────────────────────────────
        // case .masks:                       return .custom("mask")
        case .color:                       return .fill          // or .foregroundColor
        case .rotationX, .rotationY,
                .rotationZ:                   return .rotation3DEffect
        case .blur, .blurRadius:           return .blur
        case .blendMode:                   return .blendMode
        case .brightness:                  return .brightness
        case .colorInvert:                 return .colorInvert
        case .contrast:                    return .contrast
        case .hueRotation:                 return .hueRotation
        case .saturation:                  return .saturation
        case .enabled:                     return .disabled
        case .backgroundColor:             return .background
        case .isClipped, .clipped:         return .clipped
        case .padding:                     return .padding
        case .cornerRadius:                return .cornerRadius
        case .fontSize, .textFont:         return .font
        case .textAlignment:               return .multilineTextAlignment
        case .textDecoration:              return .underline
        case .keyboardType:                return .keyboardType
        case .isSpellCheckEnabled:         return .disableAutocorrection

        case .minSize, .maxSize:           return .frame

        // What is this for? It's the 3D Model?
        case .isAnimating:                 return nil // return ".animation"
        case .fitStyle:                    return nil // return ".aspectRatio"
        case .shadowColor, .shadowOpacity, .shadowRadius, .shadowOffset:
            return nil // return ".shadow"
        // Can be either `spacing:` in e.g. an HStack or the use of Spacers() within a ForEach
        case .spacing:                     return nil // return ".padding"
            
        case .masks: return nil
            
        // ── No SwiftUI analogue ────────────────────────────────────
            // Explicitly unsupported ports (no SwiftUI equivalent)
            case .lineColor,
                 .lineWidth,
                 .pivot,
                 .orientation,
                 .setupMode,
                 .cameraDirection,
                 .isCameraEnabled,
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
                 .shape,
                 .strokePosition,
                 .strokeWidth,
                 .strokeColor,
                 .strokeStart,
                 .strokeEnd,
                 .strokeLineCap,
                 .strokeLineJoin,
                 .coordinateSystem,
                 .isMetallic,
                 .canvasLineColor,
                 .canvasLineWidth,
                 .text,
                 .placeholderText,
                 .verticalAlignment,
                 .beginEditing,
                 .endEditing,
                 .setText,
                 .textToSet,
                 .isSecureEntry,
                 .image,
                 .video,
                 .model3D,
                 .progressIndicatorStyle,
                 .progress,
                 .mapType,
                 .mapLatLong,
                 .mapSpan,
                 .isSwitchToggled,
                 .startColor,
                 .endColor,
                 .startAnchor,
                 .endAnchor,
                 .centerAnchor,
                 .startAngle,
                 .endAngle,
                 .startRadius,
                 .endRadius,
                 .sfSymbol,
                 .videoURL,
                 .volume,
                 .spacingBetweenGridColumns,
                 .spacingBetweenGridRows,
                 .itemAlignmentWithinGridCell,
                 .widthAxis,
                 .heightAxis,
                 .contentMode,
                 .sizingScenario,
                 .isPinned,
                 .pinTo,
                 .pinAnchor,
                 .pinOffset,
                 .layerPadding,
                 .layerMargin,
                 .offsetInGroup,
                 .layerGroupAlignment,
                 .materialThickness,
                 .deviceAppearance,
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
            
                return nil
        }
    }
}
