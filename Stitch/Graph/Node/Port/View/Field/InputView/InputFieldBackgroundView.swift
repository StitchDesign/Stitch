//
//  InputFieldBackgroundView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI


struct InputFieldFrameAndPadding: ViewModifier {
    
    /*
     Expected to have already been adjusted for the specific case, e.g.
     - a single field in a multifield input in the inspector (e.g. Position input's X field), so width is smaller than normal
     - we're hovering over a canvas item's field and so width is larger than normal
     */
    let width: CGFloat
    
    let hasPicker: Bool
        
    var widthAdjustedForDropdown: CGFloat {
        width - (hasPicker ? (COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH + 2) : 0.0)
    }
    
    func body(content: Content) -> some View {
        content
            .frame(width: widthAdjustedForDropdown, alignment: .leading)
            .frame(width: width, alignment: .leading)
            .padding([.leading, .top, .bottom], 2)
    }
}


// Used by canvas fields and, on iPad, when inspector row is selected
struct InputFieldBackgroundColorView: ViewModifier {
    
    @Environment(\.appTheme) var theme
    
    let isHovering: Bool
    let isFocused: Bool
    let isForLayerInspector: Bool
    
    // Really, only for iPad
    let isSelectedInspectorRow: Bool
    
    // TODO: should focused fields in flyouts and inspector use same background color as focused canvas fields?
    var color: Color {
        
        // Flyout and inspector never
//        if isForLayerInspector {
//            return .INSPECTOR_FIELD_BACKGROUND_COLOR
//        }
        
        // Focus takes precedent over hover
        if isFocused {
//            if isForLayerInspector {
//                return .INSPECTOR_FIELD_BACKGROUND_COLOR
//            } else {
                return .WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE
//            }
            
        } else if isHovering {
            return .WHITE_IN_LIGHT_MODE_BLACK_IN_DARK_MODE
        }
        
        // "At rest" i.e. no user interaction
        else {
            if isForLayerInspector {
                return .INSPECTOR_FIELD_BACKGROUND_COLOR
            } else {
                return .clear
            }
        }
    }
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(self.color)
            }
        #if !targetEnvironment(macCatalyst)
            .background {
                if isSelectedInspectorRow {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.fontColor.opacity(0.3))
                        }
                }
            }
        #endif
    }
}

