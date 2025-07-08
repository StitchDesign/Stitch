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
        // Handle edge cases
        switch layer {
        case .text, .textField:
            switch self {
            case .foregroundColor:
                throw SwiftUISyntaxError.unsupportedViewModifierForLayer(self, layer)
                
            default:
                break
            }
            
        default:
            break
        }
        
        // Default behavior
        return try self.deriveLayerInputPort()
    }

    func deriveLayerInputPort() throws -> DerivedLayerInputPortsResult {
        switch self {
            // Universal modifiers (same for every layer)
        case .scaleEffect:
            return .simple(.scale)
        case .opacity:
            return .simple(.opacity)
        
        /*
         TODO: JUNE 26: UI positioning is complicated by VPL anchoring and VPL "offset in VStack/HStack"
         
         Rules?:
         - SwiftUI .position modifier *always* becomes Stitch LayerInputPort.position
         
         - SwiftUI .offset modifier becomes Stitch LayerInputPort.offsetInGroup if view's parent is e.g. VStack, else becomes Stitch LayerInputPort.position
         
         */
        case .position:
            return .simple(.position)

        case .offset:
            // TODO: if view's parent is VStack/HStack, return .simple(.offsetInGroup) instead ?
            return .simple(.position)
        
        // Rotation is a more complicated scenario which we handle with special logic
        case .rotationEffect,
            .rotation3DEffect:
            // .rotationEffect is always a z-axis rotation, i.e. .rotationZ
            // .rotation3DEffect is .rotationX or .rotationY or .rotationZ
            return .rotationScenario
                    
        case .blur:
            return .simple(.blurRadius)
        case .blendMode:
            return .simple(.blendMode)
        case .brightness:
            return .simple(.brightness)
        case .colorInvert:
            return .simple(.colorInvert)
        case .contrast:
            return .simple(.contrast)
        case .hueRotation:
            return .simple(.hueRotation)
        case .saturation:
            return .simple(.saturation)
        
        case .fill: // fill is always color
            return .simple(.color)
            
            //    case (.font, .text):
            //        return .simple(.font)
            
            //    case .fontWeight:
            //        //            return .simple(.fontWeight)
            //        return nil
            
            //    case .lineSpacing:
            //        return nil // return .simple(.lineSpacing)
            
        case .cornerRadius:
            return .simple(.cornerRadius)
            
            //    case .shadow:
            //        // Shadow would need to be broken down into multiple inputs:
            //        // .shadowColor, .shadowRadius, .shadowOffset, .shadowOpacity
            //        return .simple(.shadowRadius)
            
        // TODO: JUNE 23: .frame modifier is actually several different LayerInputPort cases: .size, .minSize, .maxSize
        case .frame:
            return .simple(.size)
            
        case .padding:
            return .simple(.padding) // vs .layerPadding ?!
            
        case .zIndex:
            return .simple(.zIndex)
        
        case .foregroundColor:
            return .simple(.color)

        case .backgroundColor:
            return .simple(.color)
            
        case .disabled:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .background:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .font:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .multilineTextAlignment:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .underline:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            // TODO: support after v1 schema
//        case .keyboardType: return .simple(.keyboardType)
        case .disableAutocorrection:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .clipped:
            return .simple(.clipped) // return .isClipped
        case .layerId:
            return .layerId
        case .color:
            return .simple(.color)
        default:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        }
    }
}

