//
//  CanvasItemReader.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/11/25.
//

import Foundation

// Protocol for functions that only need to retrieve certain objects from GraphState

protocol GraphReader {
    @MainActor func getNode(_ id: NodeId) -> NodeViewModel?
    @MainActor func getCanvasItem(_ id: CanvasItemId) -> CanvasItemViewModel?
    @MainActor func getInputRowObserver(_ id: InputCoordinate) -> InputNodeRowObserver?
    @MainActor func getOutputRowObserver(_ id: OutputCoordinate) -> OutputNodeRowObserver?
    
    // TODO: replace with
    @MainActor var groupNodeFocused: GroupNodeType? { get }
    
    @MainActor var selectedEdges: Set<PortEdgeUI> { get }
    @MainActor var edgeDrawingObserver: EdgeDrawingObserver { get }
    
    @MainActor var currentGraphTime: TimeInterval { get }
}

extension GraphState: GraphReader {
    @MainActor var groupNodeFocused: GroupNodeType? {
        self.documentDelegate?.groupNodeFocused
    }
}

extension GraphReader {
    @MainActor
    func updateCanvasItemFields(canvasItemId: CanvasItemId,
                                activeIndex: ActiveIndex) {
        guard let canvasItem = self.getCanvasItem(canvasItemId) else {
            // Crashes in some valid examples
            // fatalErrorIfDebug()
            return
        }
        
        canvasItem.inputViewModels.forEach {
            if let observer = self.getInputRowObserver($0.nodeIOCoordinate) {
                $0.updateFields(observer.getActiveValue(activeIndex: activeIndex))
            }
        }
        
        canvasItem.outputViewModels.forEach {
            if let observer = self.getOutputRowObserver($0.nodeIOCoordinate) {
                $0.updateFields(observer.getActiveValue(activeIndex: activeIndex))
            }
        }
    }
}
