//
//  GraphMovementViewModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/4/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct GraphMovementViewModifier: ViewModifier {
    @Bindable var graphMovement: GraphMovementObserver
    @Bindable var currentNodePage: NodePageData
    let groupNodeFocused: GroupNodeType?

    func body(content: Content) -> some View {
        content
            .onChange(of: graphMovement.localPosition, initial: true) {
                currentNodePage.localPosition = graphMovement.localPosition
            }
            .onChange(of: graphMovement.zoomData, initial: true) {
                currentNodePage.zoomData = graphMovement.zoomData
            }
            .onChange(of: groupNodeFocused, initial: true) {
                self.graphMovement.localPosition = currentNodePage.localPosition
                self.graphMovement.localPreviousPosition = currentNodePage.localPosition
                self.graphMovement.zoomData = currentNodePage.zoomData
            }
            // offset and scale are applied to the nodes on the graph,
            // but not eg to the blue box and green cursor;
            // GRAPH-OFFSET (applied to container for all the nodes)
            .offset(x: graphMovement.localPosition.x,
                    y: graphMovement.localPosition.y)
            // SCALE APPLIED TO GRAPH-OFFSET + ALL THE NODES
            .scaleEffect(graphMovement.zoomData.zoom)
    }
}
