//
//  StitchAIErrorModalView.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/14/24.
//

import SwiftUI


extension StitchDocumentViewModel {
    @MainActor
    func showErrorModal(message: String,
                        userPrompt: UserAIPrompt) {
        if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
            let hostingController = UIHostingController(rootView: StitchAIErrorModalView(
                message: message,
                userPrompt: userPrompt
            ))
            rootViewController.present(hostingController, animated: true, completion: nil)
        }
    }
}

struct StitchAIErrorModalView: View {
    var message: String
    var userPrompt: UserAIPrompt
    
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
//                    Text("Response: \(jsonResponse ?? "No JSON Response")")
                }
                .padding()
            }
            
            HStack {
                Button("Copy") {
                    let textToCopy = "Message: \(message)\nUser Prompt: \(userPrompt)"
                    UIPasteboard.general.setValue(textToCopy, forPasteboardType: "public.utf8-plain-text")
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
