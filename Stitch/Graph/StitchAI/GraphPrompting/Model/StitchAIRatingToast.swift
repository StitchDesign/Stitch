//
//  StitchAIRatingToast.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/26/25.
//

import SwiftUI


enum StitchAIRating: CGFloat, Equatable, Hashable, CaseIterable {
    case oneStar = 0.0
    case twoStars = 0.25
    case threeStars = 0.5
    case fourStars = 0.75
    case fiveStars = 1.0
}

extension StitchAIRating {
    var isPerfectRating: Bool {
        self == .fiveStars
    }
    
    init?(_ int: Int) {
        switch int {
        case 1:
            self = .oneStar
        case 2:
            self = .twoStars
        case 3:
            self = .threeStars
        case 4:
            self = .fourStars
        case 5:
            self = .fiveStars
        default:
            fatalErrorIfDebug()
            if int > 5 {
                self = .fiveStars
            } else if int < 1 {
                self = .oneStar
            } else {
                return nil
            }
        }
    }
}

struct AIRatingSubmitted: StitchDocumentEvent {
    let rating: StitchAIRating
    
    func handle(state: StitchDocumentViewModel) {
        // Make Supabase request
        log("AIRatingSubmitted: rating: \(rating)")
                
        guard let deviceUUID = getDeviceUUID() else {
            log("AIRatingSubmitted error: no device ID found.")
            return
        }
        
        guard case .ratingToast(let userPrompt) = state.llmRecording.modal else {
            log("AIRatingSubmitted error: did not have rating toast")
            return
        }
        
        guard StitchStore.canShareAIData else {
            log("AIRatingSubmitted error: did not have user permission to share AI data")
            return
        }
        
        Task(priority: .high) { [weak state] in
            guard let state = state,
                  let aiManager = state.aiManager else {
                fatalErrorIfDebug("AIRatingSubmitted: Did not have AI Manager")
                return
            }
            
            do {
                // Write a row with the original rating and actions etc.
                // (Edit modal will later write a second row with a 5-star rating and different actions if the user chooses to submit a request)
                try await aiManager.uploadGraphGenerationInferenceCallResultToSupabase(
                    prompt: userPrompt,
                    finalActions: state.llmRecording.actions.map(\.toStep),
                    deviceUUID: deviceUUID,
                    tableName: aiManager.graphGenerationInferenceCallResultTableName,
                    requestId: state.llmRecording.requestIdFromCompletedRequest,
                    isCorrection: false,
                    rating: rating,
                    ratingExplanation: nil, // not provided yet
                    requiredRetry: false // not applicable
                )
            } catch {
                log("Could not upload rating to Supabase: \(error.localizedDescription)", .logToServer)
            }
            
            // If non-perfect rating, then
            // start augmentation mode, so user can issue a correction.
            if !rating.isPerfectRating {
                state.startLLMAugmentationMode()
            }
        }
                        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                if state.llmRecording.modal.isRatingToast {
                    log("AIRatingSubmitted: will hide modal")
                    state.llmRecording.modal = .none
                }
            }
        }
    }
}

struct AIRatingToastExpired: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // log("AIRatingToastExpired: state.llmRecording.modal is currently: \(state.llmRecording.modal)")
        
        if state.llmRecording.rating.isDefined || state.llmRecording.ratingFromPreviousExistingGraphSubmittedAsTrainingData.isDefined {
            log("AIRatingSubmitted error: we already rated this graph.")
            withAnimation {
                if state.llmRecording.modal.isRatingToast {
                    log("AIRatingToastExpired: will hide modal")
                    state.llmRecording.modal = .none
                }
            }
            return
        }
        
        guard let deviceUUID = getDeviceUUID() else {
            log("AIRatingSubmitted error: no device ID found.")
            return
        }
                
        // If we expired without rating, still upload the inference call to Supabase *so long as user has given permssion*
        if StitchStore.canShareAIData {
            Task(priority: .high) { [weak state] in
                guard let state = state,
                      let aiManager = state.aiManager else {
                    fatalErrorIfDebug("AIRatingToastExpired: Did not have AI Manager")
                    return
                }
                
                do {
                    // Write a row with the original rating and actions etc.
                    // (Edit modal will later write a second row with a 5-star rating and different actions if the user chooses to submit a request)
                    try await aiManager.uploadGraphGenerationInferenceCallResultToSupabase(
                        prompt: state.llmRecording.promptForTrainingDataOrCompletedRequest,
                        finalActions: state.llmRecording.actions.map(\.toStep),
                        deviceUUID: deviceUUID,
                        tableName: aiManager.graphGenerationInferenceCallResultTableName,
                        requestId: state.llmRecording.requestIdFromCompletedRequest,
                        isCorrection: false,
//                        rating: nil,
                        rating: .fiveStars, // TODO: is it really okay to assume a five-star rating here?
                        ratingExplanation: nil, // not provided yet
                        requiredRetry: false // not applicable
                    )
                } catch {
                    log("AIRatingToastExpired: Could not upload non-rated graph-gen inference call to Supabase: \(error.localizedDescription)", .logToServer)
                }
            }
        }
        
        
        withAnimation {
            if state.llmRecording.modal.isRatingToast {
                log("AIRatingToastExpired: will hide modal")
                state.llmRecording.modal = .none
            }
        }
    }
}

extension LLMRecordingState {
    var showRatingToast: Bool {
        self.modal.isRatingToast
    }
}

// See .toast usage in `ProjectsHomeView` as an example of Toast

struct StitchAIRatingToast: View {
    
    @State private var submitted: Bool = false
    @State private var show: Bool = true
    
    @State var currentRating: StitchAIRating?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(self.submitted ? "Thanks!" : "Rate Stitch AI Results")
            SelectAStitchAIRatingView(currentRating: self.$currentRating) { (rating: StitchAIRating) in
                self.submitted = true
                dispatch(AIRatingSubmitted(rating: rating))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation {
                        self.show = false
                    }
                }
            }
        } // VStack
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
        .opacity(show ? 1 : 0)
    }
}

struct SelectAStitchAIRatingView: View {
    
    @Binding var currentRating: StitchAIRating?
    var onRatingSelected: (StitchAIRating) -> Void
    
    var body: some View {
        StitchAIRatingStarsView(currentRating: currentRating) { (rating: StitchAIRating) in
            self.currentRating = rating
            self.onRatingSelected(rating)
        }  // HStack
    }
}


struct StitchAIRatingStarsView: View {
    
    var currentRating: StitchAIRating?
    var onTap: ((StitchAIRating) -> Void)?
    
    var body: some View {
        HStack {
            ForEach(StitchAIRating.allCases, id: \.self) { rating in
                let fill = currentRating.map { rating.rawValue <= $0.rawValue } ?? false
                Image(systemName: fill ? "star.fill" : "star")
                    .onTapGesture {
                        self.onTap?(rating)
                    }
            } // ForEach
        }  // HStack
    }
}
