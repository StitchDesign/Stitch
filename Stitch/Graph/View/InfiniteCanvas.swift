//
//  InfiniteCanvas.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/19/24.
//

import SwiftUI

struct CanvasLayoutPosition {
    let id: CanvasItemId
    let position: CGPoint
}

struct CanvasPositionKey: LayoutValueKey {
    static let defaultValue: CanvasLayoutPosition = .init(id: .node(.init()),
                                                          position: .zero)
}

struct InfiniteCanvas: Layout {
    // Prevents possible loop of cache recreation
    @State private var willUpdateCache = true
    
    let graph: GraphState
    let existingCache: Self.Cache
    let needsInfiniteCanvasCacheReset: Bool
    
    typealias Cache = [CanvasItemId: CGRect]
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        .init(width: proposal.width ?? .zero,
              height: proposal.height ?? .zero)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        // Place subviews
        for subview in subviews {
            let positionData = subview[CanvasPositionKey.self]
            let id = positionData.id
            
            guard let subviewSize = cache.get(id)?.size else {
                // This is when with empty view for empty nodes
                continue
            }

            subview.place(
                at: bounds.origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(subviewSize))
        }
    }
    
    func makeCache(subviews: Subviews) -> Cache {
        // Only make cache when specified
        if !self.needsInfiniteCanvasCacheReset || self.willUpdateCache {
            return self.existingCache
        }
        
        self.willUpdateCache = true
        
        // Rebuilding cache scenario
        let cache = subviews.reduce(into: Cache()) { result, subview in
            let positionData = subview[CanvasPositionKey.self]
            let id = positionData.id
            let position = positionData.position
            let size = subview.sizeThatFits(.unspecified)
            
            let bounds = CGRect(origin: position,
                                size: size)
            result.updateValue(bounds, forKey: id)
        }
        
        DispatchQueue.main.async { [weak graph] in
            self.willUpdateCache = false
            graph?.visibleNodesViewModel.needsInfiniteCanvasCacheReset = false
            graph?.visibleNodesViewModel.infiniteCanvasCache = cache
        }
        
        return cache
    }
    
    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        // Recalcualte graph if cache reset
        // TODO: check infinte canvas update cache
//        if graph.visibleNodesViewModel.infiniteCanvasCache == nil {
//            cache = self.makeCache(subviews: subviews)
//            graph.visibleNodesViewModel.infiniteCanvasCache = cache
//        }
    }
    
    func explicitAlignment(of guide: HorizontalAlignment,
                           in bounds: CGRect,
                           proposal: ProposedViewSize,
                           subviews: Self.Subviews,
                           cache: inout Cache) -> CGFloat? {
        return nil
    }
    
    func explicitAlignment(of guide: VerticalAlignment,
                           in bounds: CGRect,
                           proposal: ProposedViewSize,
                           subviews: Self.Subviews,
                           cache: inout Cache) -> CGFloat? {
        return nil
    }
}
