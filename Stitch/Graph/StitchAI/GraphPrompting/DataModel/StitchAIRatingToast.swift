//
//  StitchAIRatingToast.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/26/25.
//

import SwiftUI


enum StitchAIRating: CGFloat, Equatable, Hashable {
    case oneStar = 0.0
    case twoStars = 0.25
    case threeStars = 0.5
    case fourStars = 0.75
    case fiveStars = 1.0
}

extension StitchAIRating {
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
        // fatalErrorIfDebug()
                
        guard let deviceUUID = StitchAIManager.getDeviceUUID() else {
            log("AIRatingSubmitted error: no device ID found.")
            return
        }
        
        guard case .ratingToast(let userPrompt) = state.llmRecording.modal else {
            log("AIRatingSubmitted error: did not have rating toast")
            return
        }
        
        Task(priority: .high) { [weak state] in
            guard let state = state,
                  let aiManager = state.aiManager else {
                fatalErrorIfDebug("AIRatingSubmitted: Did not have AI Manager")
                return
            }
            
            do {
                try await aiManager.uploadActionsToSupabase(
                    prompt: userPrompt,
                    finalActions: state.llmRecording.actions.map(\.toStep),
                    deviceUUID: deviceUUID,
                    isCorrection: false,
                    rating: rating,
                    requiredRetry: false)
            } catch {
                log("Could not upload rating to Supabase: \(error.localizedDescription)", .logToServer)
            }
        }
                        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            withAnimation {
                if state.llmRecording.modal.isRatingToast {
                    log("AIRatingSubmitted: will hide modal")
                    state.llmRecording.modal = .none
                }
            }
        }
    }
}

struct AIRatingToastExpiredWithoutRating: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // log("AIRatingToastExpiredWithoutRating: state.llmRecording.modal is currently: \(state.llmRecording.modal)")
        withAnimation {
            if state.llmRecording.modal.isRatingToast {
                log("AIRatingToastExpiredWithoutRating: will hide modal")
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
    
    @State var tappedStar: Int?
    
    // TODO: make var on document
    @State var show: Bool = true
    
    var body: some View {
        VStack(spacing: 8) {
            Text(self.tappedStar != nil ? "Thanks!" : "Rate results")
            HStack {
                ForEach(1...5, id: \.self) { starNumber in
                    
                    let fill = tappedStar.map { starNumber <= $0 } ?? false
                    
                    Image(systemName: fill ? "star.fill" : "star")
                        .onTapGesture(perform: {
                            self.tappedStar = starNumber
                            
                            if let rating = StitchAIRating(starNumber) {
                                dispatch(AIRatingSubmitted(rating: rating))
                            } else {
                                fatalErrorIfDebug()
                            }
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation {
                                    self.show = false
                                }
                            }
                        })
                } // ForEach
            }  // HStack
        } // VStack
        .padding()
        .background(.regularMaterial)
        .cornerRadius(8)
        .opacity(show ? 1 : 0)
    }
}
