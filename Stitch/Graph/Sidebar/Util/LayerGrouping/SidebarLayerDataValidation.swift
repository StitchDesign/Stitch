//
//  SidebarLayerDataValidation.swift
//  Stitch
//
//  Created by Claude Code on 8/21/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI

extension Array where Element == SidebarLayerData {
    /// Recursively detects oval layers that incorrectly have children.
    /// Returns array of problematic layer IDs with their children count.
    func detectOvalLayersWithChildren(graph: GraphState) -> [(layerId: UUID, childrenCount: Int)] {
        var results: [(layerId: UUID, childrenCount: Int)] = []
        
        func crawlLayer(_ layer: SidebarLayerData) {
            // Check if this layer is an oval with children
            if let layerNode = graph.getNode(layer.id),
               let layerKind = layerNode.kind.getLayer,
               layerKind == .oval,
               let children = layer.children,
               !children.isEmpty {
                results.append((layerId: layer.id, childrenCount: children.count))
            }
            
            // Recursively check all children
            layer.children?.forEach { childLayer in
                crawlLayer(childLayer)
            }
        }
        
        // Process all layers at the top level
        self.forEach { layer in
            crawlLayer(layer)
        }
        
        return results
    }
    
    /// Alternative version that doesn't require graph access - 
    /// checks based on layer type information if available
    func detectInvalidLayerChildren() -> [(layerId: UUID, issue: String)] {
        var results: [(layerId: UUID, issue: String)] = []
        
        func crawlLayer(_ layer: SidebarLayerData) {
            // This would need layer type information to be stored in SidebarLayerData
            // For now, just detect any layer with children that shouldn't have them
            if let children = layer.children, !children.isEmpty {
                // This is a placeholder - we'd need additional layer type info
                // to make this work without graph access
                results.append((layerId: layer.id, issue: "Layer has \(children.count) children - needs validation"))
            }
            
            // Recursively check all children
            layer.children?.forEach { childLayer in
                crawlLayer(childLayer)
            }
        }
        
        self.forEach { layer in
            crawlLayer(layer)
        }
        
        return results
    }
}

extension SidebarLayerData {
    /// Convenience method to check if this specific layer is an oval with children
    func isOvalWithChildren(graph: GraphState) -> Bool {
        guard let layerNode = graph.getNode(self.id),
              let layerKind = layerNode.kind.getLayer,
              layerKind == .oval,
              let children = self.children,
              !children.isEmpty else {
            return false
        }
        return true
    }
}