//
//  JSONEditorView.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/21/25.
//

import SwiftUI
import SwiftyJSON

struct LLMPortDisplayView: View {
    let action: Step
    let nodeKind: PatchOrLayer
    
    var body: some View {
        // Can you get the actions more generally?
        // can you get a better data structure than just the giant json-like struct you have to unravel?
        if let parsedPort: NodeIOPortType = action.parsePort() {
            
            switch parsedPort {
            case .keyPath(let keyPath):
                StitchTextView(string: "Port: \(keyPath)")
                
            case .portIndex(let portIndex):
                
                HStack {
                    StitchTextView(string: "Port: ")
                    
                    if let labelForPortIndex = nodeKind.asNodeKind.getPatch?.graphNode?.rowDefinitions(for: .number).inputs[safeIndex: portIndex] {
                        StitchTextView(string: "Port: \(portIndex)")
                    }
                    
                    StitchTextView(string: "\(portIndex)")
                }
                
            } // switch parsedPort
        } else {
            EmptyView()
        }
    }
}

struct LLMFromPortDisplayView: View {
    let action: Step
    
    var body: some View {
        // Can you get the actions more generally?
        // can you get a better data structure than just the giant json-like struct you have to unravel?
        if let parsedFromPort: Int = action.parseFromPort() {
            StitchTextView(string: "From Port: \(parsedFromPort)")
        } else {
            EmptyView()
        }
    }
}


struct JSONEditorView: View {
    @Environment(\.dismiss) var dismiss
    
//    @State private var jsonString: String
    
    @State private var isValidJSON = true
    
    @State private var errorMessage: String? = nil
    
    @State private var hasCompleted = false
    
    private let completion: (String) -> Void
    
    @State private var recordingWrapper: RecordingWrapper // prompt + actions
    
//    init(initialJSON: String,
//         completion: @escaping (String) -> Void) {
//        let formattedJSON = Self.formatJSON(initialJSON)
//        _jsonString = State(initialValue: formattedJSON)
//        self.completion = completion
//    }
    
    
    @State private var nodeIdToNameMapping: [String: String]

    
    var body: some View {
        VStack {
            StitchTextView(string: "\(recordingWrapper.prompt)")
                .onAppear {
                    recordingWrapper.actions.map { (action: LLMStepAction) in
                        if let nodeId = action.nodeId,
                           let nodeName = action.nodeName {
                            self.nodeIdToNameMapping.updateValue(nodeName, forKey: nodeId)
                        }
                    }
                }
            
            ForEach(recordingWrapper.actions) { (action: LLMStepAction) in
                
                
                // A given `Step` may only have the
                VStack {
                    StitchTextView(string: "Step Type: \(action.stepType)")
                    
                    if let nodeId = action.nodeId {
                        
                        // We effectively MUST have these node kinds
                        if let nodeKind: PatchOrLayer = self.nodeIdToNameMapping.get(nodeId),.parseNodeKind() {
                            
                            HStack {
                                StitchTextView(string: "Node ID: \(nodeId)")
                                StitchTextView(string: "Node Kind: \(nodeKind.asNodeKind.display)")
                            }
                            
                            LLMPortDisplayView(action: action, nodeKind: nodeKind)
                            LLMFromPortDisplayView(action: action)
                                
                            // Step.fromNodeId
                            if let fromNodeId = action.fromNodeId,
                               let fromNodeKind = self.nodeIdToNameMapping.get(fromNodeId)?.parseNodeKind() {
                                StitchTextView(string: "From Node Id: \(fromNodeId)")
                                StitchTextView(string: "From Node Kind: \(fromNodeKind.asNodeKind.display)")
                            }
                            
                            
                            if let toNodeId = action.toNodeId,
                               let toNodeKind = self.nodeIdToNameMapping.get(toNodeId)?.parseNodeKind() {
                                StitchTextView(string: "To Node Id: \(toNodeId)")
                                StitchTextView(string: "To Node Kind: \(toNodeKind.asNodeKind.display)")
                            }
                            
                            if let value = action.value {
                                StitchTextView("Value: \(value.jsonWrapper.description)")
                            }
                            
                            if let nodeType = action.nodeType {
                                StitchTextView("NodeType: \(nodeType.jsonWrapper.description)")
                            }
                            
                            
                            
                        } // if let nodeKind = ..
                        
                    } // if let nodeId
                    
                } // VStack
            } // ForEach
            
            
//            TextEditor(text: $jsonString)
//                .font(.custom("Menlo", size: 13))
//                .frame(maxWidth: .infinity, maxHeight: .infinity)
//                .scrollContentBackground(.hidden)
//                .background {
//                    if !isValidJSON {
//                        Color.red.opacity(0.2)
//                            .cornerRadius(8)
//                    } else {
//                        Color.clear
//                    }
//                }
//                .onChange(of: jsonString) { newValue in
//                    // Replace smart quotes with standard quotes
//                    jsonString = newValue
//                        .replacingOccurrences(of: "“", with: "\"")
//                        .replacingOccurrences(of: "”", with: "\"")
//                    validateJSON(jsonString)
//                }
//                .padding()
//
            
            if !isValidJSON {
                Text(errorMessage ?? "Invalid JSON format")
                    .foregroundColor(.red)
                    .padding(.bottom)
            }
            
            HStack {
                Button(action: {
                    log("will dismiss without submitting")
                    dismiss()
                }) {
                    Text("Cancel")
                        .padding()
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.bottom)
                
                Button(action: {
//                    completeAndDismiss(jsonString)
                    // turn the edited actions etc. into the expected json or actions etc.
                    log("will complete and dismiss")
                }) {
                    Text("Send to Supabase")
                        .padding()
                        .background(isValidJSON ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(!isValidJSON)
                .padding(.bottom)
                
            } // HStack
            
          
            
            
           
        }
//        
//        .toolbar {
//            ToolbarItem(placement: .cancellationAction) {
//                Button("Cancel") {
//                    completeAndDismiss(jsonString)
//                }
//            }
//            
//            ToolbarItem(placement: .confirmationAction) {
//                Button("Save") {
//                    completeAndDismiss(Self.minifyJSON(jsonString))
//                }
//                .disabled(!isValidJSON)
//            }
//        }
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
