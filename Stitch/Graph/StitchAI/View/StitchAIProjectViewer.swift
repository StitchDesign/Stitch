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
    @Bindable var document: StitchDocumentViewModel

    func validateJSON() {
        // Reset previous state
        document.graph.update(from: .createEmpty())
        let data = self.aiJsonPrompt.data(using: .utf8)!
        let steps: Steps = try! getStitchDecoder().decode(LLMStepActions.self, from: data)
        let stepActions: [any StepActionable] = steps.map { $0.parseAsStepAction().value! }
        log("StitchAIProjectViewer: validateJSON: steps: \(steps)")
        log("StitchAIProjectViewer: validateJSON: stepActions: \(stepActions)")
        if let validationError = document.validateAndApplyActions(stepActions) {
            fatalErrorIfDebug("StitchAIProjectViewer: validateJSON: validationError: \(validationError.description)")
        }
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
