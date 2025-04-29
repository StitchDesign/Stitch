//
//  InputFieldBackgroundView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/29/25.
//

import SwiftUI

// TODO: per Elliot, this is actually a perf-expensive view?
struct InputFieldBackground: ViewModifier {
    
    @Environment(\.appTheme) var theme
    
    let show: Bool // if hovering, selected or for sidebar
    let hasDropdown: Bool
    let forPropertySidebar: Bool
    let isSelectedInspectorRow: Bool
    var width: CGFloat
    let isHovering: Bool
    
    let onTap: (() -> Void)? // nil =
     
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
            .background {
                // Why is `RoundedRectangle.fill` so much lighter than `RoundedRectangle.background` ?
                let color = show ? backgroundColor : Color.clear
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .overlay {
                        if isSelectedInspectorRow {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(theme.fontColor.opacity(0.3))
                        }
                    }
            }
            .contentShape(Rectangle())
        
            .overlay(content: {
                if isHovering {
                    content
                        .frame(width: width + hoveringAdjustment,
                               alignment: .leading)
                        .padding([.leading, .top, .bottom], 2)
                        .background {
                            // Why is `RoundedRectangle.fill` so much lighter than `RoundedRectangle.background` ?
                            let color = show ? Color.red : Color.clear
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color)
                                .overlay {
                                    if isSelectedInspectorRow {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(theme.fontColor.opacity(0.3))
                                    }
                                }
                        }
                        .offset(x: hoveringAdjustment / 2)
                        .onTapGesture {
                            if let onTap = self.onTap {
                                onTap()
                            }
                        }
                }
            })
            .zIndex(isHovering ? 99999 : 0)
    }
}
