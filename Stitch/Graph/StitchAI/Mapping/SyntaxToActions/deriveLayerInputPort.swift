//
//  deriveLayerInputPort.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import UIKit


extension SyntaxViewArgumentData {    
    func deriveLayerInputPort(_ layer: CurrentStep.Layer) -> CurrentStep.LayerInputPort? {
        switch SyntaxConstructorArgumentLabel(rawValue: self.label ?? "") {
            
        case .systemName:
            return .sfSymbol
            
        case .cornerRadius:
            return .cornerRadius
            
            // TODO: JUNE 24: *many* SwiftUI ...
        case .none:
            switch layer {
            case .text, .textField:
                return .text
            default:
//                throw SwiftUISyntaxError.unsupportedConstructorArgument(self)
                return nil
            }
        }
    }
}


enum DerivedLayerInputPortsResult: Equatable, Hashable, Sendable {
    
    // Vast majority of cases: a single view modifier name corresponds to a single layer input
    case simple(CurrentStep.LayerInputPort)
    
    // Special case: .rotation3DEffect modifier corresponds to *three* different layer inputs; .rotation also requires special parsing of its `.degrees(x)` arguments
    case rotationScenario
    
    // Tracks some layer ID assigned to a view
    case layerId
}

enum LayerInputViewModification {
    case layerInputValues([CurrentAIPatchBuilderResponseFormat.CustomLayerInputValue])
    case layerIdAssignment(String)
}

extension SyntaxViewModifierName {
    
    func deriveLayerInputPort(_ layer: CurrentStep.Layer) throws -> DerivedLayerInputPortsResult {
        switch (self, layer) {
            // Universal modifiers (same for every layer)
        case (.scaleEffect, _):
            return .simple(.scale)
        case (.opacity, _):
            return .simple(.opacity)
        
        /*
         TODO: JUNE 26: UI positioning is complicated by VPL anchoring and VPL "offset in VStack/HStack"
         
         Rules?:
         - SwiftUI .position modifier *always* becomes Stitch LayerInputPort.position
         
         - SwiftUI .offset modifier becomes Stitch LayerInputPort.offsetInGroup if view's parent is e.g. VStack, else becomes Stitch LayerInputPort.position
         
         */
        case (.position, _):
            return .simple(.position)

        case (.offset, _):
            // TODO: if view's parent is VStack/HStack, return .simple(.offsetInGroup) instead ?
            return .simple(.position)
        
        // Rotation is a more complicated scenario which we handle with special logic
        case (.rotationEffect, _),
            (.rotation3DEffect, _):
            // .rotationEffect is always a z-axis rotation, i.e. .rotationZ
            // .rotation3DEffect is .rotationX or .rotationY or .rotationZ
            return .rotationScenario
                    
        case (.blur, _):
            return .simple(.blurRadius)
        case (.blendMode, _):
            return .simple(.blendMode)
        case (.brightness, _):
            return .simple(.brightness)
        case (.colorInvert, _):
            return .simple(.colorInvert)
        case (.contrast, _):
            return .simple(.contrast)
        case (.hueRotation, _):
            return .simple(.hueRotation)
        case (.saturation, _):
            return .simple(.saturation)
        
        case (.fill, _): // fill is always color
            return .simple(.color)
            
            //    case (.font, .text):
            //        return .simple(.font)
            
            //    case (.fontWeight, _):
            //        //            return .simple(.fontWeight)
            //        return nil
            
            //    case (.lineSpacing, _):
            //        return nil // return .simple(.lineSpacing)
            
        case (.cornerRadius, _):
            return .simple(.cornerRadius)
            
            //    case (.shadow, _):
            //        // Shadow would need to be broken down into multiple inputs:
            //        // .shadowColor, .shadowRadius, .shadowOffset, .shadowOpacity
            //        return .simple(.shadowRadius)
            
        // TODO: JUNE 23: .frame modifier is actually several different LayerInputPort cases: .size, .minSize, .maxSize
        case (.frame, _):
            return .simple(.size)
            
        case (.padding, _):
            return .simple(.padding) // vs .layerPadding ?!
            
        case (.zIndex, _):
            return .simple(.zIndex)
        
        case (.foregroundColor, let kind) where kind != .text && kind != .textField:
            return .simple(.color)

        case (.foregroundColor, _):
            return .simple(.color)

            //        case (.backgroundColor, _):
            //            return .simple(.color)
                        
        case (.disabled, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.background, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.font, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.multilineTextAlignment, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.underline, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            // TODO: support after v1 schema
//        case (.keyboardType, _): return .simple(.keyboardType)
        case (.disableAutocorrection, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.clipped, _):
            return .simple(.clipped) // return .isClipped
        case (.layerId, _):
            return .layerId
        case (.color, _):
            return .simple(.color)
        default:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        }
    }
}

