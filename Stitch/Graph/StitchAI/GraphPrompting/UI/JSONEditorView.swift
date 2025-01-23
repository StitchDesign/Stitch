//
//  JSONEditorView.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/21/25.
//

import SwiftUI
import SwiftyJSON

struct JSONEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var jsonString: String
    @State private var isValidJSON = true
    @State private var errorMessage: String? = nil
    @State private var hasCompleted = false
    private let completion: (String) -> Void
    
    init(initialJSON: String, completion: @escaping (String) -> Void) {
        let formattedJSON = Self.formatJSON(initialJSON)
        _jsonString = State(initialValue: formattedJSON)
        self.completion = completion
    }
    
    var body: some View {
        VStack {
            TextEditor(text: $jsonString)
                .font(.custom("Menlo", size: 13))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .background {
                    if !isValidJSON {
                        Color.red.opacity(0.2)
                            .cornerRadius(8)
                    } else {
                        Color.clear
                    }
                }
                .onChange(of: jsonString) { newValue in
                    // Replace smart quotes with standard quotes
                    jsonString = newValue
                        .replacingOccurrences(of: "“", with: "\"")
                        .replacingOccurrences(of: "”", with: "\"")
                    validateJSON(jsonString)
                }
                .padding()
            
            if !isValidJSON {
                Text(errorMessage ?? "Invalid JSON format")
                    .foregroundColor(.red)
                    .padding(.bottom)
            }
            
            Button(action: {
                completeAndDismiss(jsonString)
            }) {
                HStack {
                    Text("Send to Supabase")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isValidJSON ? Color.accentColor : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isValidJSON)
            .padding(.bottom)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    completeAndDismiss(jsonString)
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    completeAndDismiss(Self.minifyJSON(jsonString))
                }
                .disabled(!isValidJSON)
            }
        }
        .navigationTitle("Edit JSON")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if !hasCompleted {
                completeAndDismiss(jsonString)
            }
        }
    }
    
    private func validateJSON(_ jsonString: String) {
        let trimmedString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = trimmedString.data(using: .utf8) else {
            isValidJSON = false
            errorMessage = "Invalid UTF-8 encoding"
            return
        }
        
        do {
            _ = try JSONSerialization.jsonObject(with: jsonData, options: [])
            isValidJSON = true
            errorMessage = nil
        } catch {
            isValidJSON = false
            errorMessage = "Invalid JSON format: \(error.localizedDescription)"
        }
    }
    
    private func completeAndDismiss(_ json: String) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(json)
        dismiss()
    }
    
    private static func formatJSON(_ jsonString: String) -> String {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData),
              let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return jsonString
        }
        return prettyString
    }
    
    private static func minifyJSON(_ jsonString: String) -> String {
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData),
              let minData = try? JSONSerialization.data(withJSONObject: json),
              let minString = String(data: minData, encoding: .utf8) else {
            return jsonString
        }
        return minString
    }
}
