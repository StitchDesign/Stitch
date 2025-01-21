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
    private let completion: (String) -> Void
    
    init(initialJSON: String, completion: @escaping (String) -> Void) {
        _jsonString = State(initialValue: initialJSON)
        self.completion = completion
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $jsonString)
                    .font(.custom("Menlo", size: 14))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .onChange(of: jsonString) { newValue in
                        validateJSON(newValue)
                    }
                
                if !isValidJSON {
                    Text("Invalid JSON format")
                        .foregroundColor(.red)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Edit JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        completion(jsonString)
                        dismiss()
                    }
                    .disabled(!isValidJSON)
                }
            }
        }
        .onAppear {
            validateJSON(jsonString)
        }
    }
    
    private func validateJSON(_ jsonString: String) {
        guard let jsonData = jsonString.data(using: .utf8),
              let _ = try? JSONSerialization.jsonObject(with: jsonData) else {
            isValidJSON = false
            return
        }
        isValidJSON = true
    }
}

#Preview {
    JSONEditorView(initialJSON: "{\"test\": \"value\"}") { _ in }
}

