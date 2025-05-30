//
//  AITrainingExampleFromExistingGraph.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/29/25.
//

import SwiftUI


// A user's
struct UserAIPrompt: Equatable, Hashable {
    var value: String
    
    init(_ string: String) {
        self.value = string
    }
}

struct ExistingGraphAsTrainingExample: Equatable, Hashable {
    var graph: GraphEntity
    var prompt: UserAIPrompt
    var rating: StitchAIRating
}

struct ExistingGraphSubmittedAsTrainingExample: StitchDocumentEvent {
    
    let prompt: UserAIPrompt
    let rating: StitchAIRating
    
    func handle(state: StitchDocumentViewModel) {

        // Create actions from the existing graph
        
        let existingGraph = state.visibleGraph
        
        // a pseudo-"empty graph"
        // TODO: can we use `.createEmpty` or do we need the graph id and graph name to be the same?
        let emptyGraph: GraphEntity = .init(id: existingGraph.id.value,
                                            name: existingGraph.name,
                                            nodes: .init(),
                                            orderedSidebarLayers: .init(),
                                            commentBoxes: .init())
        
        let actionsFromExistingGraph = StitchDocumentViewModel.deriveNewAIActions(
            oldGraphEntity: emptyGraph, // Start with an empty one
            visibleGraph: state.visibleGraph)

        state.llmRecording.actions = actionsFromExistingGraph
        
        state.llmRecording.promptForTrainingDataOrCompletedRequest = prompt
        state.llmRecording.rating = rating
        
        // Shows the edit modal, BUT DOES NOT put us into "correction mode" (i.e. we're not correcting a response from OpenAI).
        // User will then review the actions via the 'edit before submit' and 'approve and submit' modals before final submission to Supabase.
        state.showEditBeforeSubmitModal()
    }
}

struct ShowCreateTrainingDataFromExistingGraphModal: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        state.llmRecording.modal = .submitExistingGraphAsTrainingExample
    }
}

struct SubmitExistingGraphAsTrainingExampleModalView: View {
    
    let promptFromPreviousExistingGraphSubmittedAsTrainingData: UserAIPrompt?
    
    @State var prompt: String = ""
    @State var rating: StitchAIRating? = nil
  
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            enterPrompt
            enterRating
            cancelOrSubmit
        }
        .frame(width: 340)
        .padding()
        
#if targetEnvironment(macCatalyst)
        .background(.regularMaterial)
#else
        .background(.ultraThickMaterial)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray)
        }
#endif
        
        .cornerRadius(8)
        .onAppear {
            if let existingPrompt = self.promptFromPreviousExistingGraphSubmittedAsTrainingData {
                self.prompt = existingPrompt.value
            }
        }
    }
    
    
    var enterPrompt: some View {
        HStack {
            StitchTextView(string: "Prompt: ")
            TextField("", text: self.$prompt)
                .frame(width: 260)
                .padding(6)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray)
                }
        }
    }
    
    var enterRating: some View {
        HStack {
            StitchTextView(string: "Rating: ")
            SelectAStitchAIRatingView { (rating: StitchAIRating) in
                self.rating = rating
            }
        }
    }
    
    var cancelOrSubmit: some View {
        HStack {

            Spacer()
            
            Button(action: {
                dispatch(StitchAIActionReviewCancelled())
            }, label: {
                Text("Cancel")
            })
            .buttonStyle(.bordered)
            
            Button(action: {
                if let rating = rating {
                    dispatch(ExistingGraphSubmittedAsTrainingExample(
                        prompt: .init(self.prompt),
                        rating: rating))
                }
            }, label: {
                Text("Submit")
            })
            .disabled(prompt.isEmpty && !rating.isDefined)
            .buttonStyle(.bordered)
            
            Spacer()
            
        }
        
        // TODO: HStack with Spacers on a parent with fixed width = put child in center; can we `.alignmentGuide` to center instead?
        // https://holyswift.app/the-basics-of-swiftui-alignment-guides/
        
//            .alignmentGuide(.leading) { dimensions in
//                dimensions.width / 2
//            }
    }
    
}
