//
//  NodeBroadcastSubmenuView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/14/24.
//

import SwiftUI
import StitchSchemaKit


struct BroadcastChoice: Identifiable, Equatable, Hashable {
    let title: String
    let id: NodeId
}

let nilBroadcastChoice = BroadcastChoice(
    title: "None",
    id: .fakeNodeId)

struct NodeWirelessBroadcastSubmenuView: View {

    @Bindable var graph: GraphState
    
    @State var currentBroadcastChoice: BroadcastChoice
        
    let nodeId: NodeId // wireless receiver node id
    
    var forNodeTitle: Bool = false

    // TODO: Picker's selection state (the checkmark) is incorrect; and .onChange for a manually passed in input value completely breaks Picker's selection state; and this explicit `init` does not help either
    init(graph: GraphState,
         currentBroadcastChoice: BroadcastChoice,
         nodeId: NodeId,
         forNodeTitle: Bool = false) {
        self.graph = graph
        self.currentBroadcastChoice = currentBroadcastChoice
        self.nodeId = nodeId
        self.forNodeTitle = forNodeTitle
    }
    
    
    // nilChoice id is created afresh everytime
    @MainActor
    var choices: [BroadcastChoice] {
        [nilBroadcastChoice] + self.graph
            .getBroadcasterNodesAtThisTraversalLevel()
            // Sort alphabetically
            .sorted(by: { $0.displayTitle < $1.displayTitle })
            .map { .init(title: $0.displayTitle, id: $0.id) }
    }

    var body: some View {
        
        // logInView("NodeBroadcastSubmenuView: body")
        // logInView("NodeBroadcastSubmenuView: currentBroadcastChoice: \(currentBroadcastChoice)")
        
        Picker("Change Broadcast", selection: $currentBroadcastChoice) {
            ForEach(choices) { choice in
                
                // logInView("NodeBroadcastSubmenuView: choice: \(choice)")
                
                if let broadcasterNode = graph.getNodeViewModel(choice.id) {
                    @Bindable var node = broadcasterNode
                    StitchTextView(string: node.displayTitle)
                        .tag(choice)
                } else {
                    StitchTextView(string: NodeViewModel.fakeTitle)
                        .tag(choice)
                }
            }
        }
        .pickerStyle(.inline)
//        .modifier(PickerStyleModifierView(forNodeTitle: forNodeTitle))
        
        //        .onChange(of: self.currentAssignedBroadcaster, initial: true) { oldValue, newValue in
        //            log("NodeBroadcastSubmenuView: onChange self.currentAssignedBroadcaster: oldValue: \(oldValue)")
        //            log("NodeBroadcastSubmenuView: onChange self.currentAssignedBroadcaster: newValue: \(newValue)")
        //            self.currentBroadcastChoice = .init(
        //                title: currentAssignedBroadcasterTitle,
        //                id: currentAssignedBroadcaster ?? nilBroadcastChoice.id)
        //        }
        .onChange(of: self.currentBroadcastChoice) { oldValue, newValue in
            // log("NodeBroadcastSubmenuView: onChange self.currentBroadcastChoice: oldValue: \(oldValue)")
            // log("NodeBroadcastSubmenuView: onChange self.currentBroadcastChoice: newValue: \(newValue)")
            dispatch(SetBroadcastForWirelessReceiver(
                broadcasterNodeId: newValue.id,
                receiverNodeId: nodeId))
        }
    }
}

// TODO: support in the node tag menu again?
//struct PickerStyleModifierView: ViewModifier {
//    
//    let forNodeTitle: Bool
//    
//    func body(content: Content) -> some View {
//        if forNodeTitle {
//            // .inline = create this Picker at the same hierarchy level as the current view, don't nest etc.
//            content.pickerStyle(.inline)
//        } else {
//            // Default to .menu, which manifests as 'submenu' when used with another menu
//            content.pickerStyle(.menu)
//        }
//    }
//}
