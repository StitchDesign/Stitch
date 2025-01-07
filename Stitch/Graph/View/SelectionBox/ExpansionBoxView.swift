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
    let scale: CGFloat

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
                lineWidth: 4 * 1/scale
            )

            let scaledSize = CGSize(width: size.width * scale,
                                    height: size.height * scale)
            
            logInView("RoundedRectView: scale: \(scale)")
            logInView("RoundedRectView: size: \(size)")
            logInView("RoundedRectView: scaledSize: \(scaledSize)")
            logInView("RoundedRectView: rect.size: \(rect.size)")
            logInView("RoundedRectView: rect.origin: \(rect.origin)")
            
            context.fill(roundedRectPath, with: .color(color.opacity(0.4)))
            
            // what should be the orgiin here?
//            let sizePath = Path(roundedRect: .init(origin: .zero, size: size),
//                                cornerRadius: CANVAS_ITEM_CORNER_RADIUS)
            
//            context.stroke(sizePath, with: .color(.white), lineWidth: 12)
        }
        
        // this frame... it thinks we're already max size?
        .border(.green, width: 8)
        
        // seriously messes up everything ?
//        .frame(width: WHOLE_GRAPH_LENGTH * 1/scale,
//               height: WHOLE_GRAPH_LENGTH * 1/scale)
        .offset(x: 500,
                y: 500)
        .border(.black, width: 8)
        
        // messes everthing up?
//        .scaleEffect(1/scale)
        
    }
}

struct ExpansionBoxView: View {
    let graph: GraphState
    let box: CGRect
    let scale: CGFloat
    
    var body: some View {
        RoundedRectView(rect: box, scale: scale)
            .onChange(of: box) { _, newSelectionBounds in
                graph.processCanvasSelectionBoxChange(selectionBox: newSelectionBounds)
            }
    }
}


// NOTE: LEGACY EXPANSION BOX VIEW
// TODO: debug why SwiftUI Canvas
// https://github.com/StitchDesign/Stitch/pull/578/files#diff-62ea000e757e13dc2ac4d4a896ac3aad9e9af6a4e6a63311b25b924dbbbabdde
//struct ExpansionBoxView: View {
//    
//    @Environment(\.appTheme) var theme
//    
//    var color: Color {
//        theme.themeData.edgeColor
//    }
//    
//    let box: ExpansionBox
//    
//    @State var size: CGSize = .zero
//    
//    
//    var body: some View {
//        RoundedRectangle(cornerRadius: CANVAS_ITEM_CORNER_RADIUS,
//                         style: .continuous)
//        .fill(color.opacity(0.4))
//        .overlay(
//            RoundedRectangle(cornerRadius: CANVAS_ITEM_CORNER_RADIUS)
//                .stroke(color, lineWidth: 4)
//        )
//        .frame(box.size)
//        .position(box.anchorCorner)
//    }
//}



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

