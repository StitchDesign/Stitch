//
//  deriveLayerInputPort.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation


extension SyntaxView {
    
    // TODO: actually use this; i.e. update SASetLayerInput to use LayerInputPort
    func deriveLayerInputPorts(_ layer: Layer) -> LayerInputPortSet {
        
        let portsFromConstructorArgs = self.constructorArguments.compactMap {
            $0.toLayerInput(layer)
        }
        
        let portsFromModifiers = self.modifiers.compactMap {
            $0.kind.toLayerInput(layer)
        }
        
        let ports = portsFromConstructorArgs + portsFromModifiers
        let portsSet = ports.toOrderedSet
        
        assertInDebug(ports.count == portsSet.count)
        
        return portsSet
    }
}

extension SyntaxViewConstructorArgument {
    func toLayerInput(_ layer: Layer) -> LayerInputPort? {
        switch self.label {
            
        case .systemName:
            return .sfSymbol
            
        // TODO: JUNE 24: *many* SwiftUI ...
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

extension SyntaxViewModifierName {
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

