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
    let graph: GraphState
    let existingCache: Self.Cache
//    let isUpdatingCache: Bool
    let needsInfiniteCanvasCacheReset: Bool
    
    typealias Cache = [CanvasItemId: CGRect]
    
    var willUpdateCache: Bool {
        self.needsInfiniteCanvasCacheReset// && !isUpdatingCache
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        .init(width: proposal.width ?? .zero,
              height: proposal.height ?? .zero)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        // Check if cache needs resetting
//        if willUpdateCache {
//            let newCache = self.recreateCache(subviews: subviews,
//                                              graph: graph)
//            cache = newCache
//        }
        
        // Override native cache
//        let cache = self.existingCache
        
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
        self.recreateCache(subviews: subviews,
                           oldCache: nil)
       
//        // Only make cache when specified
//        if willUpdateCache {
//            DispatchQueue.main.async { [weak graph] in
//                guard let graph = graph else {
//                    return
//                }
//                
//            }
//        }
//    
//        return self.existingCache
    }
    
    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        if self.willUpdateCache {
            cache = self.recreateCache(subviews: subviews,
                                       oldCache: cache)
        }
    }
    
    
    func recreateCache(subviews: Subviews,
                       oldCache: Cache?) -> Cache {
//        graph.isUpdatingCache = true
        
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
        
        if cache != oldCache {
            DispatchQueue.main.async { [weak graph] in
//                graph?.isUpdatingCache = false
                graph?.visibleNodesViewModel.needsInfiniteCanvasCacheReset = false
                graph?.visibleNodesViewModel.infiniteCanvasCache = cache
                
                // Update visible nodes (fixes init case)
                graph?.updateVisibleNodes()
            }
        }
        
        return cache
    }
    
//    func updateCache(_ cache: inout Cache, subviews: Subviews) { }
    
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
