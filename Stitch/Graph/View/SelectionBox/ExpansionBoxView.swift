//
//  ExpansionBoxView.swift
//  prototype
//
//  Created by Christian J Clampitt on 12/6/21.
//

import SwiftUI
import StitchSchemaKit

struct SelectionBoxPreferenceKey: PreferenceKey {
    typealias Value = CGRect

    static var defaultValue: Value = .init()

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value = nextValue()
    }
}

struct ExpansionBoxView: View {

    @Environment(\.appTheme) var theme

    var color: Color {
        theme.themeData.edgeColor
    }

    let box: ExpansionBox

    @State var size: CGSize = .zero

    var body: some View {
        RoundedRectangle(cornerRadius: CANVAS_ITEM_CORNER_RADIUS,
                         style: .continuous)
            .fill(color.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: CANVAS_ITEM_CORNER_RADIUS)
                    .stroke(color, lineWidth: 4)
            )
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: SelectionBoxPreferenceKey.self,
                                    value: geometry.frame(in: .named(NodesView.coordinateNameSpace)))
                }
            }
            .frame(box.size)
            .position(box.anchorCorner)
            .onPreferenceChange(SelectionBoxPreferenceKey.self) { newSelectionBounds in
                dispatch(DetermineSelectedCanvasItems(selectionBounds: newSelectionBounds))
            }
    }
}

struct ExpansionBoxView_Previews: PreviewProvider {
    static var previews: some View {

        let box = ExpansionBox(
            expansionDirection: .none, // not quite correct?
            size: CGSize(width: 100, height: 100),
            startPoint: CGPoint(x: 400, y: 400),
            endPoint: CGPoint(x: 500, y: 500))

        ExpansionBoxView(box: box)
    }
}
