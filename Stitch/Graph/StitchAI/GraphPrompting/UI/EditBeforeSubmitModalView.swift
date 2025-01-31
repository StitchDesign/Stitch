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
    
    var actions: [StepTypeAction] {
        recordingState.actions
    }
    
    var nodeIdToNameMapping: [NodeId: PatchOrLayer] {
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
//        .frame(maxWidth: 420, maxHeight: 600)
        .frame(maxWidth: 360, maxHeight: 600)
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
            ForEach(actions, id: \.hashValue) { action in
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

struct LLMNodeIOPortTypeView: View {
    let nodeName: PatchOrLayer
    let port: NodeIOPortType
    let isForToPortOfConnectNodesAction: Bool
    
    var body: some View {
        let generalLabel = isForToPortOfConnectNodesAction ? "To Port: " : "Port: "
        
        switch port {
            
        case .keyPath(let keyPath):
            StitchTextView(string: "\(generalLabel) \(keyPath.layerInput)")
            
        case .portIndex(let portIndex):
            HStack {
                StitchTextView(string: "\(generalLabel) ")
                
                if let labelForPortIndex = nodeName.asNodeKind.getPatch?.graphNode?.rowDefinitions(for: .number).inputs[safeIndex: portIndex],
                   !labelForPortIndex.label.isEmpty {
                    
                    StitchTextView(string: "\(labelForPortIndex.label), ")
                }
                
                StitchTextView(string: "\(portIndex)")
            }
        } // switch port
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
    let action: StepTypeAction
    let nodeIdToNameMapping: [NodeId: PatchOrLayer]
        
    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            // added
            stepTypeAndDeleteView
            
            switch action {
            case .addNode(let x):
                StitchTextView(string: "Node: \(x.nodeName.asNodeKind.description) \(x.nodeId.debugFriendlyId)")
                
            case .addLayerInput(let x):
                if let nodeName = nodeIdToNameMapping.get(x.nodeId) {
                    StitchTextView(string: "Node: \(nodeName.asNodeKind.description) \(x.nodeId.debugFriendlyId)")
                    
                    // added
                    LLMNodeIOPortTypeView(nodeName: nodeName,
                                          port: .keyPath(x.port.asFullInput),
                                          isForToPortOfConnectNodesAction: false)
                }
            
            case .connectNodes(let x):
                if let fromNodeName = nodeIdToNameMapping.get(x.fromNodeId) {
                    StitchTextView(string: "From Node: \(fromNodeName.asNodeKind.description) \(x.fromNodeId.debugFriendlyId)")
                    LLMNodeIOPortTypeView(nodeName: fromNodeName,
                                          port: x.fromPort,
                                          isForToPortOfConnectNodesAction: false)
                }
                if let toNodeName = nodeIdToNameMapping.get(x.toNodeId) {
                    StitchTextView(string: "To Node: \(toNodeName.asNodeKind.description) \(x.toNodeId.debugFriendlyId)")
                    LLMNodeIOPortTypeView(nodeName: toNodeName,
                                          port: x.fromPort,
                                          isForToPortOfConnectNodesAction: true)
                }
                
            case .changeNodeType(let x):
                if let nodeName = nodeIdToNameMapping.get(x.nodeId) {
                    StitchTextView(string: "Node: \(nodeName.asNodeKind.description) \(x.nodeId.debugFriendlyId)")
                }
                StitchTextView(string: "NodeType: \(x.nodeType.display)")
                
            case .setInput(let x):
                if let nodeName = nodeIdToNameMapping.get(x.nodeId) {
                    StitchTextView(string: "Node: \(nodeName.asNodeKind.description) \(x.nodeId.debugFriendlyId)")
                    LLMNodeIOPortTypeView(nodeName: nodeName,
                                          port: x.port,
                                          isForToPortOfConnectNodesAction: false)
                }
                StitchTextView(string: "NodeType: \(x.nodeType.display)")
                StitchTextView(string: "Value: \(x.value.display)")
            }
        }
        .padding()
        .background(.ultraThickMaterial)
        .cornerRadius(16)
    }
    
    @ViewBuilder
    var stepTypeAndDeleteView: some View {
        HStack {
            StitchTextView(string: "Step Type: \(action.stepType.display)")
            Spacer()
            Image(systemName: "trash")
                .onTapGesture {
                    dispatch(LLMActionDeleted(deletedAction: action))
                }
        }
    }
  
}
