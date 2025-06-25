//
//  deriveLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation

extension Layer {
    
    func deriveSyntaxViewName(layerGroupOrientiation: StitchOrientation? = nil) -> SyntaxViewName? {
        
        switch self {
        
            // Stitch Layer.sfSymbol and Stitch Layer.image both use SwiftUI Image
        case .sfSymbol, .image:
            return .image
        case .rectangle:
            return .rectangle
        case .oval:
            return .ellipse
        case .text:
            return .text
        case .textField:
            return .textField
        
        // TODO: JUNE 24: Layer.group becomes ZStack, VStack, HStack, Grid etc. according to LayerInputPort.orientation
        case .group:
            // default to VStack for groups (any stack/grid maps to .group)
            return .zStack
        
        case .map:
            return .map
        case .video:
            return .videoPlayer
        case .model3D:
            return .model3D
        case .linearGradient:
            return .linearGradient
        case .radialGradient:
            return .radialGradient
        case .angularGradient:
            return .angularGradient
        case .material:
            return .material
        case .canvasSketch:
            return .canvas
        case .realityView:
            return nil
        case .shape:
            return nil
        case .colorFill:
            return .color
        case .hitArea:
            return .color
        case .progressIndicator:
            return nil
        case .switchLayer:
            return .toggle
        case .videoStreaming:
            return .videoPlayer
        case .box, .sphere, .cylinder, .cone:
            return .model3D
        }
    }
}

extension SyntaxView {
    func deriveLayer() -> Layer? {
        let name: SyntaxViewName = self.name
        let args: [SyntaxViewConstructorArgument] = self.constructorArguments
        
        // Vast majority of cases, there is a 1:1 mapping of ViewKind to Layer
        switch name {
            
        case .image:
            switch args.first?.label {
            case .systemName:
                return .sfSymbol
            default:
                return .image
            }
            
        case .roundedRectangle:
            return nil // nilOrDebugCrash()
            
        case .rectangle: return .rectangle
            
        case .ellipse: return .oval
            
            // SwiftUI Text view has different arg-constructors, but those do not change the Layer we return
        case .text: return .text
            
            // SwiftUI TextField view has different arg-constructors, but those do not change the Layer we return
        case .textField: return .textField
            
            // All 'stacks' are just a layer group; V vs H vs Z vs Grid is just the orientation input
        case .vStack, .hStack, .zStack, .lazyVStack, .lazyHStack, .lazyVGrid, .lazyHGrid, .grid:
            return .group
            
        case .map: return .map
            
            // Revisit these
        case .videoPlayer: return .video
        case .model3D: return .model3D
            
        case .circle: return nil // oval but not quite the same..
        case .capsule: return nil
        case .path: return nil // Canvas sketch ?
        case .color: return nil // both Layer.hitArea AND Layer.colorFill
            
        case .linearGradient: return .linearGradient
        case .radialGradient: return .radialGradient
        case .angularGradient: return .angularGradient
        case .material: return .material
            
            // TODO: JUNE 24: what actually is SwiftUI sketch ?
        case .canvas: return .canvasSketch
            
        case .secureField:
            // TODO: JUNE 24: ought to return `(Layer.textField, LayerInputPort.keyboardType, UIKeyboardType.password)` ? ... so a SwiftUI View can correspond to more than just a Layer ?
            return .textField
            
        case .label: return nil
        case .asyncImage: return nil
        case .symbolEffect: return nil
        case .group: return nil
        case .spacer: return nil
        case .divider: return nil
        case .geometryReader: return nil
        case .alignmentGuide: return nil
        case .scrollView: return nil
        case .list: return nil
        case .table: return nil
        case .outlineGroup: return nil
        case .forEach: return nil
        case .navigationStack: return nil
        case .navigationSplit: return nil
        case .navigationLink: return nil
        case .tabView: return nil
        case .form: return nil
        case .section: return nil
        case .button: return nil
        case .toggle: return nil
        case .slider: return nil
        case .stepper: return nil
        case .picker: return nil
        case .datePicker: return nil
        case .gauge: return nil
        case .progressView: return nil
        case .link: return nil
        case .timelineView: return nil
        case .anyView: return nil
        case .preview: return nil
        case .timelineSchedule: return nil
        case .custom(_): return nil
        }
    }
}
