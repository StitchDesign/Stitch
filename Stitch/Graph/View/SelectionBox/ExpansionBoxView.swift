//
//  ExpansionBoxView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/6/21.
//

import SwiftUI
import StitchSchemaKit

struct ExpansionBoxView: View {
    
    let graph: GraphState
    let document: StitchDocumentViewModel
    let box: ExpansionBox
    
    @Environment(\.appTheme) var theme
    
    var color: Color {
        theme.themeData.edgeColor
    }
        
    @State var size: CGSize = .zero
    
    
    var body: some View {
        RoundedRectangle(cornerRadius: CANVAS_ITEM_CORNER_RADIUS,
                         style: .continuous)
        .fill(color.opacity(0.4))
        .overlay(
            RoundedRectangle(cornerRadius: CANVAS_ITEM_CORNER_RADIUS)
                .stroke(color, lineWidth: 4)
        )
        .frame(box.size)
        .position(box.anchorCorner)
        .onChange(of: box) { _, newSelectionBounds in
            document.processCanvasSelectionBoxChange(selectionBox: newSelectionBounds.asCGRect)
        }
    }
}

// NOTE: LEGACY EXPANSION BOX VIEW
// TODO: UIScrollView's zoomLevel appears to shrink SwiftUI Canvas' size, hence the node selection box gets cut off; revisit this and figure out how to still be able to use a SwiftUI Canvas ?
// https://github.com/StitchDesign/Stitch/pull/578/files#diff-62ea000e757e13dc2ac4d4a896ac3aad9e9af6a4e6a63311b25b924dbbbabdde

///// Creates a selection box view.
//struct RoundedRectView: View {
//    @Environment(\.appTheme) private var theme
//
//    let rect: CGRect
//    let scale: CGFloat
//
//    var color: Color {
//        theme.themeData.edgeColor
//    }
//
//    var body: some View {
//        Canvas { context, size in
//            // Normalize the rectangle to handle negative size values
//            let normalizedRect = CGRect(
//                x: min(rect.origin.x, rect.origin.x + rect.size.width),
//                y: min(rect.origin.y, rect.origin.y + rect.size.height),
//                width: abs(rect.size.width),
//                height: abs(rect.size.height)
//            )
//            
//            // Create a rounded rectangle path
//            let roundedRectPath = Path(roundedRect: normalizedRect,
//                                       cornerRadius: CANVAS_ITEM_CORNER_RADIUS)
//            
//            // Add a border to the rectangle
//            context.stroke(
//                roundedRectPath,
//                with: .color(color),
//                lineWidth: 4 * 1/scale
//            )
//
//            let scaledSize = CGSize(width: size.width * scale,
//                                    height: size.height * scale)
//            
//            logInView("RoundedRectView: scale: \(scale)")
//            logInView("RoundedRectView: size: \(size)")
//            logInView("RoundedRectView: scaledSize: \(scaledSize)")
//            logInView("RoundedRectView: rect.size: \(rect.size)")
//            logInView("RoundedRectView: rect.origin: \(rect.origin)")
//            
//            context.fill(roundedRectPath, with: .color(color.opacity(0.4)))
//            
//            // what should be the orgiin here?
////            let sizePath = Path(roundedRect: .init(origin: .zero, size: size),
////                                cornerRadius: CANVAS_ITEM_CORNER_RADIUS)
//            
////            context.stroke(sizePath, with: .color(.white), lineWidth: 12)
//        }
//        
//        // this frame... it thinks we're already max size?
//        .border(.green, width: 8)
//        
//        // seriously messes up everything ?
////        .frame(width: WHOLE_GRAPH_LENGTH * 1/scale,
////               height: WHOLE_GRAPH_LENGTH * 1/scale)
//        .offset(x: 500,
//                y: 500)
//        .border(.black, width: 8)
//        
//        // messes everthing up?
////        .scaleEffect(1/scale)
//        
//    }
//}

//struct ExpansionBoxView: View {
//    let graph: GraphState
//    let box: CGRect
//    let scale: CGFloat
//    
//    var body: some View {
//        RoundedRectView(rect: box, scale: scale)
//            .onChange(of: box) { _, newSelectionBounds in
//                graph.processCanvasSelectionBoxChange(selectionBox: newSelectionBounds)
//            }
//    }
//}

