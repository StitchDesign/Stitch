//
//  OutputPortUIData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/21/25.
//

import Foundation

// May want a common protocol differentiated by `portAddress` type
@Observable
final class OutputPortUIData: Identifiable, AnyObject {
    
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


extension OutputNodeRowViewModel {
    @MainActor var anchorPoint: CGPoint? {
        get {
            self.portData.anchorPoint
        } set(newValue) {
            self.portData.anchorPoint = newValue
        }
    }
    
    @MainActor var portColor: PortColor {
        get {
            self.portData.portColor
        } set(newValue) {
            self.portData.portColor = newValue
        }
    }
    
    @MainActor var portAddress: PortAddressType? {
        get {
            self.portData.portAddress
        } set(newValue) {
            self.portData.portAddress = newValue
        }
    }
    
    @MainActor var connectedCanvasItems: CanvasItemIdSet {
        get {
            self.portData.connectedCanvasItems
        } set(newValue) {
            self.portData.connectedCanvasItems = newValue
        }
    }
}
