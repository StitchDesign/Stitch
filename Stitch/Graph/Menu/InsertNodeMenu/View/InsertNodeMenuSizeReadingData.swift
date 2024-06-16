//
//  InsertNodeMenuSizeReadingData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/24/24.
//

import Foundation
import SwiftUI

struct InsertNodeFooterSizeReader: View {

    @Binding var footerRect: CGRect

    var body: some View {
        GeometryReader { proxy in
            let cgRect = proxy.frame(in: .global)
            Color.clear
                .onChange(of: proxy.frame(in: .global), initial: true) {
                    // log("InsertNodeFooterSizeReader: onChange: cgRect.size: \(cgRect.size)")
                    // log("InsertNodeFooterSizeReader: onChange: cgRect.origin: \(cgRect.origin)")
                    
                    // Note: original implementation could just use `cgRect.width`; why did this change?
                    let staticWidth = INSERT_NODE_MENU_FOOTER_WIDTH
                    
                    // Expand height of footer's CGRect such that any selection at or below the footer is treated as "below"
                    let expandedHeight = cgRect.height + 900
                    
                    self.footerRect = .init(origin: cgRect.origin,
                                            size: .init(width: staticWidth,
                                                        height: expandedHeight))
                }
        }
    }
}

struct InsertNodeResultSizeReader: View {

    let id: UUID // id of InsertNodeMenuOptionData
    let title: String // debug
    @Binding var nodeResultSizes: [UUID: CGRect]

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onChange(of: proxy.frame(in: .global), initial: true) { _, newValue in
                    // log("InsertNodeResultSizeReader: onChange: \(title) \(id)")
                    // log("InsertNodeResultSizeReader: onChange: newValue.origin: \(newValue.origin)")
                    // log("InsertNodeResultSizeReader: onChange: newValue.size: \(newValue.size)")
                    nodeResultSizes.updateValue(
                        newValue,
                        forKey: id)
                }
        }
    }
}
