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
    
//    var actions: [StepTypeAction] {
    var recordingStateActions: [StepTypeAction] {
        recordingState.actions
    }
    
    var nodeIdToNameMapping: [NodeId: PatchOrLayer] {
        recordingState.nodeIdToNameMapping
    }
    
    @State var actions: [StepTypeAction]
    
    var body: some View {
        VStack {
            StitchTextView(string: "Prompt: \(prompt)")
                .font(.headline)
                .padding(.top)
            
            // https://www.hackingwithswift.com/quick-start/swiftui/how-to-let-users-move-rows-in-a-list
            List(self.$actions, id: \.hashValue, editActions: .move) { $action in
                LLMActionCorrectionView(action: action,
                                        nodeIdToNameMapping: self.nodeIdToNameMapping)
                .listRowBackground(Color.clear)
                .listRowSpacing(8)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            
            buttons
                .padding(.bottom)
        }
        .frame(maxWidth: 360, maxHeight: 600)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .padding()
        .onChange(of: self.recordingStateActions) { oldValue, newValue in
            log(".onChange(of: self.recordingStateActions): newValue: \(newValue)")
            self.actions = newValue
        }
        .onChange(of: self.actions) { oldValue, newValue in
            log(".onChange(of: self.actions): newValue: \(newValue)")
            dispatch(LLMActionsUpdatedByModal(newActions: newValue))
        }
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
}

struct LLMNodeIOPortTypeView: View {
    let nodeName: PatchOrLayer
    let port: NodeIOPortType
    let generalLabel: String
    
    var body: some View {
        
        switch port {
            
        case .keyPath(let keyPath):
            StitchTextView(string: "\(generalLabel): \(keyPath.layerInput)")
            
        case .portIndex(let portIndex):
            HStack {
                StitchTextView(string: "\(generalLabel): ")
                
                if let labelForPortIndex = nodeName.asNodeKind.getPatch?.graphNode?.rowDefinitions(for: .number).inputs[safeIndex: portIndex],
                   !labelForPortIndex.label.isEmpty {
                    
                    StitchTextView(string: "\(labelForPortIndex.label), ")
                }
                
                StitchTextView(string: "index \(portIndex)")
            }
        } // switch port
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
                    
                    LLMNodeIOPortTypeView(nodeName: nodeName,
                                          port: .keyPath(x.port.asFullInput),
                                          generalLabel: "Layer Input")
                }
            
            case .connectNodes(let x):
                if let fromNodeName = nodeIdToNameMapping.get(x.fromNodeId) {
                    StitchTextView(string: "From Node: \(fromNodeName.asNodeKind.description) \(x.fromNodeId.debugFriendlyId)")
                    LLMNodeIOPortTypeView(nodeName: fromNodeName,
                                          port: x.fromPort,
                                          generalLabel: "From Port")
                }
                if let toNodeName = nodeIdToNameMapping.get(x.toNodeId) {
                    StitchTextView(string: "To Node: \(toNodeName.asNodeKind.description) \(x.toNodeId.debugFriendlyId)")
                    LLMNodeIOPortTypeView(nodeName: toNodeName,
                                          port: x.port,
                                          generalLabel: "To Port")
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
                                          generalLabel: "Input")
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
