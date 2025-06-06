//
//  AnchorGridIconView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/28/24.
//

import SwiftUI
import StitchSchemaKit

struct AnchoringGridIconView: View {

    @AppStorage(StitchAppSettings.APP_THEME.rawValue) private var theme: StitchTheme = StitchTheme.defaultTheme
    
    private let iconLength = 100.0
    private let squareLength = 25.0 + 4 // +4 because of padding?
    private let color: Color = .THEMED_TITLE_FONT_COLOR
    
    // nil when multiselect
    let anchor: Anchoring?
    let isSelectedInspectorRow: Bool
    
    //    let anchor: Anchoring = .init(y: 0.2, x: 0.7)
    //    let anchor: Anchoring = .topLeft
    //    let anchor: Anchoring = .bottomCenter
    
    private var finalColor: Color {
        isSelectedInspectorRow ? theme.fontColor : color
    }
    
    var body: some View {
        ZStack {
            Image(systemName: "square.grid.3x3")
                .resizable()
                .frame(width: iconLength,
                       height: iconLength)
                .foregroundColor(finalColor)
        }
        .overlay {
            if let anchor = anchor {
                currentAnchor(anchor)
            }
        }
    }
    
    @ViewBuilder
    func currentAnchor(_ anchor: Anchoring) -> some View {
        
        /*
         Based off of `adjustPosition`:
         
         let height = position.height
             + (parentSize.height * anchor.y)
             - (size.height * (anchor.y - 0.5))
         
         ^^ But `position` will always be 0
         */
        let x = (iconLength * anchor.x) - (squareLength * (anchor.x - 0.5))
        let y = (iconLength * anchor.y) - (squareLength * (anchor.y - 0.5))
        
        RoundedRectangle(cornerRadius: 8.0, style: .continuous)
            .fill(finalColor)
            .frame(width: squareLength, height: squareLength)
            .position(x: x, y: y)
    }
}
