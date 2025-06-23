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


