//
//  StitchAIProjectViewer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/23/25.
//

import SwiftUI
import StitchSchemaKit

extension StitchStore {
    @MainActor
    func createAIDocumentPreviewer() -> (StitchDocumentViewModel, DocumentEncoder) {
        let document = StitchDocument()
        let encoder = DocumentEncoder(document: document,
                                      disableSaves: true)
        let documentViewModel = StitchDocumentViewModel
            .createEmpty(document: document,
                         encoder: encoder,
                         store: self)
        
        return (documentViewModel, encoder)
    }
}

struct StitchAIProjectViewer: View {
    @FocusedValue(\.focusedField) private var focusedField
    @State private var swiftUICode = ""
    
    let store: StitchStore
    @Bindable var document: StitchDocumentViewModel

    func validateJSON() {        
        let codeParserResult = SwiftUIViewVisitor.parseSwiftUICode(swiftUICode)
        
        // Syntax → Actions
        var stitchActionsResult = codeParserResult.deriveStitchActions(bindingDeclarations: codeParserResult.bindingDeclarations)
        
        // Apply AI result to fake document
        Task(priority: .high) {
            await stitchActionsResult
                .createAIGraph(document: document)
        }
    }
    
    var body: some View {
        
        ZStack {
            StitchProjectView(store: store,
                              document: document,
                              alertState: store.alertState)
            VStack {
                HStack {
                    TextField("Insert SwiftUI Code",
                              text: $swiftUICode)
                    .focusedValue(\.focusedField, .aiPreviewerTextField)
                    .onSubmit {
                        validateJSON()
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
            }
        }
    }
}
