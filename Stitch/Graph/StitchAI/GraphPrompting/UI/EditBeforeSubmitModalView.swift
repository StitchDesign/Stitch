//
//  JSONEditorView.swift
//  Stitch
//
//  Created by Nicholas Arner on 1/21/25.
//

import SwiftUI
import SwiftyJSON

// TODO: re-introduce the specific enum cases of Step, so that they can be manipulated more easily in views etc.
struct EditBeforeSubmitModalView: View {
 
    let recordingState: LLMRecordingState
    
    var prompt: String {
        recordingState.promptState.prompt
    }
    
    var actions: [LLMStepAction] {
        recordingState.actions
    }
    
//    @State private var nodeIdToNameMapping: [String: String] = .init()
    var nodeIdToNameMapping: [NodeId: String] {
        recordingState.nodeIdToNameMapping
    }
    
    var body: some View {
        VStack {
            ScrollView {
                actionsView
                    .padding()
            }
            
            buttons
                .padding()
        }
        .frame(maxWidth: 420, maxHeight: 600)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
        
    }
    
    var buttons: some View {
        HStack {
            Button(action: {
                dispatch(LLMAugmentationCancelled())
            }) {
                Text("Cancel")
                    .padding()
            }
            
            Button(action: {
                log("will complete and dismiss")
                dispatch(ShowLLMApprovalModal())
            }) {
                Text("Submit")
                    .padding()
            }
        } // HStack
    }
    
    @ViewBuilder
    var actionsView: some View {
        VStack {
            StitchTextView(string: "Prompt: \(prompt)")

            // `id:` by hashable ought to be okay?
            ForEach(actions, id: \.hashValue) { (action: LLMStepAction) in
                LLMActionCorrectionView(action: action,
                                        nodeIdToNameMapping: self.nodeIdToNameMapping)
            }
        }
    }
}


struct LLMActionToNodeAndPortView: View {
    let action: Step
    let nodeIdToNameMapping: [NodeId: String]
    
    var body: some View {
        // Step.fromNodeId
        if let toNodeId = action.toNodeId?.parseNodeId,
           let toNodeKind = nodeIdToNameMapping.get(toNodeId)?.parseNodeKind() {
            StitchTextView(string: "To Node: \(toNodeKind.asNodeKind.description), \(toNodeId.debugFriendlyId)")
            
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
    let nodeIdToNameMapping: [NodeId: String]
    
    var body: some View {
        // Step.fromNodeId
        if let fromNodeId = action.fromNodeId?.parseNodeId,
           let fromNodeKind = nodeIdToNameMapping.get(fromNodeId)?.parseNodeKind() {
            StitchTextView(string: "From Node: \(fromNodeKind.asNodeKind.description), \(fromNodeId.debugFriendlyId)")
        }
    }
}

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
    let nodeIdToNameMapping: [NodeId: String]
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            stepTypeAndDeleteView
            
            if let nodeId = action.parseNodeId,
               let nodeKind: PatchOrLayer = nodeIdToNameMapping.get(nodeId)?.parseNodeKind() {
                StitchTextView(string: "Node: \(nodeKind.asNodeKind.description) \(nodeId.debugFriendlyId)")
                
                LLMPortDisplayView(action: action,
                                   nodeKind: nodeKind,
                                   isForConnectNodeAction: false)
            }
        
            setInputView
            
            // Connect Nodes
            fromPortView
            toPortView
        }
        .padding()
        .background(.ultraThickMaterial)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    var stepTypeAndDeleteView: some View {
        HStack {
            if let stepType = StepType.init(rawValue: action.stepType) {
                StitchTextView(string: "Step Type: \(stepType.display)")
            }
            Spacer()
            Image(systemName: "trash")
                .onTapGesture {
                    dispatch(LLMActionDeleted(deletedAction: action))
                }
        }
    }
    
    @ViewBuilder
    var fromPortView: some View {
        // Step.fromNodeId
        LLMActionFromNodeView(action: action,
                              nodeIdToNameMapping: nodeIdToNameMapping)
        LLMFromPortDisplayView(action: action)

    }
    
    @ViewBuilder
    var toPortView: some View {
        // Step.toNodeId
        LLMActionToNodeAndPortView(action: action,
                                   nodeIdToNameMapping: nodeIdToNameMapping)
    }
    
    @ViewBuilder
    var setInputView: some View {
        
         if let value = action.parseValueForSetInput() {
             StitchTextView(string: "Value: \(value.display)")
         }
         
         if let nodeType = action.parseNodeType() {
             StitchTextView(string: "NodeType: \(nodeType.display)")
         }
    }
}
