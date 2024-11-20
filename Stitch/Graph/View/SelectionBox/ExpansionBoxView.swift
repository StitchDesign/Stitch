//
//  ExpansionBoxView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/6/21.
//

import SwiftUI
import StitchSchemaKit

/// Creates a selection box view.
struct RoundedRectView: View {
    @Environment(\.appTheme) private var theme

    let rect: CGRect

    var color: Color {
        theme.themeData.edgeColor
    }

    var body: some View {
        Canvas { context, size in
            // Normalize the rectangle to handle negative size values
            let normalizedRect = CGRect(
                x: min(rect.origin.x, rect.origin.x + rect.size.width),
                y: min(rect.origin.y, rect.origin.y + rect.size.height),
                width: abs(rect.size.width),
                height: abs(rect.size.height)
            )
            
            // Create a rounded rectangle path
            let roundedRectPath = Path(roundedRect: normalizedRect,
                                       cornerRadius: CANVAS_ITEM_CORNER_RADIUS)
            
            // Add a border to the rectangle
            context.stroke(
                roundedRectPath,
                with: .color(color),
                lineWidth: 4
            )
            
            context.fill(roundedRectPath, with: .color(color.opacity(0.4)))
        }
    }
}

struct ExpansionBoxView: View {
    let graph: GraphState
    let box: CGRect
    
    var body: some View {
        RoundedRectView(rect: box)
            .onChange(of: box) { _, newSelectionBounds in
                graph.processCanvasSelectionBoxChange(selectionBox: newSelectionBounds)
            }
    }
}

//struct ExpansionBoxView_Previews: PreviewProvider {
//    static var previews: some View {
//
//        let box = ExpansionBox(
//            expansionDirection: .none, // not quite correct?
//            size: CGSize(width: 100, height: 100),
//            startPoint: CGPoint(x: 400, y: 400),
//            endPoint: CGPoint(x: 500, y: 500))
//
//        ExpansionBoxView(box: box)
//    }
//}
