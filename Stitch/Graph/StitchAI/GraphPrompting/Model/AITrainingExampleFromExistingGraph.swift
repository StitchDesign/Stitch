//
//  AITrainingExampleFromExistingGraph.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/29/25.
//

import SwiftUI


struct ExistingGraphSubmittedAsTrainingExample: StitchDocumentEvent {
    
    let prompt: String
    let ratingExplanation: String
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
        
        // Note: we do NOT provide a request_id for the freshly-created training examples
        // state.llmRecording.requestIdFromCompletedRequest = nil
        
        state.llmRecording.rating = rating
        
        // Just submit to Supabase right away
        state.submitApprovedActionsToSupabase(
            ratingForExistingGraph: rating,
            explanationForRatingForExistingGraph: ratingExplanation)
    }
}

struct ShowCreateTrainingDataFromExistingGraphModal: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        state.llmRecording.modal = .submitExistingGraphAsTrainingExample
    }
}

struct SubmitExistingGraphAsTrainingExampleModalView: View {
    
    let promptFromPreviousExistingGraphSubmittedAsTrainingData: String?
    let ratingFromPreviousExistingGraphSubmittedAsTrainingData: StitchAIRating?
    
    @State var prompt: String = ""
    @State var ratingExplanation: String = ""
    @State var currentRating: StitchAIRating? = nil
  
    var body: some View {
        
        VStack(alignment: .leading, spacing: 12) {
            enterPrompt
            enterRating
            enterRatingExplanation
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
                self.prompt = existingPrompt
            }
            if let existingRating = self.ratingFromPreviousExistingGraphSubmittedAsTrainingData {
                self.currentRating = existingRating
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
            SelectAStitchAIRatingView(currentRating: self.$currentRating) { (rating: StitchAIRating) in
                // TODO: no longer necessary now that we're passing down the binding; clean up this view a bit
                self.currentRating = rating
            }
        }
    }
    
    var enterRatingExplanation: some View {
        HStack {
            StitchTextView(string: "Why?: ")
            TextField("", text: self.$ratingExplanation)
                .frame(width: 260)
                .padding(6)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray)
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
                if let rating = currentRating {
                    dispatch(ExistingGraphSubmittedAsTrainingExample(
                        prompt: .init(self.prompt),
                        ratingExplanation: self.ratingExplanation,
                        rating: rating))
                }
            }, label: {
                Text("Submit")
            })
            .disabled(prompt.isEmpty || !currentRating.isDefined || ratingExplanation.isEmpty)
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
