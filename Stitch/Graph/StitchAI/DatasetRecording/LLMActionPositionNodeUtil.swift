//
//  LLMActionPositionNodeUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/31/25.
//

import Foundation


final class AdjacencyCalculator {
    // key = From node
    // value = To nodes
    var adjacencyList: [UUID: [UUID]] = [:]
    
    var inDegree: [UUID: Int] = [:]
    
    var seenNodes: Set<UUID> = .init()
    
    var nodeCount: Int {
        seenNodes.count
    }

    func addEdge(from: UUID, to: UUID) {
        
        // Always make sure we have at least an empty list for this key (From).
        if adjacencyList[from] == nil {
            adjacencyList[from] = []
        }
        
        seenNodes.insert(from)
        seenNodes.insert(to)
                
        adjacencyList[from]?.append(to)
        inDegree[to, default: 0] += 1
        inDegree[from, default: 0] += 0 // Ensure source nodes exist
    }
    
    func computeDepth() -> ([UUID: Int]?, Bool) {
        var depth: [UUID: Int] = [:]
        var queue: [UUID] = []
        var processedNodes = 0  // Track processed nodes
        
        for (node, degree) in inDegree {
            if degree == 0 {
                queue.append(node)
                depth[node] = 0
            }
        }
        
        while !queue.isEmpty {
            let node = queue.removeFirst()
            processedNodes += 1
            let currentDepth = depth[node] ?? 0
            
            if let neighbors = adjacencyList[node] {
                for neighbor in neighbors {
                    inDegree[neighbor]! -= 1
                    if inDegree[neighbor] == 0 {
                        queue.append(neighbor)
                        depth[neighbor] = max(depth[neighbor] ?? 0, currentDepth + 1)
                    }
                }
            }
        }
        
        // If not all nodes were processed, a cycle exists
        let hasCycle = (processedNodes < nodeCount)
        log("AdjacencyCalculator: computeDepth: processedNodes: \(processedNodes)")
        log("AdjacencyCalculator: computeDepth: nodeCount: \(nodeCount)")
        return hasCycle ? (nil, true) : (depth, false)
    }
}
