//
//  InputFieldBackgroundView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI

// TODO: per Elliot, this is actually a perf-expensive view?
struct InputFieldBackground: ViewModifier {
        
    let show: Bool // if hovering, selected or for sidebar
    let hasDropdown: Bool
    let forPropertySidebar: Bool
    let isSelectedInspectorRow: Bool
    let isCanvasField: Bool
    var width: CGFloat
    let isHovering: Bool
    
    let onTap: (() -> Void)?
     
//    static let HOVER_EXTRA_LENGTH: CGFloat = 80
//    static let HOVER_EXTRA_LENGTH: CGFloat = 100
    static let HOVER_EXTRA_LENGTH: CGFloat = 52
    
    var hoveringAdjustment: CGFloat {
        isHovering ? Self.HOVER_EXTRA_LENGTH : 0
    }
    
    var widthAdjustedForDropdown: CGFloat {
        width - (hasDropdown ? (COMMON_EDITING_DROPDOWN_CHEVRON_WIDTH + 2) : 0.0)
    }
    
    var hoveredAdjustmentForAlignment: CGFloat {
        (hoveringAdjustment - width) / 2
    }
    
    var backgroundColor: Color {
        if forPropertySidebar {
            return Color.INSPECTOR_FIELD_BACKGROUND_COLOR
        } else {
            return Color.COMMON_EDITING_VIEW_READ_ONLY_BACKGROUND_COLOR
        }
    }
    
    func body(content: Content) -> some View {
        content
            
        
        // When this field uses a dropdown,
        // we shrink the "typeable" area of the input,
        // so that typing never touches the dropdown's menu indicator.
            .frame(width: widthAdjustedForDropdown, alignment: .leading)
        
        // ... But we always use a full-width background for the focus/hover effect.
            .frame(width: width, alignment: .leading)
            .padding([.leading, .top, .bottom], 2)
        
            .modifier(InputFieldBackgroundColorView(show: show))
            .modifier(InspectorSelectedRowFieldBackground(isSelectedInspectorRow: isSelectedInspectorRow))
        
            .contentShape(Rectangle())
        
        // Canvas field ONLY
            .overlay(content: {
                if isHovering, isCanvasField {
                    content
                        .frame(width: width + hoveringAdjustment,
                               alignment: .leading)
                        .padding([.leading, .top, .bottom], 2)
                        .modifier(InputFieldBackgroundColorView(show: show))
                        
                        .offset(x: hoveringAdjustment / 2)
                        
                        .onTapGesture {
                            if let onTap = self.onTap {
                                onTap()
                            }
                        }
                }
            })
    }
}

// Used by canvas fields and, on iPad, when inspector row is selected
struct InputFieldBackgroundColorView: ViewModifier {
    
    @Environment(\.appTheme) var theme
    
    let show: Bool
    
    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(show ? Color.red : Color.clear)
            }
    }
}

// Only for iPad, to change the color of field's background when the entire inspector row is selected
struct InspectorSelectedRowFieldBackground: ViewModifier {
    
    let isSelectedInspectorRow: Bool
    
    @Environment(\.appTheme) var theme
    
    func body(content: Content) -> some View {
        content
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


struct CanvasFieldHoverView: View {
    
    var body: some View {
        Text("WIP")
    }
}
