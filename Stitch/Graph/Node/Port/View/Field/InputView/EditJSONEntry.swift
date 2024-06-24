//
//  EditJSONView.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/14/21.
//

import SwiftUI
import SwiftyJSON
import StitchSchemaKit

let JSON_BRACKET_SF_SYMBOL = "curlybraces.square"

struct EditJSONEntry: View {
    @FocusedValue(\.focusedField) private var focusedField
    @State var internalEditString: String = ""

    let coordinate: InputCoordinate
    let json: StitchJSON? // nil helps with perf?

    @State var properJson = true
    @State var isOpen = false

    @Binding var isPressed: Bool

    var body: some View {
        FieldButtonImage(sfSymbolName: JSON_BRACKET_SF_SYMBOL)
            .popover(isPresented: $isOpen) {
                TextEditor(text: $internalEditString)
                    .focusedValue(\.focusedField, .textInput(coordinate.toSingleFieldCoordinate))
                    .font(STITCH_FONT)
                    .scrollContentBackground(.hidden)
                    .background {
                        properJson
                            ? EmptyView().eraseToAnyView()
                            : StitchTextView(
                                string: "Improperly formatted JSON",
                                fontColor: .red)
                            .opacity(0.5)
                            .eraseToAnyView()
                    }

                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .frame(width: 200, height: 200)
                    .padding()
                    .onAppear {
                        internalEditString = json?.display ?? ""
                        properJson = true
                    }
                    // for when eg we've tapped the graph,
                    // thus defocusing this field
                    .onDisappear {
                        // log("EditJsonEntry: TextEditor: onDisappear")

                        // Only commit if we have a JSON edit which is valid and not equivalent to existing json.
                        if let json = json?.value,
                           let edit = getCleanedJSON(internalEditString),
                           !areEqualJsons(edit, json) {

                            dispatch(JsonEditCommitted(coordinate: coordinate,
                                                       json: edit))
                        }
                    }
                    .onChange(of: internalEditString) { newValue in
                        log("onChange of internalEditString: ")
                        if !getCleanedJSON(newValue).isDefined {
                            properJson = false
                        } else {
                            properJson = true
                        }
                    }
            } // popover
            .onTapGesture {
                self.isOpen.toggle()
                self.isPressed = true
            }
            .onAppear {
                internalEditString = json?.display ?? ""
            }
            .onChange(of: json) { newJSON in
                internalEditString = newJSON?.display ?? ""
            }
    } // body
}
