//
//  LLMModalViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/27/25.
//

import SwiftUI

// TODO: can we get rid of this step/view/modal ? User can scroll around the graph just fine with the "Edit Before Submit" modal.
// Final approval modal
struct ApproveAndSubmitModalView: View {
    
    let prompt: UserAIPrompt?
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Does this graph look correct?")
                .font(.headline)
            
            Text("Prompt: \(prompt?.value ?? "")")
                .font(.subheadline)
            
            HStack {
                Button {
                    dispatch(ShowEditBeforeSubmitModal())
                } label: {
                    Text("Edit")
                }
                
                Button {
                    dispatch(ActionsApprovedAndSubmittedToSupabase())
                } label: {
                    Text("Upload") // "Send to Supabase"
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding()
    }
}
