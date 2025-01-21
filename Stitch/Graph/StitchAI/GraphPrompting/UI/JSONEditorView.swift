//
//  JSONEditorView.swift
//  Stitch
//

import SwiftUI
import SwiftyJSON

struct JSONEditorView: View {
    @Environment(\.dismiss) var dismiss
    @State private var jsonString: String
    @State private var isValidJSON = true
    @State private var isSubmitting = false
    @State private var errorMessage: String? = nil
    private let completion: (String) -> Void
    
    init(initialJSON: String, completion: @escaping (String) -> Void) {
        // Format the JSON string nicely before displaying
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
                        StitchTextView(
                            string: errorMessage ?? "Improperly formatted JSON",
                            fontColor: .red)
                        .opacity(0.5)
                    }
                }
                .onChange(of: jsonString) { newValue in
                    validateJSON(newValue)
                }
            
            if !isValidJSON {
                Text(errorMessage ?? "Invalid JSON format")
                    .foregroundColor(.red)
                    .padding(.bottom)
            }
            
            Button(action: {
                Task {
                    await sendToSupabase()
                }
            }) {
                HStack {
                    Text("Send to Supabase")
                    if isSubmitting {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .disabled(!isValidJSON || isSubmitting)
            .padding(.bottom)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    // Minify JSON before saving
                    let minifiedJSON = Self.minifyJSON(jsonString)
                    completion(minifiedJSON)
                    dismiss()
                }
                .disabled(!isValidJSON)
            }
        }
        .navigationTitle("Edit JSON")
        .navigationBarTitleDisplayMode(.inline)
        .padding()
        .onAppear {
            validateJSON(jsonString)
        }
    }
    
    private func validateJSON(_ jsonString: String) {
        if let jsonData = jsonString.data(using: .utf8) {
            do {
                let json = try JSON(data: jsonData)
                
                // Print the JSON for debugging purposes
                print("Parsed JSON: \(json)")
                
                // Check if the JSON is valid and has the expected structure
                if json.type == .dictionary {
                    if let actionsArray = json["actions"].array {
                        // Convert each action in the array to LLMStepAction
                        var stepActions: [LLMStepAction] = []
                        
                        for actionJson in actionsArray {
                            if let stepType = actionJson["stepType"].string,
                               let nodeId = actionJson["nodeId"].string {
                                
                                // Create LLMStepAction with required fields
                                let stepAction = LLMStepAction(
                                    stepType: stepType,
                                    nodeId: nodeId,
                                    nodeName: actionJson["nodeName"].string,
                                    port: actionJson["port"].string.map { .init(value: $0) }, fromPort: actionJson["fromPort"].string.map { .init(value: $0) }, fromNodeId: actionJson["fromNodeId"].string, toNodeId: actionJson["toNodeId"].string, value: actionJson["value"].exists() ? JSONFriendlyFormat(value: actionJson["value"].rawValue as! PortValue) : nil, nodeType: actionJson["nodeType"].string
                                )
                                
                                stepActions.append(stepAction)
                            }
                        }
                        
                        if !stepActions.isEmpty {
                            isValidJSON = true
                            errorMessage = nil
                            return
                        }
                    }
                    
                    isValidJSON = false
                    errorMessage = "JSON must contain an array of valid step actions"
                } else {
                    isValidJSON = false
                    errorMessage = "JSON must be an object with 'actions' array"
                }
            } catch {
                print("Error parsing JSON: \(error)")
                isValidJSON = false
                errorMessage = "Invalid JSON format: \(error.localizedDescription)"
            }
        } else {
            isValidJSON = false
            errorMessage = "Invalid UTF-8 encoding"
        }
    }
    
    private func sendToSupabase() async {
            
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
