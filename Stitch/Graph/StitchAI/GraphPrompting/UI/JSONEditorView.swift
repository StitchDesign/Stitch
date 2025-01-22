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
    @State private var hasCompleted = false
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
                    //validateJSON(newValue)
                }
            
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
        .padding()
        .onDisappear {
            if !hasCompleted {
                completeAndDismiss(jsonString)
            }
        }
    }
    
//    private func validateJSON(_ jsonString: String) {
//        guard let jsonData = jsonString.data(using: .utf8) else {
//            isValidJSON = false
//            errorMessage = "Invalid UTF-8 encoding"
//            return
//        }
//
//        do {
//            let decoder = JSONDecoder()
//            _ = try decoder.decode(LLMStepActions.self, from: jsonData)
//            
//            isValidJSON = true
//            errorMessage = nil
//        } catch let decodingError as DecodingError {
//            isValidJSON = false
//            switch decodingError {
//            case .keyNotFound(let key, let context):
//                errorMessage = "Missing key: \(key.stringValue) in \(context.codingPath.map { $0.stringValue }.joined(separator: " > "))"
//            case .typeMismatch(let type, let context):
//                errorMessage = "Type mismatch: Expected \(type) in \(context.codingPath.map { $0.stringValue }.joined(separator: " > "))"
//            case .valueNotFound(let type, let context):
//                errorMessage = "Value not found: Expected \(type) in \(context.codingPath.map { $0.stringValue }.joined(separator: " > "))"
//            case .dataCorrupted(let context):
//                errorMessage = "Data corrupted: \(context.debugDescription)"
//            @unknown default:
//                errorMessage = "Unknown decoding error"
//            }
//        } catch {
//            isValidJSON = false
//            errorMessage = "Invalid JSON format: \(error.localizedDescription)"
//        }
//    }

//    private func sendToSupabase() async {
//        do {
//            try await SupabaseManager.shared.uploadEditedLLMRecording(jsonString)
//        } catch {
//            print("Failed to upload the edited LLM recording: \(error.localizedDescription)")
//        }
//    }
    
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
