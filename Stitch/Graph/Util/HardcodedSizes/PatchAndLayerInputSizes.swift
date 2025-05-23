//
//  PatchAndLayerInputSizes.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/23/25.
//

import Foundation
import SwiftUI

typealias PatchSizes = [Patch: [NodeType?: CGSize]]
typealias LayerInputSizes = [LayerInputPort: CGSize]

extension CGSize {
    // A layer input-fields on the canvas are a single size
    static let ASSUMED_LAYER_FIELD_SIZE: CGSize = .init(width: 200, height: 120)
}

struct PatchOrLayerSizes {
    static let patches: PatchSizes = CANVAS_SIZES_FOR_PATCH_BY_NODE_TYPE
    static let layerInputs: LayerInputSizes = LAYER_INPUT_SIZES_FOR_LAYER_INPUT_PORT
    static let layerFieldSize: CGSize = .ASSUMED_LAYER_FIELD_SIZE
}

// MARK: ONLY TO BE USED WHEN GENERATING NEW HARDCODED SIZE DICTIONARIES FOR "PATCH BY NODE TYPE" AND LAYER INPUTS
struct PSEUDO_SCRIPT_READ_PATCH_NODE_AND_LAYER_INPUT_SIZES: ViewModifier {
    
    @Bindable var document: StitchDocumentViewModel
            
    func body(content: Content) -> some View {
        content.onAppear {
#if DEV_DEBUG || DEBUG
            log("ReadAllPatchAndLayerInputSizes: onAppear")
            // Ensure all layer nodes and their inputs are created before reading sizes
            
            // self.readLayerInputSizes()
             self.readPatchByNodeTypeSizes()
#else
            log("ReadAllPatchAndLayerInputSizes: should not have been called")
#endif
        }
    }
    
    func readLayerInputSizes() {
        let graph = document.visibleGraph
        graph.DEBUG_GENERATING_CANVAS_ITEM_ITEM_SIZES = true
        let _ = document.createAllLayerNodesAndAddAllInputs()
        graph.updateGraphData(document) // Important: update the cache that NodesOnlyView looks at, so nodes will render
        graph.visibleNodesViewModel.setAllCanvasItemsVisible()
     
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) {
            var newSizes: LayerInputSizes = [:]

            // Replace `graph.layerNodeViewModels` with however you retrieve your LayerNodeViewModel instances
            for layerVM in graph.layerNodes() {
                for port in LayerInputPort.allCases {
                    let observer = layerVM[keyPath: port.layerNodeKeyPath].getCanvasItemForWholeInput()
                    if let size = observer?.sizeByLocalBounds {
                        newSizes[port] = size
                    }
                }
            }
            
            // Make sure we handled every case
            for input in LayerInputPort.allCases {
//                assertInDebug(newSizes[input].isDefined)
                if !newSizes[input].isDefined {
                    log("no size for input \(input)")
                }
            }
            
            // Print in a copy-pasteable format
            print("ReadAllPatchAndLayerInputSizes: Captured layerInputSizes:")
            print(newSizes.swiftLayerInputSizesLiteral())
            graph.DEBUG_GENERATING_CANVAS_ITEM_ITEM_SIZES = true
        }
        
    }
    
    func readPatchByNodeTypeSizes() {
        let patchByNodeTypeNodes = document.createAllPatchByNodeTypesCombinations()
        let graph = document.visibleGraph
        graph.updateGraphData(document) // Important: update the cache that NodesOnlyView looks at, so nodes will render
        graph.visibleNodesViewModel.setAllCanvasItemsVisible()
        
        // 45 seconds = roughly enough time for all patch x nodeType combos to be created and rendered on screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 45.0) {
            // Build the nested dictionary
            var newSizes: PatchSizes = [:]
            
            for node in patchByNodeTypeNodes {
                if case let .patch(patchVM) = node.nodeType {
                    let patch     = patchVM.patch
                    let nodeType  = patchVM.userVisibleType
                    if let size      = patchVM.canvasObserver.sizeByLocalBounds {
                        // insert into the nested map
                        newSizes[patch, default: [:]][nodeType] = size
                    }
                    else {
                        // i.e. we did not render the patch x nodeType combon and read its size in time;
                        // may need to allow a larger timegap
                        fatalErrorIfDebug("no size for patch \(patch) with node type \(nodeType)")
                    }
                }
            }
            
            print("ReadAllPatchAndLayerInputSizes: canvasSizes:")
            let literal = newSizes.swiftDictionaryLiteral()
            literal.split(separator: "\n").forEach { print(String($0)) }
        } // DispatchQueue
    }
    
}

extension Dictionary where Key == Patch, Value == [NodeType?: CGSize] {
    /// Generates a Swift source-code literal for a [Patch: [NodeType?: CGSize]] dictionary,
    /// named `CANVAS_SIZES_FOR_PATCH_BY_NODE_TYPE`, using `Optional<NodeType>.none` for missing types.
    func swiftDictionaryLiteral() -> String {
        var lines: [String] = []
        lines.append("let CANVAS_SIZES_FOR_PATCH_BY_NODE_TYPE: [Patch: [NodeType?: CGSize]] = [")
        
        for (patch, innerMap) in self {
            // Build inner entries
            let innerEntries = innerMap.map { (nodeTypeOpt, size) -> String in
                let key = nodeTypeOpt.map { ".\($0)" } ?? "Optional<NodeType>.none"
                return "\(key): CGSize(width: \(Int(size.width)), height: \(Int(size.height)))"
            }.joined(separator: ", ")
            
            // Append with trailing comma
            lines.append("    .\(patch): [\(innerEntries)],")
        }
        
        lines.append("]")
        return lines.joined(separator: "\n")
    }
}


extension Dictionary where Key == LayerInputPort, Value == CGSize {
    /// Generates a Swift source-code literal for a [LayerInputPort: CGSize] dictionary,
    /// named `LAYER_INPUT_SIZES_FOR_LAYER_INPUT_PORT`.
    func swiftLayerInputSizesLiteral() -> String {
        var lines: [String] = []
        lines.append("let LAYER_INPUT_SIZES_FOR_LAYER_INPUT_PORT: [LayerInputPort: CGSize] = [")
        for (port, size) in self {
            lines.append("    .\(port): CGSize(width: \(Int(size.width)), height: \(Int(size.height))),")
        }
        lines.append("]")
        return lines.joined(separator: "\n")
    }
}

// MARK: CREATING ALL PATCH X NODE-TYPE COMBOS AND ADDING ALL LAYER INPUTS TO THE CANVAS

extension StitchDocumentViewModel {
    /// Inserts one patch node for each Patch ▷ NodeType combination.
    /// - Returns: The array of inserted node view models.
    @MainActor
    func createAllPatchByNodeTypesCombinations() -> [NodeViewModel] {
        var createdNodes: [NodeViewModel] = []
        let graph = self.visibleGraph
        
        for patch in Patch.allCases {
            let nodeTypes = patch.availableNodeTypes
            
            // If no specific node types, just insert the default patch node once
            if nodeTypes.isEmpty {
                let node = self.nodeInserted(choice: .patch(patch))
                createdNodes.append(node)
            }
            // Otherwise, insert one node per available type and switch it
            else {
                for nodeType in nodeTypes {
                    let node = self.nodeInserted(choice: .patch(patch))
                    createdNodes.append(node)
                    
                    // Change the newly-inserted node’s type to the desired one
                    guard let oldType = node.userVisibleType else {
                        fatalError("Expected a default type on newly-inserted patch node")
                    }
                    _ = graph.changeType(
                        for: node,
                        oldType: oldType,
                        newType: nodeType,
                        activeIndex: .defaultActiveIndex
                    )
                }
            }
        }
        
        return createdNodes
    }

    /// Creates every layer node and adds all of its inputs to the canvas.
    /// - Returns: The array of inserted layer node view models.
    @MainActor
    func createAllLayerNodesAndAddAllInputs() -> [NodeViewModel] {
        var createdLayers: [NodeViewModel] = []
        for layer in Layer.allCases {
            // Insert the layer node
            let nodeVM = self.nodeInserted(choice: .layer(layer))
            createdLayers.append(nodeVM)
            
            self.visibleGraph.updateGraphData(self)
            
            // For each input port, attempt to add to canvas
            for input in LayerInputPort.allCases {
                self.addLayerInputToCanvas(node: nodeVM,
                                           layerInput: input,
                                           draggedOutput: nil,
                                           canvasHeightOffset: nil)
            }
        }
        return createdLayers
    }
}
