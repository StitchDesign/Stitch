//
//  NodeLayout.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/19/24.
//

import SwiftUI

/// Used by view models to cache local data.
protocol StitchLayoutCachable: AnyObject, Sendable {
    @MainActor var viewCache: NodeLayoutCache? { get set }
}

struct NodeLayoutCache {
    var needsUpdating = false
    var sizes: [CGSize] = []
    var sizeThatFits: CGSize = .zero
    var spacing: ViewSpacing = .zero
}

extension View {
    func canvasPosition(id: CanvasItemId,
                        position: CGPoint) -> some View {
        layoutValue(key: CanvasPositionKey.self, value: .init(id: id,
                                                              position: position))
            .position(position)
    }
}

struct NodeLayout<T: StitchLayoutCachable>: Layout, Sendable {
    typealias Cache = ()
    
    // Check that prevents loop of cache updates given dispatch
    // updating cache on next cycle
    @State private var isUpdatingCache = false
    
    let observer: T
    let existingCache: NodeLayoutCache?
    
    // IMPORTANT
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        
        let isMarkedForUpdate = existingCache?.needsUpdating ?? true
        
        // Condition for needing new cache
        if isMarkedForUpdate && !self.isUpdatingCache {
            let newCache = self.recreateCache(subviews: subviews)
            return newCache.sizeThatFits
        }
        
        return existingCache?.sizeThatFits ?? .zero
    }
    
    func recreateCache(subviews: Subviews) -> NodeLayoutCache {
        let newCache = self.createCache(subviews: subviews)
        self.isUpdatingCache = true
        
        DispatchQueue.main.async { [weak observer] in
            self.isUpdatingCache = false
            observer?.viewCache = newCache
        }
        
        return newCache
    }
    
    // Ignore when not needed for perf
    private func createCache(subviews: Subviews) -> NodeLayoutCache {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let sizeThatFits = self.calculateSizeThatFits(subviews: subviews)
        let spacing = self.calculateSpacing(subviews: subviews)
        let cache = NodeLayoutCache(needsUpdating: false,
                                    sizes: sizes,
                                    sizeThatFits: sizeThatFits,
                                    spacing: spacing)
        
        return cache
    }
    
    private func calculateSizeThatFits(subviews: Subviews) -> CGSize {
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        
        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified) // Ask subview for its natural size
            totalWidth = max(totalWidth, subviewSize.width) // Expand the width to fit the widest subview
            totalHeight += subviewSize.height // Stack the subviews vertically
        }
        
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    // What does this mean for e.g. ScrollView { Image } ?
    // Explore in Playgrounds
    
    // Some parent view is calling this view to place its child;
    // start from parent, work down to children
    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout Cache) {
        
        guard !subviews.isEmpty else { return }
        
        let cache = self.existingCache ?? self.createCache(subviews: subviews)
            
        if self.existingCache == nil {
            DispatchQueue.main.async { [weak observer] in
                observer?.viewCache = cache
            }
        }
        
        for index in subviews.indices {
            let subview = subviews[index]
            let size = cache.sizes[index]
            
            // What is ScrollView used the bounds of the layer, instead of container?
            
            // Can we place the Scroll
            // Want to keep the ScrollView's size (vs content's size) so that we can still scroll;
            // but make the ScrollView start at the same 
            subview.place(
                at: bounds.origin, // bounds are received from parent
                anchor: .topLeading, // typical SwiftUI default top-left anchoring
                proposal: ProposedViewSize(size))
        }
    }
    
    func spacing(subviews: Self.Subviews, cache: inout Cache) -> ViewSpacing {
        guard let cache = self.existingCache else {
            let newCache = self.createCache(subviews: subviews)
            return newCache.spacing
        }
        
        return cache.spacing
    }
    
    private func calculateSpacing(subviews: Self.Subviews) -> ViewSpacing {
        var spacing = ViewSpacing()

        for index in subviews.indices {
            var edges: Edge.Set = [.leading, .trailing]
            if index == 0 { edges.formUnion(.top) }
            if index == subviews.count - 1 { edges.formUnion(.bottom) }
            spacing.formUnion(subviews[index].spacing, edges: edges)
        }

        return spacing
    }
    
    // MARK: we don't use SwiftUI Layout's native cache as it doesn't resize properly for our needs.
//    func makeCache(subviews: Subviews) -> Cache { }
    
    // Keep this empty for perf
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
