//
//  EditJSONView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/14/21.
//

import SwiftUI
import SwiftyJSON
import StitchSchemaKit

let JSON_BRACKET_SF_SYMBOL = "curlybraces.square"

struct EditJSONEntry: View {
    @FocusedValue(\.focusedField) private var focusedField
    @State private var internalEditString: String = ""
    @State private var properJson = true
    @State private var isOpen = false

    @Bindable var graph: GraphState
    let coordinate: FieldCoordinate
    let rowObserverCoordinate: NodeIOCoordinate
    let json: StitchJSON? // nil helps with perf?
    let isSelectedInspectorRow: Bool
    @Binding var isPressed: Bool

    var body: some View {
        FieldButtonImage(sfSymbolName: JSON_BRACKET_SF_SYMBOL,
                         isSelectedInspectorRow: isSelectedInspectorRow)
            .popover(isPresented: $isOpen) {
                TextEditor(text: $internalEditString)
                    .focusedValue(\.focusedField, .textInput(coordinate))
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
                            
                            graph.handleInputEditCommitted(
                                input: rowObserverCoordinate,
                                value: .json(edit.toStitchJSON),
                                // TODO: currently we never use json input for a layer input; but should pass down proper values here
                                isFieldInsideLayerInspector: false,
                                // TODO: technically not a dropdown, but not a regular textfield entry either
                                wasDropdown: true)
                            
                            // TODO: clean up this, use same functions as `inputEdited` etc.?
                            graph.encodeProjectInBackground()
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
