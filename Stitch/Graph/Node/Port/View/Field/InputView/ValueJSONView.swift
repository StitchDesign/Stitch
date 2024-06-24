//
//  ValueJSONView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/14/23.
//

import SwiftUI
import StitchSchemaKit

// For viewing a json, but not editing it
// (eg an output)
struct ValueJSONView: View {
    @FocusedValue(\.focusedField) private var focusedField
    let coordinate: OutputCoordinate
    let json: StitchJSON?

    var id: NodeId {
        coordinate.nodeId
    }

    @Binding var isPressed: Bool

    var body: some View {
        FieldButtonImage(sfSymbolName: JSON_BRACKET_SF_SYMBOL)
            .popover(isPresented: $isPressed) {
                /*
                 NOTE 1: TextEditor seems to be the best solution for a scrollable multiline text.
                 Various combinations of ScrollView + VStack.frame + Text/TextField.fixedSize(vertical: true) have been recommended but do no seem to work:
                 ScrollView {
                 VStack {
                 TextField(axis: .vertical)
                 .lineLimit(nil)
                 .fixedSize(horizontal: false, vertical: true)
                 }.frame(width: 200, height: 200)
                 }
                 ^^ this does not work very well

                 NOTE 2: By providing a .constant binding, we can select values in the field but not edit them.
                 */
                TextEditor(text: .constant(json?.display ?? .empty))
                    .focusedValue(\.focusedField, .jsonPopoverOutput(coordinate))
                    .font(STITCH_FONT)
                    .frame(width: 200, height: 200)
                    .scrollContentBackground(.hidden)
                    .padding()
            }
            .onTapGesture {
                self.isPressed = true
            }
            .frame(width: NODE_INPUT_OR_OUTPUT_WIDTH,
                   alignment: .trailing)
    }
}

struct ValueJSONView_Previews: PreviewProvider {
    static var previews: some View {
        //        ValueJSONView(json: JSON(parseJSON: sampleMoveToJSON),
        ValueJSONView(coordinate: .fakeOutputCoordinate,
                      json: .init(.init(parseJSON: "{\"path\": 0}")),
                      isPressed: .constant(true))
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
