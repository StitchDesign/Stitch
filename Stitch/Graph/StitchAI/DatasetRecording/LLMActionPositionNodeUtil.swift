//
//  LLMActionPositionNodeUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/31/25.
//

import Foundation


final class AdjacencyCalculator {
    var adjacencyList: [UUID: [UUID]] = [:]
    var inDegree: [UUID: Int] = [:]
    var nodeCount: Int = 0

    func addEdge(from: UUID, to: UUID) {
        if adjacencyList[from] == nil {
            adjacencyList[from] = []
            nodeCount += 1  // Count unique nodes
        }
        if adjacencyList[to] == nil {
            nodeCount += 1  // Count unique nodes
        }
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
        return hasCycle ? (nil, true) : (depth, false)
    }
}

//// Example Usage
//let graph = Graph()
//
//// Create UUIDs for nodes
//let nodeA = UUID()
//let nodeB = UUID()
//let nodeC = UUID()
//let nodeD = UUID()
//
//// Construct the graph with a cycle: A → B → C → D → B (cycle)
//graph.addEdge(from: nodeA, to: nodeB)
//graph.addEdge(from: nodeB, to: nodeC)
//graph.addEdge(from: nodeC, to: nodeD)
//graph.addEdge(from: nodeD, to: nodeB)  // Creates a cycle
//
//// Compute topological depth and detect cycle
//let (depthMap, hasCycle) = graph.computeDepth()
//
//if hasCycle {
//    print("Cycle detected! Topological sorting is not possible.")
//} else {
//    for (node, depth) in depthMap! {
//        print("\(node): Depth \(depth)")
//    }
//}
