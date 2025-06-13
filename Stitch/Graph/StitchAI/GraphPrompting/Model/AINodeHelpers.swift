//
//  AINodeHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/25.
//

import SwiftUI


extension String {
    static let CREATE_CUSTOM_NODE_WITH_AI = "Create Node"
}

struct AINodePromptEntryModalView: View {
    
    @Bindable var document: StitchDocumentViewModel
    
    @State var userPrompt: String = ""
    
    func entryCancelled() {
        self.document.llmRecording.modal = .none
    }
    
    func submitted() {
        document.aiNodePromptSubmitted(userPrompt: self.userPrompt)
        document.llmRecording.modal = .none
    }
    
    var body: some View {
        
        VStack(spacing: 16) {
            StitchTextView(string: "Create a Custom Node with AI",
                           font: .title3.weight(.semibold))
            
            TextField("What should your node do?",
                      text: self.$userPrompt)
            .padding(4)
            .background {
                Color.EXTENDED_FIELD_BACKGROUND_COLOR.cornerRadius(8)
            }
            .onAppear(perform: {
                // So that `CMD+A: select all` works in this text field
                dispatch(ReduxFieldFocused(focusedField: .aiNodePrompt))
            })
            .onSubmit {
                log("text field submit called")
                if self.userPrompt.isEmpty {
                    self.entryCancelled()
                } else {
                    self.submitted()
                }
            }
            
            HStack(spacing: 18) {
                Button("Cancel", role: .cancel) {
                    self.entryCancelled()
                }
                
                Button("Submit") {
                    self.submitted()
                }
                .disabled(self.userPrompt.isEmpty)
            }
           
        } // VStack
        .frame(maxWidth: 400)
        .padding(16)
        
#if targetEnvironment(macCatalyst)
        .background(.regularMaterial)
#else
        .background(.thinMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray)
        }
#endif
        .cornerRadius(8)
    }
}


struct ShowAINodePromptEntryModal: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        state.llmRecording.modal = .aiNodePromptEntry
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func aiNodePromptSubmitted(userPrompt: String) {
        
        let document = self
        
        // On submit, create a javascript node
        let aiNode = document.nodeInserted(choice: .patch(.javascript))
        guard let aiPatchNode = aiNode.patchNode else {
            fatalErrorIfDebug()
            return
        }
                
        aiPatchNode.canvasObserver.isLoading = true
        
        document.graph.updateGraphData(document)
        
        
        do {
            guard let secrets: Secrets = document.aiManager?.secrets else {
                throw StitchAIManagerError.secretsNotFound
            }
            
            let jsAIRequest = AIEditJSNodeRequest(
                prompt: userPrompt,
                secrets: secrets,
                nodeId: aiNode.id)
            
            Task { [weak aiPatchNode, weak document] in
                guard let aiPatchNode = aiPatchNode,
                      let document = document,
                      let aiManager = document.aiManager else {
                    return
                }
                
                // TODO: move to a `willRequest` for the Javascript Request ?
                willRequest_SideEffect(
                    userPrompt: jsAIRequest.userPrompt,
                    requestId: jsAIRequest.id,
                    document: document,
                    canShareData: StitchStore.canShareAIData,
                    userPromptTableName: nil)
                                    
                let result = await jsAIRequest.request(document: document,
                                                       aiManager: aiManager)
                
                switch result {
                
                case .success(let jsSettings):
                    log("success: jsSettings: \(jsSettings)")
                    
                    // TODO: are we not catching this potential error? Swift compiler is not detecting that within the Task ?
                    try await aiManager.uploadJavascriptCallResultToSupabase(
                        userPrompt: jsAIRequest.userPrompt,
                        requestId: jsAIRequest.id,
                        javascriptSettings: jsSettings)
                    
                    aiPatchNode.canvasObserver.isLoading = false
                    
                    // Process the new Javascript settings
                    aiPatchNode.processNewJavascript(response: jsSettings,
                                                     document: document)
                    
                    document.graph.updateGraphData(document)
                    
                case .failure(let error):
                    log("failure: error: \(error)")
                    fatalErrorIfDebug(error.description)
                }
            }
        } catch {
            log("javascriptNodeField error: \(error.localizedDescription)")
        }
    }
}
