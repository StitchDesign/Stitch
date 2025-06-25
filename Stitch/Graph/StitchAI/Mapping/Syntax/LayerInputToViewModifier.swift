//
//  LayerInputToSwiftUIViewModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// MARK: LayerInputPort -> SwiftUI modifier
// e.g. size -> .frame
// e.g. opacity -> .opacity

/*
 TODO: this is more complicated `layer input -> SwiftUI view modifier`.
 
 A Stitch layer input may map to tons of business logic (e.g. pinning) or a SwiftUI View constructor-argument.
 
 
 you actually want a data structure that's more like
 you want a single function for the mapping; so all the inputs, to all the ouput possibilities
 */


/*
 a couple things you want to know:
 - I want a "create layer" action. What do I need to know, from the ViewNode?
 - I want a "set layer input" action. What do I need to know, from the ViewNode?
 */

extension ViewNode {
    // derived from name and construct arguments
    func deriveCreateLayerAction() -> VPLLayer? {
        if let layer: Layer = self.deriveLayer() {
            return VPLLayer(
                id: self.id,
                name: layer,
                children: self.children.compactMap { $0.deriveCreateLayerAction() } )
        }
        return nil
    }
    
    func deriveLayer() -> Layer? {
        let name: ViewKind = self.name
        let args: [ConstructorArgument] = self.constructorArguments

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
    
    // dervied from modifiers and constructor arguments
    func deriveSetInputAndIncomingEdgeActions(_ layer: Layer) -> [VPLLayerConcept] {
        
        var actions = [VPLLayerConcept]()
        
        // iterate through constructor arguments
        for arg in self.constructorArguments {
            
            guard let port = arg.toLayerInput(layer) else {
                log("deriveSetInputAndIncomingEdgeActions: could not handle constructor argument label: \(arg.label)")
                // fatalErrorIfDebug()
                continue
            }
            
            switch arg.syntaxKind {
            
            case .literal:
                actions.append(
                    .layerInputSet(VPLLayerInputSet(kind: port,
                                                    value: arg.value))
                )
                
            case .expression, .variable:
                actions.append(
                    .incomingEdge(VPLIncomingEdge(name: port))
                )
            } // switch
            
        } // for arg in ...

        // iterate through modifiers
        for modifier in self.modifiers {
            
            guard let port = modifier.kind.toLayerInput(layer) else {
                log("could not create layer input for modifier \(modifier)")
                continue
            }
            
            // JUNE 24: PROPERLY HANDLE WHEN INPUT HAS ONE FIELD WITH A LITERAL AND ANOTHER FIELD WITH AN INCOMING EDGE
            let allLiteral = modifier.arguments.allSatisfy {
                if case .literal = $0.syntaxKind { return true }
                return false
            }
            if allLiteral {
                // Emit ONE SASetLayerInput: kind = modifier.kind, value = joined literal list
                // Format: "label1: value1, value2"
                let parts: [String] = modifier.arguments.map {
                    if let label = $0.label, !label.isEmpty {
                        return "\(label): \($0.value)"
                    } else {
                        return $0.value
                    }
                }
                
                let joined = parts.joined(separator: ", ")
                actions.append(.layerInputSet(VPLLayerInputSet(kind: port,
                                                               value: joined)))
            } else {
                // Emit ONE action per argument
                for arg in modifier.arguments {
                    switch arg.syntaxKind {
                    case .literal:
                    actions.append(.layerInputSet(VPLLayerInputSet(kind: port,
                                                                   value: arg.value)))
                    case .variable, .expression:
                        actions.append(.incomingEdge(VPLIncomingEdge(name: port)))
                    }
                }
            }
            
        } // for modifier in ...
        
        return actions
    }
    
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


func nilOrDebugCrash<T>() -> T? {
    fatalErrorIfDebug()
    return nil
}

/*
 Note: a ViewNode's core view (`name`) is either supported by Stitch (= a Layer) or not; if not, we return nil from `viewNode.deriveLayer` and do not process any of its modifiers, constructor-args or children.
 
 However, mapping between ViewNode's constructor-args and modifiers to Stitch Layer Inputs is more complicated.
 */

// TODO: maybe don't need these enums below? but a good way to understand how to convert between LayerInput and various parts of ViewNode


// Whether a given LayerInput corresponds to a ViewNode constructor-arg, a ViewNode modifier, or something much more complicated (e.g. pinning);
enum FromSwiftUIToLayerInput {
    // Simple conversions like `LayerInputPort.text -> Text(<textValue>)`
    case constructorArgument(ConstructorArgumentLabel)
    
    // Simple conversions like `LayerInputPort.scale -> .scaleEffect`
    case modifier(ModifierKind)
        
    //  When the LayerInputPort corresponds to something more complicated than a single SwiftUI view modifier or single SwiftUI view constructor
    // e.g. LayerInputPort.anchoring, which is a function of a layer size, layer position, layer anchoring and parent size
    case function
    
    // Heavier business logic cases that have no clear "SwiftUI code <-> VPL steps" equivalent, e.g. pinning;
    // if the mapping function returns `nil`, then the conversion is unsupported.
    case unsupported
}

enum FromLayerInputToSwiftUI {
    // Simple conversion where a SwiftUI View's constr-arg corresponds to a single LayerInputPort
    // e.g. `Text(<textValue>) -> LayerInputPort.text`
    // e.g. `Image(systemName:) -> LayerInputPort.sfSymbol`
    // e.g. `Image(uiImage:) -> LayerInputPort.media`
    case constructorArgument(ConstructorArgument)
    
    // Simple conversion where a SwiftUI view modifier corresponds to a single LayerInputPort
    // e.g. `.scaleEffect -> LayerInputPort.scale`
    // e.g. `.opacity -> LayerInputPort.opacity`
    
    // see `mapModifierToLayerInput` for handling really simple cases like this
    case modifier(Modifier)
    
    case function(ConversionFunction)
    
    // Many, many SwiftUI constructor-args and modifiers are unsupported by Stitch as of June 2025
    case unsupported
}


// TODO: JUNE 24: a more complex mapping
enum ConversionFunction {
    // LayerInputPort.anchoring, which is a function of a layer size, layer position, layer anchoring and parent size
    case anchoring
}

enum VPLConversionUnsupported {
    case pinning
}


extension LayerInputPort {

    /// A typed equivalent of `swiftUIModifier`.
    /// Returns `nil` when there is no direct SwiftUI modifier match.
    var toSwiftUIViewModifier: ModifierKind? {
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
