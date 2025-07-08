//
//  deriveLayerInputPort.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import UIKit
import SwiftUI


extension SyntaxViewArgumentData {
    
    // A single argument can correspond to multiple layer inputs,
    // e.g. `ScrollView([.horizontal, .vertical]) corresponds to ScrollXEnabled, ScrollYEnabled
//    func deriveLayerInputPort(_ layer: CurrentStep.Layer) -> [CurrentStep.LayerInputPort]? {
    static func deriveLayerInputPort(_ layer: CurrentStep.Layer,
                                     label: String? = nil,
                                     argType: SyntaxViewModifierArgumentType? = nil) -> CurrentStep.LayerInputPort? {
        
//        switch SyntaxConstructorArgumentLabel(rawValue: self.label ?? "") {
        switch SyntaxConstructorArgumentLabel(rawValue: label ?? "") {
            
        case .systemName:
            return .sfSymbol
            
        case .cornerRadius:
            return .cornerRadius
            
        // e.g. `VStack(spacing:)` or `HStack(spacing:)`
        case .spacing:
            return .spacing
            
            // TODO: JUNE 24: *many* SwiftUI ...
        case .none: // i.e. no label, so e.g. `Text("love")`
            switch layer {
            case .text, .textField:
                return .text
            
            
            // TODO: a group could be a VStack or HStack, which accepts `spacing:` etc.; or a could be a scroll
            
            case .group:
                // NOTE:
                // A layer group
                // Many different forms supported:
                // `ScrollView([.horizontal, .vertical])`
                // `ScrollView([.horizontal])`
                // `ScrollView(.horizontal)`
                
                
                
                // SHOULD NOT BE CALLED WITH AN ARRAY -- ONLY A TUPLE OR MEMBER-ACCESS OR LITERAL ?
                
//                if case let .array(array) = self.value {
//                    log("SyntaxViewArgumentData: deriveLayerInputPort: had array: \(array)")
//                    return array.compactMap {
//                        if case let .memberAccess(member) = $0,
//                           let port = member.deriveLayerInputPort() {
//                            return port
//                        } else {
//                            return nil
//                        }
//                    }
////                    return [.scrollXEnabled, .scrollYEnabled]
//                    
//                }
//
                switch argType {
                case .memberAccess(let x):
                    if let port = x.property.parseAsScrollAxis() {
                        return port
                    }
                default:
                    return nil
                }
                
//                if let argValueString = argValueString,
//                   let port = argValueString.parseAsScrollAxis() {
//                    return port
//                }
                
////
////                else
//                if case let .memberAccess(member) = self.value,
//                        let port = member.deriveLayerInputPort() {
//                    log("SyntaxViewArgumentData: deriveLayerInputPort: had port: \(port)")
//                    return port
//                }
                
                //
                //                    if member.property == "horizontal" {
//                                        log("SyntaxViewArgumentData: deriveLayerInputPort: had horizontal")
                //                        return [.scrollXEnabled]
                //                    } else if member.property == "vertical" {
                //                        log("SyntaxViewArgumentData: deriveLayerInputPort: had vertical")
                //                        return [.scrollYEnabled]
                //                    }
                
//                }
                
                log("SyntaxViewArgumentData: deriveLayerInputPort: returning nil")
                return nil
                
                
            default:
//                throw SwiftUISyntaxError.unsupportedConstructorArgument(self)
                return nil
            }
        }
    }
}

extension String {
    // A member-access might correspond to a single layer-input-port
    func parseAsScrollAxis() -> CurrentStep.LayerInputPort? {
        switch self {
        case Axis.horizontal.description:
            return .scrollXEnabled
        case Axis.vertical.description:
            return .scrollYEnabled
        default:
            return nil
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

        case (.backgroundColor, _):
            return .simple(.color)
            
        case (.disabled, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.background, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.font, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.multilineTextAlignment, _):
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
        
            // REBASE HERE FOR IMPORTANT INFO
            
            // `.underline()` -> `LayerInputPort.TextDecoration + TextDecoration.underline`
            
        case (.underline, _),
            (.strikethrough, _):
            // TODO: text decoration can be strikethrough or underline
            return .simple(.textDecoration)
            
//        default:
//            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accentColor, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityAction, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityAddTraits, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityAdjustableAction, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityElement, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityFocused, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityHidden, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityHint, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityIdentifier, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityInputLabels, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityLabel, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityRemoveTraits, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityRepresentation, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityScrollAction, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilityShowsLargeContentViewer, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.accessibilitySortPriority, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.allowsHitTesting, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.allowsTightening, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.animation, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.aspectRatio, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.badge, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.baselineOffset, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.bold, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.border, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.buttonStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.clipShape, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.colorMultiply, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.compositingGroup, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.containerRelativeFrame, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.contentShape, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.controlSize, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.contextMenu, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.drawingGroup, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.dynamicTypeSize, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.environment, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.environmentObject, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.exclusiveGesture, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.fixedSize, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.focusable, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.focused, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        case (.fontDesign, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.fontWeight, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
        case (.foregroundStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        case (.gesture, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
        case (.help, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        case (.highPriorityGesture, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
        case (.hoverEffect, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        case (.id, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
        case (.ignoresSafeArea, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.interactiveDismissDisabled, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        case (.italic, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
        case (.kerning, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.layoutPriority, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.lineLimit, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.lineSpacing, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.listRowBackground, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.listRowInsets, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.listRowSeparator, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.listRowSeparatorTint, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.listSectionSeparator, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.listSectionSeparatorTint, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.listSectionSeparatorVisibility, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.listStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.mask, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.matchedGeometryEffect, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.menuStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.minimumScaleFactor, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.monospaced, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.monospacedDigit, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.navigationBarBackButtonHidden, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.navigationBarHidden, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.navigationBarItems, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.navigationBarTitle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.navigationBarTitleDisplayMode, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.navigationDestination, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.navigationTitle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onAppear, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onChange, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onDisappear, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onDrag, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onDrop, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onHover, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onLongPressGesture, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onSubmit, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.onTapGesture, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.overlay, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.preferredColorScheme, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.presentationCornerRadius, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.presentationDetents, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.progressViewStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.projectionEffect, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.redacted, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.refreshable, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.safeAreaInset, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.scrollClipDisabled, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.scrollDisabled, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.scrollDismissesKeyboard, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.scrollIndicators, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.scrollTargetBehavior, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.searchable, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.sensoryFeedback, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.shadow, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.simultaneousGesture, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.sliderStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.smallCaps, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
                    
        case (.submitLabel, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.swipeActions, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.symbolEffect, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.symbolRenderingMode, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.tableStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.task, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.textCase, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.textContentType, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.textFieldStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        case (.textInputAutocapitalization, _):
            
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
        case (.textSelection, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.tint, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.toggleStyle, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.toolbar, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.tracking, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.transformEffect, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.transition, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.truncationMode, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case (.uppercaseSmallCaps, _):
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        }
    }
}

