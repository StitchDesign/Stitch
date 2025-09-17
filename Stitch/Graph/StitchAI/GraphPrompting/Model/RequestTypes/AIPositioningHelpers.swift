//
//  AIPositioningHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/17/25.
//

import Foundation
import SwiftUI

// MARK: - Constants

let LAYER_MATCHING_SIMILARITY_THRESHOLD: Double = 0.5
let PATCH_MATCHING_SIMILARITY_THRESHOLD: Double = 0.5

// MARK: - Layer Canvas Item Coordinate

/// Represents a specific canvas item within a layer node's input port
/// Type-safe coordinate for identifying layer canvas items during position preservation
struct LayerCanvasItemCoordinate: Hashable, Identifiable {
    let nodeId: UUID
    let port: LayerInputPort
    let mode: PackedOrUnpacked

    var id: String { "\(nodeId):\(port):\(mode)" }

    /// Distinguishes between packed (single value) and unpacked (array) layer inputs
    enum PackedOrUnpacked: Hashable {
        case packed
        case unpacked(index: Int)
    }
}

// MARK: - Pure Functions

/// Captures canvas item positions from a matched layer entity
/// - Parameters:
///   - layerEntity: The existing layer node to extract positions from
///   - newNodeId: The ID of the new node that will receive these positions
/// - Returns: Dictionary mapping canvas item coordinates to their positions
func captureLayerCanvasItemPositions(
    from layerEntity: LayerNodeEntity,
    forNewNodeId newNodeId: UUID
) -> [LayerCanvasItemCoordinate: CGPoint] {
    var positions: [LayerCanvasItemCoordinate: CGPoint] = [:]

    for inputDefinition in layerEntity.layer.layerGraphNode.inputDefinitions {
        let portData = layerEntity[keyPath: inputDefinition.schemaPortKeyPath]

        // Check packed canvas items
        if let canvasItem = portData.packedData.canvasItem {
            let coordinate = LayerCanvasItemCoordinate(
                nodeId: newNodeId,
                port: inputDefinition,
                mode: .packed
            )
            positions[coordinate] = canvasItem.position
            log("  ✅ Captured packed canvas for port \(inputDefinition): position \(canvasItem.position)")
        }

        // Check unpacked canvas items
        for (index, unpackedData) in portData.unpackedData.enumerated() {
            if let canvasItem = unpackedData.canvasItem {
                let coordinate = LayerCanvasItemCoordinate(
                    nodeId: newNodeId,
                    port: inputDefinition,
                    mode: .unpacked(index: index)
                )
                positions[coordinate] = canvasItem.position
                log("  ✅ Captured unpacked[\(index)] canvas for port \(inputDefinition): position \(canvasItem.position)")
            }
        }
    }

    return positions
}

/// Matches nodes from old graph to new graph based on similarity
struct NodeEntitySimilarityMatcher {
    let oldNodes: [NodeEntity]

    /// Calculates similarity score between two nodes (0.0 to 1.0)
    func calculateSimilarity(oldNode: NodeEntity, newNodeType: PatchOrLayer) -> Double {
        log("calculateSimilarity: oldNodes.map(.id): \(oldNodes.map(\.id))")
        var score = 0.0
        var maxScore = 0.0

        // 1. Exact type match (highest weight: 3 points)
        maxScore += 3.0
        switch oldNode.nodeTypeEntity {
        case .patch(let patchNodeEntity):
            if case .patch(let newPatch) = newNodeType, patchNodeEntity.patch == newPatch {
                log("calculateSimilarity: had matching patch: \(newPatch)")
                score += 3.0
            }
        case .layer(let layerNodeEntity):
            if case .layer(let newLayer) = newNodeType, layerNodeEntity.layer == newLayer {
                log("calculateSimilarity: had matching layer: \(newLayer)")
                score += 3.0
            }
        case .group:
            // TODO: Handle group node similarity
            break
        case .component:
            // TODO: Handle component node similarity
            break
        }

        // 2. Input values match (medium-high weight: 2.5 points)
        maxScore += 2.5
        var inputMatchScore = 0.0

        let oldInputValues = extractInputValues(from: oldNode)
        log("calculateSimilarity: oldInputValues: \(oldInputValues)")
        if !oldInputValues.isEmpty {
            var totalComparisons = 0
            var matchScore = 0.0

            for oldValueList in oldInputValues {
                for _ in oldValueList {
                    totalComparisons += 1
                    // TODO: When we have newInputValues available, we can directly compare values
                    // For now, give partial credit for having values
                    matchScore += 0.5 // Half credit for having a value
                }
            }

            if totalComparisons > 0 {
                inputMatchScore = 2.5 * (matchScore / Double(totalComparisons))
            }
        }
        score += inputMatchScore

        // 3. Connection pattern match (medium weight: 2 points)
        maxScore += 2.0
        var connectionScore = 0.0

        let (upstreamCount, downstreamPotential) = extractConnectionCounts(from: oldNode)

        // Score based on connection complexity
        if upstreamCount > 0 || downstreamPotential > 0 {
            // Give points for having similar connection patterns
            // This helps distinguish between isolated nodes and connected ones
            connectionScore = 2.0 * min(1.0, Double(upstreamCount + downstreamPotential) / 10.0)
        }
        score += connectionScore

        // 4. Node kind category match (low weight: 0.5 points)
        maxScore += 0.5
        let oldIsPatch = oldNode.nodeTypeEntity.patchNodeEntity != nil
        let oldIsLayer = oldNode.nodeTypeEntity.layerNodeEntity != nil

        if (oldIsPatch && newNodeType.isPatch) ||
           (oldIsLayer && newNodeType.isLayer) {
            score += 0.5
        }

        let finalScore = maxScore > 0 ? score / maxScore : 0.0
        log("calculateSimilarity: maxScore: \(maxScore)")
        log("calculateSimilarity: score: \(score)")
        log("calculateSimilarity: finalScore: \(finalScore)")
        return finalScore
    }

    /// Represents a match between an old node and new node with similarity score
    struct NodeMatch {
        let oldNode: NodeEntity
        let newNodeType: PatchOrLayer
        let newNodeId: UUID
        let similarity: Double
    }

    /// Performs one-to-one matching between old nodes and new nodes
    /// Returns matches above threshold, ensuring each old node is matched to at most one new node
    func findOptimalMatches(for newNodes: [(UUID, PatchOrLayer)]) -> [NodeMatch] {
        log("findOptimalMatches: for \(newNodes.count) new nodes")

        // Step 1: Create similarity matrix - calculate all possible matches
        var candidateMatches: [NodeMatch] = []
        let threshold = 0.5

        for (newNodeId, newNodeType) in newNodes {
            for oldNode in oldNodes {
                let similarity = calculateSimilarity(oldNode: oldNode, newNodeType: newNodeType)
                if similarity >= threshold {
                    candidateMatches.append(NodeMatch(
                        oldNode: oldNode,
                        newNodeType: newNodeType,
                        newNodeId: newNodeId,
                        similarity: similarity
                    ))
                }
            }
        }

        log("findOptimalMatches: found \(candidateMatches.count) candidate matches above threshold")

        // Step 2: Sort by similarity score (highest first) for greedy assignment
        candidateMatches.sort { $0.similarity > $1.similarity }

        // Step 3: Greedy one-to-one assignment
        var finalMatches: [NodeMatch] = []
        var usedOldNodeIds = Set<UUID>()
        var usedNewNodeIds = Set<UUID>()

        for candidate in candidateMatches {
            // Skip if either node is already matched
            if usedOldNodeIds.contains(candidate.oldNode.id) ||
               usedNewNodeIds.contains(candidate.newNodeId) {
                continue
            }

            // Accept this match and mark both nodes as used
            finalMatches.append(candidate)
            usedOldNodeIds.insert(candidate.oldNode.id)
            usedNewNodeIds.insert(candidate.newNodeId)

            log("findOptimalMatches: accepted match - old: \(candidate.oldNode.id) (\(candidate.oldNode.kind)) -> new: \(candidate.newNodeId) (\(candidate.newNodeType)), similarity: \(candidate.similarity)")
        }

        log("findOptimalMatches: final \(finalMatches.count) one-to-one matches")
        return finalMatches
    }

    /// Extracts input values from a NodeEntity
    func extractInputValues(from node: NodeEntity) -> [[PortValue]] {
        switch node.nodeTypeEntity {
        case .patch(let patchNodeEntity):
            return patchNodeEntity.inputs.compactMap { inputEntity in
                switch inputEntity.portData {
                case .values(let values):
                    log("extractInputValues: patch: for node \(node.id) \(node.kind), had input values: \(values)")
                    return values
                case .upstreamConnection:
                    log("extractInputValues: patch: for node \(node.id) \(node.kind), had an upstream connection and thus no input values")
                    return [] // Connected inputs don't have direct values
                }
            }
        case .layer(let layerNodeEntity):
            // Extract values from the main layer input ports
            var allValues: [[PortValue]] = []

            // Sample key ports for similarity analysis
            // TODO: Should we check more layer inputs down the road?
            let keyPorts = [
                layerNodeEntity.positionPort,
                layerNodeEntity.sizePort,
                layerNodeEntity.colorPort,
                layerNodeEntity.opacityPort,
                layerNodeEntity.rotationZPort
            ]

            for port in keyPorts {
                switch port.packedData.inputPort {
                case .values(let values):
                    allValues.append(values)
                case .upstreamConnection:
                    allValues.append([]) // Connected ports don't have direct values
                }

                // Also check unpacked data for loop connections
                for unpackedData in port.unpackedData {
                    switch unpackedData.inputPort {
                    case .values(let values):
                        allValues.append(values)
                    case .upstreamConnection:
                        allValues.append([])
                    }
                }
            }

            log("extractInputValues: layer: for node \(node.id) \(node.kind), had input values: allValues: \(allValues)")
            return allValues
        case .group:
            // TODO: Handle group node input extraction
            return []
        case .component:
            // TODO: Handle component node input extraction
            return []
        }
    }

    /// Extracts connection counts from a NodeEntity
    func extractConnectionCounts(from node: NodeEntity) -> (upstream: Int, downstream: Int) {
        switch node.nodeTypeEntity {
        case .patch(let patchNodeEntity):
            let upstreamCount = patchNodeEntity.inputs.reduce(0) { count, inputEntity in
                switch inputEntity.portData {
                case .upstreamConnection(let x):
                    log("extractConnectionCounts: patch: for node \(node.id) \(node.kind) and input \(inputEntity.id), had an upstream connection: \(x)")
                    return count + 1
                case .values:
                    log("extractConnectionCounts: patch: for node \(node.id) \(node.kind) and input \(inputEntity.id) had values")
                    return count
                }
            }
            // For downstream, we estimate based on patch type's typical output count
            // This is less precise than runtime analysis but gives a useful signal
            let downstreamPotential = 1 // Most patches have at least one output
            return (upstreamCount, downstreamPotential)
        case .layer(let layerNodeEntity):
            // Count upstream connections from layer input ports
            let keyPorts = [
                layerNodeEntity.positionPort,
                layerNodeEntity.sizePort,
                layerNodeEntity.colorPort,
                layerNodeEntity.opacityPort,
                layerNodeEntity.rotationZPort
            ]

            var upstreamCount = 0
            for port in keyPorts {
                // Check packed data
                if case .upstreamConnection = port.packedData.inputPort {
                    upstreamCount += 1
                }

                // Check unpacked data
                for unpackedData in port.unpackedData {
                    if case .upstreamConnection = unpackedData.inputPort {
                        upstreamCount += 1
                    }
                }
            }

            // Layers typically have one visual output
            return (upstreamCount, 1)
        case .group:
            // TODO: Handle group node connections
            return (0, 0)
        case .component:
            // TODO: Handle component node connections
            return (0, 0)
        }
    }
}
