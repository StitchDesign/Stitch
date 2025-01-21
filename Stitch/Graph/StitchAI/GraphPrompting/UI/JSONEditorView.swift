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
                // Check if the JSON is valid and has the expected structure
                if json.type == .dictionary {
                    let actions = json["actions"]
                    if actions.type == .dictionary {
                        isValidJSON = true
                        errorMessage = nil
                        return
                    }
                }
                isValidJSON = false
                errorMessage = "JSON must be an object with 'actions' dictionary"
            } catch {
                print("editing json")
            }
        } else {
            isValidJSON = false
            errorMessage = "Invalid UTF-8 encoding"
        }
    }
    
    private func sendToSupabase() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            // Validate and re-encode the JSON string before sending
            guard let jsonData = jsonString.data(using: .utf8),
                  let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
                  let reencodedJSONData = try? JSONSerialization.data(withJSONObject: jsonObject),
                  let reencodedJSONString = String(data: reencodedJSONData, encoding: .utf8) else {
                throw NSError(domain: "InvalidJSON", code: 1, userInfo: [NSLocalizedDescriptionKey: "Re-encoding JSON failed"])
            }

            // Send the re-encoded JSON to Supabase
            try await SupabaseManager.shared.uploadEditedJSON(reencodedJSONString)

            // Update completion with the new JSON
            completion(reencodedJSONString)
            dismiss()

        } catch {
            // Handle error in submission
            errorMessage = "Failed to submit JSON: \(error.localizedDescription)"
            isValidJSON = false
        }
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

#Preview {
    JSONEditorView(initialJSON: "{\"test\": \"value\"}") { _ in }
}
