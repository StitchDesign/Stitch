//
//  OutputPortUIData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/21/25.
//

import Foundation

// May want a common protocol differentiated by `portAddress` type
@Observable
final class OutputPortUIViewModel: Identifiable, AnyObject {
    
    let id: OutputCoordinate // which node id + port id this is for
    
    // the portDragged and portDragEnded methods DO require specific input vs output row view model;
    // so instead you can pass down the nodeIO and the
    @MainActor var anchorPoint: CGPoint? = nil
    @MainActor var portColor: PortColor = .noEdge
    @MainActor var portAddress: OutputPortIdAddress?
    @MainActor var connectedCanvasItems = CanvasItemIdSet()
    
    @MainActor
    init(id: OutputCoordinate,
         anchorPoint: CGPoint? = nil,
         portColor: PortColor = .noEdge,
         portAddress: OutputPortIdAddress? = nil,
         connectedCanvasItems: CanvasItemIdSet = .init()) {
        self.id = id
        self.anchorPoint = anchorPoint
        self.portColor = portColor
        self.portAddress = portAddress
        self.connectedCanvasItems = connectedCanvasItems
    }
}

extension CanvasItemViewModel {
    @MainActor
    var outputPortUIViewModels: [OutputPortUIViewModel] {
        self.outputViewModels.map(\.portUIViewModel)
    }
}

extension OutputNodeRowViewModel {
    @MainActor var anchorPoint: CGPoint? {
        get {
            self.portUIViewModel.anchorPoint
        } set(newValue) {
            self.portUIViewModel.anchorPoint = newValue
        }
    }
    
    @MainActor var portColor: PortColor {
        get {
            self.portUIViewModel.portColor
        } set(newValue) {
            self.portUIViewModel.portColor = newValue
        }
    }
    
    @MainActor var portAddress: PortAddressType? {
        get {
            self.portUIViewModel.portAddress
        } set(newValue) {
            self.portUIViewModel.portAddress = newValue
        }
    }
    
    @MainActor var connectedCanvasItems: CanvasItemIdSet {
        get {
            self.portUIViewModel.connectedCanvasItems
        } set(newValue) {
            self.portUIViewModel.connectedCanvasItems = newValue
        }
    }
}
