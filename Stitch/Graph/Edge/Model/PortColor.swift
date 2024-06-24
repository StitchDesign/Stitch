//
//  LoopColor.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let PORT_COLOR: Color = Color(.port)

enum PortColor: Equatable {
    case noEdge,
         edge,
         loopEdge,
         highlightedEdge,
         highlightedLoopEdge

    func color(_ theme: StitchTheme) -> Color {
        self.color(theme.themeData)
    }
    
    func color(_ themeData: StitchThemeData) -> Color {
        switch self {
        case .noEdge:
            return PORT_COLOR
        case .edge:
            return themeData.edgeColor
        case .loopEdge:
            return LOOP_EDGE_COLOR
        case .highlightedEdge:
            return themeData.highlightedEdgeColor
        case .highlightedLoopEdge:
            return HIGHLIGHTED_LOOP_EDGE_COLOR
        }
    }
}
