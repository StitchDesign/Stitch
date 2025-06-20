//
//  LayersMappedToSwiftUIViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/19/25.
//

import SwiftUI
import StitchSchemaKit

import Foundation


struct LayerMappings: Codable {
    let layers: [String: String]
    let inputs: [String: String]
}

@MainActor
func generateLayerMappings() -> LayerMappings {
    let layersDict: [String: String] = Layer.allCases.reduce(into: [:]) { dict, layer in
        if let viewName = layer.swiftUIView {
            dict[layer.defaultDisplayTitle()] = viewName
        }
    }
    let inputsDict: [String: String] = LayerInputPort.allCases.reduce(into: [:]) { dict, port in
        if let modifier = port.swiftUIModifier {
            dict[port.label()] = modifier
        }
    }

    return LayerMappings(layers: layersDict, inputs: inputsDict)
}

@MainActor
func mappingsJSON() throws -> String {
    let mappings = generateLayerMappings()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(mappings)
    guard let jsonString = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "LayerMapping", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "Unable to encode mappings as UTF8 string"
        ])
    }
    return jsonString
}

@MainActor
func printRestrictivelyScopedLayersAndLayerInputsJSON() {
    do {
        let json = try mappingsJSON()
        log("RESTRICTIVELY SCOPED LAYERS AND LAYER INPUTS JSON")
        print(json)
    } catch {
        print("Error generating JSON:", error)
    }

}


// TODO: support more cases
// TODO: support patches

// MARK: Maps Layer -> SwiftUI View

extension Layer {
    // TODO: return the Any.Type instead ?
    var swiftUIView: String? {
        switch self {
        case .text:
            return String(describing: Text.self)
        case .oval:
            return String(describing: Ellipse.self)
        case .rectangle:
            return String(describing: Rectangle.self)
            
        case .image:
            // return String(describing: Image.self)
            return nil
        case .group:
//            return String(describing: Group.self)
            return nil
        case .video:
            return nil // return String(describing: Video.self)
        case .model3D:
//            return String(describing: Model3D.self)
            return nil
        case .realityView:
//            return String(describing: RealityView.self)
            return nil
        case .shape:
//            return String(describing: Shape.self)
            return nil
        case .colorFill:
//            return String(describing: ColorFill.self)
            return nil
        case .hitArea:
//            return String(describing: HitArea.self)
            return nil
        case .canvasSketch:
//            return String(describing: CanvasSketch.self)
            return nil
        case .textField:
            // return String(describing: TextField.self)
            return nil
        case .map:
            // return String(describing: Map.self)
            return nil
        case .progressIndicator:
            // return String(describing: ProgressView.self)
            return nil
        case .switchLayer:
            // return String(describing: SwitchLayer.self)
            return nil
        case .linearGradient:
            // return String(describing: LinearGradient.self)
            return nil
        case .radialGradient:
            // return String(describing: RadialGradient.self)
            return nil
        case .angularGradient:
            // return String(describing: AngularGradient.self)
            return nil
        case .sfSymbol:
            return nil
        case .videoStreaming:
            return nil
        case .material:
            return nil
        case .box:
            return nil
        case .sphere:
            return nil
        case .cylinder:
            return nil
        case .cone:
            return nil
        }
    }
}


// MARK: LayerInputPort -> SwiftUI modifier
// e.g. size -> .frame
// e.g. opacity -> .opacity

extension LayerInputPort {
    @MainActor
    var swiftUIModifier: String? {
        switch self {
        // Required
        case .position:                    return ".position"
        case .size:                        return ".frame"
        case .scale:                       return ".scaleEffect"
        case .anchoring:                   return nil
        case .opacity:                     return ".opacity"
        case .zIndex:                      return ".zIndex"

        // Common view modifiers
        case .masks:                       return nil // return ".mask"
        case .color:                       return ".fill" // return ".foregroundColor"
        case .rotationX, .rotationY:       return nil // return ".rotation3DEffect"
        case .rotationZ:                   return nil // return ".rotation3DEffect"
        case .blur:                        return ".blur"
        case .blendMode:                   return ".blendMode"
        case .brightness:                  return ".brightness"
        case .colorInvert:                 return ".colorInvert"
        case .contrast:                    return ".contrast"
        case .hueRotation:                 return ".hueRotation"
        case .saturation:                  return ".saturation"
        case .enabled:                     return nil // return ".disabled"
        case .blurRadius:                  return ".blur"
        case .backgroundColor:             return nil // return ".background"
        case .isClipped, .clipped:         return ".clipped"
        case .padding:                     return ".padding"
        case .cornerRadius:                return ".cornerRadius"
        case .fontSize, .textFont:         return nil // return ".font"
        case .textAlignment:               return nil // return ".multilineTextAlignment"
        case .textDecoration:              return ".underline"
        case .keyboardType:                return ".keyboardType"
        case .isSpellCheckEnabled:         return nil // return ".disableAutocorrection"
        case .isAnimating:                 return nil // return ".animation"
        case .fitStyle:                    return nil // return ".aspectRatio"
        case .shadowColor, .shadowOpacity, .shadowRadius, .shadowOffset:
                                           return nil // return ".shadow"
        case .minSize, .maxSize:           return nil // return ".frame"
        case .spacing:                     return nil // return ".padding"

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
//             .clipped, // alias for isClipped
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
