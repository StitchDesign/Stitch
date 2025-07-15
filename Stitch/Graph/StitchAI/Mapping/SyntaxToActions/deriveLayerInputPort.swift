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
    static func deriveLayerInputPort(_ layer: CurrentStep.Layer,
                                     label: String?,
                                     argFlatType: SyntaxViewModifierArgumentFlatType?) throws -> CurrentStep.LayerInputPort? {
        
        
        switch SyntaxConstructorArgumentLabel(rawValue: label ?? "") {
            
        case .systemName:
            // `Image(systemName:)`
            return .sfSymbol
            
        case .cornerRadius:
            // `RoundedRectangle(cornerRadius:)`
            return .cornerRadius
            
        case .spacing:
            // e.g. `VStack(spacing:)` or `HStack(spacing:)`
            return .spacing
            
        case .aligment:
            switch layer {
            case .group:
                // e.g. `VStack(spacing:)` or `HStack(spacing:)`
                return .layerGroupAlignment
            default:
                throw SwiftUISyntaxError.unsupportedConstructorArgument(layer, label, argFlatType)
            }
            
            
            
        // i.e. no label, so e.g. `Text("love")`
        case .none:
        
            switch layer {
                
            case .text, .textField:
                return .text
                        
            case .group:
                /*
                 Note: Many different forms supported:
                 
                 `ScrollView([.horizontal, .vertical])`
                 `ScrollView([.horizontal])`
                 `ScrollView(.horizontal)`
                 
                 ... but we only ever look at a single member-access at a time.
                 */
                if case .memberAccess(let x) = argFlatType,
                   let scrollEnabledPort = x.property.parseAsScrollAxis() {
                    return scrollEnabledPort
                } else {
                    return nil
                }
                
            default:
                throw SwiftUISyntaxError.unsupportedConstructorArgument(layer, label, argFlatType)
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
    
//    // e.g. `.underline()` or `.strikethrough()` modifiers
//    case textDecoration
//    
//    // SwiftUI.aspectRatio becomes a couple different cases? fitStyle for image, width/height axis too ?
//    case aspectRatio
//    
//    case textFont
}

enum LayerInputViewModification {
    case layerInputValues([CurrentAIGraphData.CustomLayerInputValue])
    case layerIdAssignment(String)
}

extension SyntaxViewModifierName {
    
    func deriveLayerInputPort(_ layer: CurrentStep.Layer) throws -> DerivedLayerInputPortsResult? {
        // Handle edge cases
        switch layer {
        case .text, .textField:
            switch self {
            case .foregroundColor:
                return .simple(.color)
                
            default:
                break
            }
            
        default:
            break
        }
        
        // Default behavior
        return try self.deriveLayerInputPort()
    }

    func deriveLayerInputPort() throws -> DerivedLayerInputPortsResult? {
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
        
        case .foregroundColor, .backgroundColor, .tint, .accentColor:
            return .simple(.color)
            
        case .onAppear:
            // We ignore this
            return nil

        case .disabled:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .background:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .font:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .multilineTextAlignment:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            // TODO: support after v1 schema
//        case .keyboardType: return .simple(.keyboardType)
        case .disableAutocorrection:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .clipped:
            return .simple(.isClipped)
//             return .simple(.clipped) // return .isClipped
        case .layerId:
            return .layerId
        case .color:
            return .simple(.color)
        
            // `.underline()` -> `LayerInputPort.TextDecoration + TextDecoration.underline`
        case .underline, .strikethrough:
            // TODO: text decoration can be strikethrough or underline
//            return .textDecoration
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
        case .aspectRatio:
//            return .aspectRatio
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
            // TODO: this is a text case
        case .bold,
                .fontDesign,
                .fontWeight,
                .monospacedDigit,
                .monospaced:
//            return .textFont
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            // MARK: Could be implemented someday?
        case .textCase,
                .textContentType,
                .textFieldStyle,
                .textInputAutocapitalization,
                .textSelection:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            
            // text / text field
        case .lineLimit:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .lineSpacing:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .truncationMode:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .uppercaseSmallCaps:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            // MARK: accessibility
        case .accessibilityAction,
                .accessibilityAddTraits,
                .accessibilityAdjustableAction,
                .accessibilityElement,
                .accessibilityFocused,
                .accessibilityHidden,
                .accessibilityHint,
                .accessibilityIdentifier,
                .accessibilityInputLabels,
                .accessibilityLabel,
                .accessibilityRemoveTraits,
                .accessibilityRepresentation,
                .accessibilityScrollAction,
                .accessibilityShowsLargeContentViewer,
                .accessibilitySortPriority:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            // Scroll
            case .scrollClipDisabled:
                throw SwiftUISyntaxError.unsupportedViewModifier(self)
            case .scrollDisabled:
                throw SwiftUISyntaxError.unsupportedViewModifier(self)
            case .scrollDismissesKeyboard:
                throw SwiftUISyntaxError.unsupportedViewModifier(self)
            case .scrollIndicators:
                throw SwiftUISyntaxError.unsupportedViewModifier(self)
            case .scrollTargetBehavior:
                throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            // Lists
        case .listRowBackground,
                .listRowInsets,
                .listRowSeparator,
                .listRowSeparatorTint,
                .listSectionSeparator,
                .listSectionSeparatorTint,
                .listSectionSeparatorVisibility,
                .listStyle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
            
            
        case .allowsHitTesting:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .allowsTightening:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .animation:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .badge:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .baselineOffset:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .border:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .buttonStyle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .clipShape:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .colorMultiply:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .compositingGroup:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .containerRelativeFrame:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .contentShape:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .controlSize:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .contextMenu:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .drawingGroup:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .dynamicTypeSize:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .environment:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .environmentObject:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .exclusiveGesture:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .fixedSize:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .focusable:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .focused:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .foregroundStyle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .gesture:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .help:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .highPriorityGesture:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .hoverEffect:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .id:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .ignoresSafeArea:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .interactiveDismissDisabled:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .italic:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .kerning:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .layoutPriority:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)

        
        case .mask:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        case .matchedGeometryEffect:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        case .menuStyle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .minimumScaleFactor:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .navigationBarBackButtonHidden:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .navigationBarHidden:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .navigationBarItems:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .navigationBarTitle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .navigationBarTitleDisplayMode:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .navigationDestination:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .navigationTitle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .onChange:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .onDisappear:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .onDrag:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .onDrop:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .onHover:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .onLongPressGesture:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .onSubmit:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .onTapGesture:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .overlay:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .preferredColorScheme:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .presentationCornerRadius:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .presentationDetents:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .progressViewStyle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .projectionEffect:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .redacted:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .refreshable:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .safeAreaInset:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .searchable:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .sensoryFeedback:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .shadow:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .simultaneousGesture:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .sliderStyle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .smallCaps:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .submitLabel:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .swipeActions:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .symbolEffect:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .symbolRenderingMode:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .tableStyle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        
        // Probably never will be implemented?
        case .task:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
    

        case .toggleStyle:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .toolbar:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .tracking:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .transformEffect:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)
        case .transition:
            throw SwiftUISyntaxError.unsupportedViewModifier(self)

        }
    }
}

