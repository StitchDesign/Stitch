//
//  StitchAIProjectViewer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/23/25.
//

import SwiftUI
import StitchSchemaKit

struct StitchAIProjectViewer: View {
    // Encoder needs a strong reference somewhere to enable the fake document view model
    @State private var encoder: DocumentEncoder
    @State private var document: StitchDocumentViewModel
    @State private var aiJsonPrompt: String
    
    let store: StitchStore
    
    init(store: StitchStore) {
        let document = StitchDocument()
        let encoder = DocumentEncoder(document: document,
                                       disableSaves: true)
        self.document = StitchDocumentViewModel.createEmpty(document: document,
                                                            encoder: encoder)
        self.encoder = encoder
        self.aiJsonPrompt = ""
        self.store = store
    }

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
                TextField("Graph from AI Response", text: $aiJsonPrompt)
                    .onSubmit {
                        validateAiJsonActions()
                    }
                
                Spacer()
            }
        }
    }
}
