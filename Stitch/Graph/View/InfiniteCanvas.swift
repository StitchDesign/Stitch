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
        if let existingCache = graph.visibleNodesViewModel.infiniteCanvasCache {
            return existingCache
        }
        
        let cache = subviews.reduce(into: Cache()) { result, subview in
            let positionData = subview[CanvasPositionKey.self]
            let id = positionData.id
            let position = positionData.position
            let size = subview.sizeThatFits(.unspecified)
            
            let bounds = CGRect(origin: position,
                                size: size)
            result.updateValue(bounds, forKey: id)
        }
        
        graph.visibleNodesViewModel.infiniteCanvasCache = cache
        return cache
    }
    
    func updateCache(_ cache: inout Cache, subviews: Subviews) {
        // Recalcualte graph if cache reset
        if graph.visibleNodesViewModel.infiniteCanvasCache == nil {
            cache = self.makeCache(subviews: subviews)
            graph.visibleNodesViewModel.infiniteCanvasCache = cache
        }
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
