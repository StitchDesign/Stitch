//
//  StitchAIProjectViewer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/23/25.
//

import SwiftUI
import StitchSchemaKit

struct StitchAIProjectViewer: View {
    @State private var document = StitchDocumentViewModel.createEmpty()
    @State private var aiJsonPrompt = ""
    
    let store: StitchStore

    func validateAiJsonActions() {
        // Reset previous state
        document.graph.update(from: .createEmpty())
        
        let data = self.aiJsonPrompt.data(using: .utf8)!
        let steps = try! getStitchDecoder().decode(LLMStepActions.self,
                                                   from: data)
        
        print("setps: \(steps)")
        
        try! document.aiManager?.openAIRequestCompleted(steps: steps,
                                                        originalPrompt: "")
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
