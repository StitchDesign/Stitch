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
            .onChange(of: graphMovement.zoomData.current, initial: true) {
                currentNodePage.zoomData.current = graphMovement.zoomData.current
            }
            .onChange(of: graphMovement.zoomData.final, initial: true) {
                currentNodePage.zoomData.final = graphMovement.zoomData.final
            }
            .onChange(of: groupNodeFocused, initial: true) {
                self.graphMovement.localPosition = currentNodePage.localPosition
                self.graphMovement.localPreviousPosition = currentNodePage.localPosition
                self.graphMovement.zoomData.current = currentNodePage.zoomData.current
                self.graphMovement.zoomData.final = currentNodePage.zoomData.final
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
