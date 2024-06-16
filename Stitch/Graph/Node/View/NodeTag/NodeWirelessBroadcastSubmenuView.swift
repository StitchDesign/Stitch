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

// TODO: why does moving the node (or something else?) reset the Picker's selection to None even when there's still an assigned broadcaster? Keeping around the commented out code to help debug that in the future
struct NodeWirelessBroadcastSubmenuView: View {

    @Bindable var graph: GraphState
    
    @State var currentBroadcastChoice: BroadcastChoice = nilBroadcastChoice
    
    let nodeId: NodeId // wireless receiver node id
    // let currentAssignedBroadcaster: NodeId?
    
    //    var currentAssignedBroadcasterTitle: String {
    //        if let currentAssignedBroadcaster = currentAssignedBroadcaster {
    //            return choices.first { $0.id == currentAssignedBroadcaster }?.title ?? "No"
    //
    //        }
    //        return nilBroadcastChoice.title
    //    }
    
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
                    StitchTextView(string: NodeViewModel.nilChoice.displayTitle)
                        .tag(choice)
                }
            }
        }
        .pickerStyle(.menu)
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
