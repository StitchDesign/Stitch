//
//  deriveLayerInputPort.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import UIKit


extension SyntaxView {
    
    // TODO: actually use this; i.e. update SASetLayerInput to use LayerInputPort
    func deriveLayerInputPorts(_ layer: CurrentStep.Layer) -> Set<CurrentStep.LayerInputPort> {
        
        let portsFromConstructorArgs = self.constructorArguments.compactMap {
            $0.deriveLayerInputPort(layer)
        }
        
        let portsFromModifiers = self.modifiers.compactMap {
            $0.name.deriveLayerInputPort(layer)
        }
        
        let ports = portsFromConstructorArgs + portsFromModifiers
        let portsSet = Set(ports)
        
        assertInDebug(ports.count == portsSet.count)
        
        return portsSet
    }
}

extension SyntaxViewConstructorArgument {
    
    func derivePortValue(_ layer: CurrentStep.Layer) -> CurrentStep.PortValue? {
        let label: SyntaxConstructorArgumentLabel = self.label
        guard let firstValue = self.values.first?.value else { return nil }
        
        switch (label, layer) {
        
        case (.systemName, _):
            return .string(.init(firstValue))
        
        case (.cornerRadius, _):
            return .number(toNumber(firstValue) ?? .zero)
            
        case (_, let text) where text == .text || text == .textField:
            return .string(.init(firstValue))
            
        case (.noLabel, _):
            // e.g. `Rectangle()`, `Ellipse`,
            // i.e. there's no constructor argument at all
            return nil
        }
    }
    
    func deriveLayerInputPort(_ layer: CurrentStep.Layer) -> CurrentStep.LayerInputPort? {
        switch self.label {
            
        case .systemName:
            return .sfSymbol
            
        case .cornerRadius:
            return .cornerRadius
            
        // TODO: JUNE 24: *many* SwiftUI ...
        case .noLabel:
            switch layer {
            case .text, .textField:
                return .text
            default:
                return nil
            }
        }
    }
}


extension SyntaxViewModifierName {
    
    func deriveLayerInputPort(_ layer: CurrentStep.Layer) -> CurrentStep.LayerInputPort? {
        switch (self, layer) {
            // Universal modifiers (same for every layer)
        case (.scaleEffect, _):
            return .scale
        case (.opacity, _):
            return .opacity
        
        /*
         TODO: JUNE 26: UI positioning is complicated by VPL anchoring and VPL "offset in VStack/HStack"
         
         Rules?:
         - SwiftUI .position modifier *always* becomes Stitch LayerInputPort.position
         
         - SwiftUI .offset modifier becomes Stitch LayerInputPort.offsetInGroup if view's parent is e.g. VStack, else becomes Stitch LayerInputPort.position
         
         */
        case (.position, _):
            return .position

        case (.offset, _):
            // TODO: if view's parent is VStack/HStack, return .offsetInGroup instead ?
            return .position
            
        
        case (.rotationEffect, _):
            // .rotationEffect is always a z-axis rotation
            return .rotationZ
        
        case (.rotation3DEffect, _):
            // Depending on the axis specified in the arguments
            // This would need argument extraction to determine X, Y, or Z
            
            // TODO: JULY 1: .rotation3DEffect
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
            
            // TODO: support after v1 schema
//        case (.keyboardType, _): return .keyboardType
        case (.disableAutocorrection, _): return nil
        case (.clipped, _): return .clipped // return .isClipped
            
        case (.custom(_), _): return nil
        }
    }
}

