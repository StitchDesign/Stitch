//
//  NodeSelectedView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/16/22.
//

import SwiftUI
import StitchSchemaKit

// fka `NodeSelectedView`
struct CanvasItemSelectedViewModifier: ViewModifier {

    @AppStorage(StitchAppSettings.APP_THEME.rawValue) private var theme: StitchTheme = StitchTheme.defaultTheme

    let isSelected: Bool

    // must use slightly larger corner radius for highlight
//    let CANVAS_ITEM_SELECTED_CORNER_RADIUS = CANVAS_ITEM_CORNER_RADIUS + 3
    let CANVAS_ITEM_SELECTED_CORNER_RADIUS = CANVAS_ITEM_CORNER_RADIUS + 6

    func body(content: Content) -> some View {
        content
//            .padding(3)
//            .padding(7)
            .padding(6)
//            .overlay {
            .background {
                if isSelected {
                    // needs to be slightly larger than
                    RoundedRectangle(cornerRadius: CANVAS_ITEM_SELECTED_CORNER_RADIUS)
                        .strokeBorder(theme.themeData.highlightedEdgeColor, lineWidth: 3)
                        
                        .zIndex(-9999)
                }
            }
    }
}
