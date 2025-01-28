//
//  LLMModalViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/27/25.
//

import SwiftUI

// Final approval modal
struct LLMApprovalModalView: View {
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Does this graph look correct?")
                .font(.headline)
            
            HStack {
                Button {
                    dispatch(ShowLLMEditModal())
                } label: {
                    Text("Add More")
                }
                
                Button {
                    // dispatch(ShowLLMEditModal())
                    // Actually submit to Supabase here
                    // call the logic in `SupabaseManager.uploadLLMRecording`
                    dispatch(SubmitLLMActionsToSupabase())
                } label: {
                    Text("Submit") // "Send to Supabase"
                }
            }
            
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(16)
        .padding()
    }
}
