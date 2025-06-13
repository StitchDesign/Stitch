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
 
    // Passed down as a Bindable so we can use with SwiftUI's Toggle
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
            
    var recordingState: LLMRecordingState {
        self.document.llmRecording
    }
    
    // TODO: Shouldn't we *always* have a prompt at this point ?
    var prompt: String {
        recordingState.promptForTrainingDataOrCompletedRequest
    }

    @State var ratingExplanation: String = ""
    
    var body: some View {
        VStack {
            StitchTextView(string: "Help us improve Stitch AI by showing how us the graph should be.")
                .font(.title2)
                .padding(.top)
            
            StitchTextView(string: "Prompt: \(prompt)")
                .font(.headline)
                .padding([.top])
            
            // Explanation
            StitchTextView(string: "Why is this graph better than lower-rated one? ",
                           font: .caption)
            
            TextField("", text: self.$ratingExplanation)
                .frame(width: 260)
                .padding(6)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray)
                }
                .onAppear {
                    self.ratingExplanation = ""
                }
            
            
            // TODO: shouldn't we *always* have a rating at this point ?
            if let rating = recordingState.rating {
                HStack {
                    StitchTextView(string: "Rating: ")
                    StitchAIRatingStarsView(currentRating: rating)
                }
                .padding([.top, .bottom])
            }
            
            List {
                // TODO: MAY 24: is hashValue okay here?
                ForEach(self.recordingState.actions, id: \.hashValue) { action in
                    LLMActionCorrectionView(action: action,
                                            graph: graph)
                }
                .listRowBackground(Color.clear)
                .listRowSpacing(8)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            
            if let invalidReason = recordingState.actionsError {
                ScrollView {
                    StitchTextView(string: "Error: " + invalidReason,
                                   fontColor: .red)
                    .lineLimit(nil)
                }
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
                dispatch(StitchAIActionReviewCancelled())
            }) {
                Text("Cancel")
                    .padding()
            }
            
            Button(action: {
                log("Stitch AI edit modal: will complete and dismiss")
                document.submitApprovedActionsToSupabase( explanationForRatingForExistingGraph: self.ratingExplanation)
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
    let port: CurrentStep.NodeIOPortType
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
    let action: any StepActionable
    @Bindable var graph: GraphState
        
    var body: some View {
        
        VStack(alignment: .leading, spacing: 8) {
            
            stepTypeAndDeleteView
            
            // TODO: update views below to work with a proper
            switch StepTypeAction.fromStep(action.toStep).value {
                
            case .addNode(let x):
                StitchTextView(string: "Node: \(x.nodeName.description) \(x.nodeId.debugFriendlyId)")

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
                StitchTextView(string: "Value: \(x.value.anyCodable)")
                
            case .sidebarGroupCreated(let x):
                StitchTextView(string: "Create Group")
                StitchTextView(string: "With Node: \(x.nodeId.debugFriendlyId)")
                if !x.children.isEmpty {
                    StitchTextView(string: "Children: \(x.children.map { $0.debugFriendlyId }.joined(separator: ", "))")
                }
                
//            case .editJSNode:
//                StitchTextView(string: "Edit JS Node")
                
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
            StitchTextView(string: "Step Type: \(action.toStep.stepType.display)")
            Spacer()
            Image(systemName: "trash")
                .onTapGesture {
                    dispatch(StepActionDeletedFromEditModal(deletedStep: action))
                }
        }
    }
}

// Hack for supporting check box on iOS
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }, label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square" : "square")
                configuration.label
            }
        })
    }
}
