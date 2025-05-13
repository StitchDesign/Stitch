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
 
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    
    var recordingState: LLMRecordingState {
        self.document.llmRecording
    }

    var body: some View {
        VStack {
            StitchTextView(string: "Prompt: \(recordingState.promptState.prompt)")
                .font(.headline)
                .padding(.top)
            
            List {
                ForEach(self.recordingState.actions) { action in
                    LLMActionCorrectionView(action: action,
                                            graph: graph)
                }
                .listRowBackground(Color.clear)
                .listRowSpacing(8)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            
            if let invalidReason = recordingState.actionsError {
                StitchTextView(string: "Error: " + invalidReason,
                               fontColor: .red)
                .padding()
                .border(.red)
                .padding()
            }
            
            buttons
                .padding(.bottom)
        }
        .frame(maxWidth: 360, maxHeight: .infinity)
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
                log("Stitch AI edit modal: will complete and dismiss")
                dispatch(ShowLLMApprovalModal())
            }) {
                Text("Submit")
                    .padding()
            }
            
            Toggle("Auto Validate", isOn: self.$document.llmRecording.willAutoValidate)
                .toggleStyle(CheckboxToggleStyle())
        }
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
    let action: Step
    @Bindable var graph: GraphState
        
    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            // added
            stepTypeAndDeleteView
            
            switch try? StepTypeAction.fromStep(action) {
            case .addNode(let x):
                StitchTextView(string: "Node: \(x.nodeName.asNodeKind.description) \(x.nodeId.debugFriendlyId)")

            case .connectNodes(let x):
                if let nodeKind = graph.getNode(x.fromNodeId)?.kind,
                   let fromNodeName = PatchOrLayer.from(nodeKind: nodeKind) {
                    StitchTextView(string: "From Node: \(nodeKind.description) \(x.fromNodeId.debugFriendlyId)")
                    LLMNodeIOPortTypeView(nodeName: fromNodeName,
                                          port: .portIndex(x.fromPort),
                                          generalLabel: "From Port")
                } else {
                    StitchTextView(string: "No Patch/Layer found for From Node \(x.fromNodeId.debugFriendlyId)")
                }
                
                if let nodeKind = graph.getNode(x.toNodeId)?.kind,
                   let toNodeName = PatchOrLayer.from(nodeKind: nodeKind) {
                    StitchTextView(string: "To Node: \(nodeKind.description) \(x.toNodeId.debugFriendlyId)")
                    LLMNodeIOPortTypeView(nodeName: toNodeName,
                                          port: x.port,
                                          generalLabel: "To Port")
                } else {
                    StitchTextView(string: "No Patch/Layer found for To Node \(x.toNodeId.debugFriendlyId)")
                }
                
            case .changeValueType(let x):
                if let nodeKind = graph.getNode(x.nodeId)?.kind,
                   let nodeName = PatchOrLayer.from(nodeKind: nodeKind) {
                    StitchTextView(string: "Node: \(nodeName.asNodeKind.description) \(x.nodeId.debugFriendlyId)")
                } else {
                    StitchTextView(string: "No Patch/Layer found for Node \(x.nodeId.debugFriendlyId)")
                }
                
                StitchTextView(string: "NodeType: \(x.valueType.display)")
                
            case .setInput(let x):
                if let nodeKind = graph.getNode(x.nodeId)?.kind,
                   let nodeName = PatchOrLayer.from(nodeKind: nodeKind) {
                    StitchTextView(string: "Node: \(nodeName.asNodeKind.description) \(x.nodeId.debugFriendlyId)")
                    LLMNodeIOPortTypeView(nodeName: nodeName,
                                          port: x.port,
                                          generalLabel: "Input")
                } else {
                    StitchTextView(string: "No Patch/Layer found for Node \(x.nodeId.debugFriendlyId)")
                }
                StitchTextView(string: "ValueType: \(x.valueType.display)")
                StitchTextView(string: "Value: \(x.value.display)")
                
            case .none:
                FatalErrorIfDebugView()
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

// Hack for supporting check box on iOS
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        // 1
        Button(action: {

            // 2
            configuration.isOn.toggle()

        }, label: {
            HStack {
                // 3
                Image(systemName: configuration.isOn ? "checkmark.square" : "square")

                configuration.label
            }
        })
    }
}
