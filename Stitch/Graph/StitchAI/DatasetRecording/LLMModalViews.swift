//
//  LLMModalViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/27/25.
//

import SwiftUI

// Final approval modal
struct LLMApprovalModalView: View {
    
    let prompt: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Does this graph look correct?")
                .font(.headline)
            
            Text("Prompt: \(prompt)")
                .font(.subheadline)
            
            HStack {
                Button {
                    dispatch(ShowLLMEditModal())
                } label: {
                    Text("Edit")
                }
                
                Button {
                    dispatch(SubmitLLMActionsToSupabase())
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
