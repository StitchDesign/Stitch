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
    @FocusState private var isFocused: Bool
    @State private var userPrompt: String = ""
    
    @Bindable var document: StitchDocumentViewModel
    
    func entryCancelled() {
        self.document.llmRecording.modal = .none
    }
    
    func submitted() {
        document.aiNodePromptSubmitted(userPrompt: self.userPrompt)
        document.llmRecording.modal = .none
    }
        
    var body: some View {
        ZStack(alignment: .top) {
            
            ModalBackgroundGestureRecognizer(dismissalCallback: { self.entryCancelled() }) {
                Color.clear
            }
            
            // Insert Node Menu view
            aiPromptyEntryView
                .frame(width: InsertNodeMenuWithModalBackground.menuWidth)
                    .shadow(radius: 4)
                    .shadow(radius: 8, x: 4, y: 2)
                    
                #if targetEnvironment(macCatalyst)
                // Padding from top, per Figma
                    .offset(y: 24)
                #else
                // TODO: why does this differ for Catalyst vs iPad ?
//                    .offset(y: 48)
//                    .offset(y: 12)
                    .offset(y: 8)
                    .offset(y: document.visibleGraph.graphYPosition)
                #endif
                
                // Preserve position when we've collapsed the node menu body because of an active AI request
                // Alternatively?: use VStack { menu, Spacer }
                    .offset(y: INSERT_NODE_MENU_SEARCH_BAR_HEIGHT/2)
        }
    }
    
    var aiPromptyEntryView: some View {
        
        TextField("What should your node do?", text: self.$userPrompt)
            .focused($isFocused)
            .frame(height: INSERT_NODE_MENU_SEARCH_BAR_HEIGHT)
            .padding(.leading, 16)
            .padding(.trailing, 60)
            .overlay(alignment: .center) {
                rightSideButton
            }
            .font(.system(size: 24))
            .onAppear(perform: {
                self.isFocused = true
                
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
            .background(INSERT_NODE_SEARCH_BACKGROUND)
            .foregroundColor(INSERT_NODE_MENU_SEARCH_TEXT)
            .cornerRadius(InsertNodeMenuWithModalBackground.shownMenuCornerRadius)
    }
    
    var rightSideButton: some View {
        HStack {
            Button(action: {
                // Helps to defocus the .focusedValue, ensuring our shortcuts like "CMD+A Select All" is enabled again.
                self.submitted()
            }, label: {
                Image(systemName: "plus.app")
            })
            .frame(width: 36, height: 36)
            .buttonStyle(.borderless)
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
        }
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
