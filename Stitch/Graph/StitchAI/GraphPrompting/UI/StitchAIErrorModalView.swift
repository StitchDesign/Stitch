//
//  StitchAIErrorModalView.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/14/24.
//

import SwiftUI

struct StitchAIErrorModalView: View {
    var message: String
    var userPrompt: String
    var jsonResponse: String?
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Error")
                .font(.title)
                .bold()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Message: \(message)")
                    Text("User Prompt: \(userPrompt)")
                    Text("Response: \(jsonResponse ?? "No JSON Response")")
                }
                .padding()
            }
            
            HStack {
                Button("Copy") {
                    UIPasteboard.general.string = """
                    Message: \(message)
                    User Prompt: \(userPrompt)
                    Response: \(jsonResponse ?? "No JSON Response")
                    """
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(DefaultButtonStyle())
                
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(DefaultButtonStyle())
            }
        }
        .padding()
    }
}
