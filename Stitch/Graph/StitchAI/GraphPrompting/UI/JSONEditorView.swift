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
    let isForConnectNodeAction: Bool
    
    var body: some View {
        // Can you get the actions more generally?
        // can you get a better data structure than just the giant json-like struct you have to unravel?
        if let parsedPort: NodeIOPortType = action.parsePort() {
            
            let generalLabel = isForConnectNodeAction ? "To Port: " : "Port: "
            
            switch parsedPort {
            case .keyPath(let keyPath):
                StitchTextView(string: "\(generalLabel) \(keyPath.layerInput)")
                
            case .portIndex(let portIndex):
                HStack {
                    StitchTextView(string: "\(generalLabel) ")
                    
                    if let labelForPortIndex = nodeKind.asNodeKind.getPatch?.graphNode?.rowDefinitions(for: .number).inputs[safeIndex: portIndex] {
                        
                        StitchTextView(string: "\(labelForPortIndex.label), ")
                    }
                    
                    StitchTextView(string: "\(portIndex)")
                }
                
            } // switch parsedPort
        } else {
            EmptyView()
        }
    }
}

struct LLMActionCorrectionView: View {
    let action: Step
    let nodeIdToNameMapping: [String: String]
    
    var body: some View {
                
        if let nodeId = action.nodeId,
           let nodeKind: PatchOrLayer = nodeIdToNameMapping.get(nodeId)?.parseNodeKind() {
            StitchTextView(string: "Node: \(nodeKind.asNodeKind.description) \(nodeId)")
            
            
            LLMPortDisplayView(action: action,
                               nodeKind: nodeKind,
                               isForConnectNodeAction: false)
        }
                
        // Step.fromNodeId
        LLMActionFromNodeView(action: action,
                              nodeIdToNameMapping: nodeIdToNameMapping)
        LLMFromPortDisplayView(action: action)

        
        // Step.toNodeId
        LLMActionToNodeAndPortView(action: action,
                                   nodeIdToNameMapping: nodeIdToNameMapping)
        
        if let value = action.parseValueForSetInput() {
            StitchTextView(string: "Value: \(value.display)")
        }
        
        if let nodeType = action.parseNodeType() {
            StitchTextView(string: "NodeType: \(nodeType.display)")
        }
        
    }
}


struct LLMActionToNodeAndPortView: View {
    let action: Step
    let nodeIdToNameMapping: [String: String]
    
    var body: some View {
        // Step.fromNodeId
        if let toNodeId = action.toNodeId,
           let toNodeKind = nodeIdToNameMapping.get(toNodeId)?.parseNodeKind() {
            StitchTextView(string: "To Node: \(toNodeKind.asNodeKind.description), \(toNodeId)")
            
            // toNode is only for connect_nodes, so we want to show the port as well
            LLMPortDisplayView(action: action,
                               nodeKind: toNodeKind,
                               isForConnectNodeAction: true)
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

struct LLMActionFromNodeView: View {
    let action: Step
    let nodeIdToNameMapping: [String: String]
    
    var body: some View {
        // Step.fromNodeId
        if let fromNodeId = action.fromNodeId,
           let fromNodeKind = nodeIdToNameMapping.get(fromNodeId)?.parseNodeKind() {
            StitchTextView(string: "From Node: \(fromNodeKind.asNodeKind.description), \(fromNodeId)")
        }
    }
}


// TODO: JAN 25
// i.e. EditBeforeSubmitModalView
struct JSONEditorView: View {
    @Environment(\.dismiss) var dismiss
        
    //    @State private var jsonString: String
    
//    @State private var isValidJSON = true
    
//    @State private var errorMessage: String? = nil
    
//    @State private var hasCompleted = false
    
//    private let completion: (LLMStepActions) -> Void
    
//    let prompt: String
    
    // TODO: GRAB THESE from LLMRecordingState
//    @State var actions: [LLMStepAction]
    
    let recordingState: LLMRecordingState
    
    var prompt: String {
        recordingState.promptState.prompt
    }
    
    var actions: [LLMStepAction] {
        recordingState.actions
    }
    
//    init(recordingWrapper: RecordingWrapper,
//         completion: @escaping (LLMStepActions) -> Void) {
////        self.prompt = recordingWrapper.prompt
////        self.completion = completion
//        self.nodeIdToNameMapping = .init()
//    }
    
    @State private var nodeIdToNameMapping: [String: String] = .init()
    
    var body: some View {
        ScrollView {
            actionsView
                .padding()
        }
    }
    
    var actionsView: some View {
        VStack {
            StitchTextView(string: "\(prompt)")
                .onAppear {
                    // Note: must do this here and not in view's `init`?
                    // Alternatively, pass in the data/mapping already created
                    actions.forEach { (action: LLMStepAction) in
                        // Add Node step uses nodeId; but Connect Nodes step uses toNodeId and fromNodeId
                        if let nodeId = action.nodeId,
                           let nodeName = action.nodeName {
                            self.nodeIdToNameMapping.updateValue(nodeName, forKey: nodeId)
                        }
                        
                        if let nodeId = action.fromNodeId,
                           let nodeName = action.nodeName {
                            self.nodeIdToNameMapping.updateValue(nodeName, forKey: nodeId)
                        }
                        
                        if let nodeId = action.toNodeId,
                           let nodeName = action.nodeName {
                            self.nodeIdToNameMapping.updateValue(nodeName, forKey: nodeId)
                        }
                        
                        log("self.nodeIdToNameMapping is now: \(self.nodeIdToNameMapping)")
                    }
                }
            
            // `id:` by hashable ought to be okay?
            ForEach(actions, id: \.hashValue) { (action: LLMStepAction) in
                VStack(alignment: .leading) {
                    
                    HStack {
                        StitchTextView(string: "Step Type: \(action.stepType)")
                        Spacer()
                        Button {
                            log("will delete this action")
                            // Note: fine to do equality check because not editing actions per se here
                            
                            dispatch(LLMActionsUpdated(newActions: self.actions.filter { $0 != action }))
                            
                        } label: {
                            Text("Delete")
                        }
                    }
                    
                    LLMActionCorrectionView(action: action,
                                            nodeIdToNameMapping: self.nodeIdToNameMapping)
                }
                Divider()
            }
            
//            if !isValidJSON {
//                Text(errorMessage ?? "Invalid JSON format")
//                    .foregroundColor(.red)
//                    .padding(.bottom)
//            }
//            
            HStack {
                Button(action: {
                    log("will dismiss without submitting")
                    // TODO: mark `hasCompleted` true or false ?
                    dismiss()
                }) {
                    Text("Cancel")
                        .padding()
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.bottom)
                
                Button(action: {
                    log("will complete and dismiss")
//                    completeAndDismiss(self.actions)
                    dismiss()
                    dispatch(ShowLLMApprovalModal())
                    
                }) {
//                    Text("Send to Supabase")
                    Text("Test before Sending to Supabase")
                        .padding()
//                        .background(isValidJSON ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
//                .disabled(!isValidJSON)
                .padding(.bottom)
                
            } // HStack
        }
        .onDisappear {
            dismiss()
//            if !hasCompleted {
//                completeAndDismiss(self.actions)
//            }
        }
    }
}
