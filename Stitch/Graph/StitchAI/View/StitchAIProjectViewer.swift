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
    @State private var aiJsonPrompt = ""
    
    let store: StitchStore
    let document: StitchDocumentViewModel

    func validateAiJsonActions() {
        // Reset previous state
        document.graph.update(from: .createEmpty())
        
        let data = self.aiJsonPrompt.data(using: .utf8)!
        let steps = try! getStitchDecoder().decode(LLMStepActions.self,
                                                   from: data)
        
//        print("setps: \(steps)")
        
        try! document.validateAndApplyActions(steps,
                                              isNewRequest: true)
    }
    
    var body: some View {
        
        ZStack {
            StitchProjectView(store: store,
                              document: document,
                              alertState: store.alertState)

            VStack {
                HStack {
                    TextField("Insert array of JSON actions...",
                              text: $aiJsonPrompt)
                    .focusedValue(\.focusedField, .aiPreviewerTextField)
                    .onSubmit {
                        validateAiJsonActions()
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
            }
        }
    }
}
