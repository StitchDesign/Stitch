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
let ASSUMED_LAYER_FIELD_SIZE: CGSize = .init(width: 200, height: 120)

struct PatchOrLayerSizes {
    let patches: PatchSizes // = CANVAS_SIZES_FOR_PATCH_BY_NODE_TYPE
    static let layerInputs: LayerInputSizes = LAYER_INPUT_SIZES_FOR_LAYER_INPUT_PORT
    static let layerFieldSize: CGSize = ASSUMED_LAYER_FIELD_SIZE
}

struct ReadAllPatchAndLayerInputSizes: ViewModifier {
    
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

let LAYER_INPUT_SIZES_FOR_LAYER_INPUT_PORT: [LayerInputPort: CGSize] = [
    .orientation: CGSize(width: 318, height: 97),
    .isShadowsEnabled: CGSize(width: 261, height: 97),
    .scrollJumpToXStyle: CGSize(width: 324, height: 97),
    .enabled: CGSize(width: 187, height: 97),
    .verticalAlignment: CGSize(width: 425, height: 97),
    .contrast: CGSize(width: 266, height: 97),
    .cameraDirection: CGSize(width: 352, height: 97),
    .shape: CGSize(width: 225, height: 97),
    .scrollYEnabled: CGSize(width: 250, height: 97),
    .offsetInGroup: CGSize(width: 468, height: 97),
    .centerAnchor: CGSize(width: 277, height: 97),
    .sizingScenario: CGSize(width: 277, height: 97),
    .shadowOpacity: CGSize(width: 318, height: 97),
    .fitStyle: CGSize(width: 290, height: 97),
    .fontSize: CGSize(width: 281, height: 97),
    .itemAlignmentWithinGridCell: CGSize(width: 278, height: 97),
    .blendMode: CGSize(width: 316, height: 97),
    .placeholderText: CGSize(width: 261, height: 97),
    .saturation: CGSize(width: 277, height: 97),
    .model3D: CGSize(width: 291, height: 97),
    .brightness: CGSize(width: 280, height: 97),
    .blur: CGSize(width: 235, height: 97),
    .scrollJumpToX: CGSize(width: 210, height: 97),
    .transform3D: CGSize(width: 272, height: 97),
    .endAngle: CGSize(width: 276, height: 97),
    .isPinned: CGSize(width: 188, height: 97),
    .isClipped: CGSize(width: 193, height: 97),
    .color: CGSize(width: 176, height: 97),
    .spacingBetweenGridColumns: CGSize(width: 318, height: 97),
    .pinAnchor: CGSize(width: 253, height: 97),
    .scrollJumpToXLocation: CGSize(width: 316, height: 97),
    .strokeWidth: CGSize(width: 295, height: 97),
    .hueRotation: CGSize(width: 295, height: 97),
    .maxSize: CGSize(width: 425, height: 97),
    .textFont: CGSize(width: 385, height: 97),
    .text: CGSize(width: 210, height: 97),
    .widthAxis: CGSize(width: 280, height: 97),
    .scrollXEnabled: CGSize(width: 250, height: 97),
    .backgroundColor: CGSize(width: 260, height: 97),
    .endColor: CGSize(width: 226, height: 97),
    .opacity: CGSize(width: 260, height: 97),
    .size3D: CGSize(width: 501, height: 97),
    .rotationX: CGSize(width: 278, height: 97),
    .isEntityAnimating: CGSize(width: 210, height: 97),
    .minSize: CGSize(width: 422, height: 97),
    .spacingBetweenGridRows: CGSize(width: 295, height: 97),
    .translation3DEnabled: CGSize(width: 215, height: 97),
    .rotation3DEnabled: CGSize(width: 198, height: 97),
    .startColor: CGSize(width: 226, height: 97),
    .zIndex: CGSize(width: 257, height: 97),
    .cornerRadius: CGSize(width: 303, height: 97),
    .pinOffset: CGSize(width: 432, height: 97),
    .canvasLineWidth: CGSize(width: 280, height: 97),
    .scrollContentSize: CGSize(width: 451, height: 97),
    .volume: CGSize(width: 258, height: 97),
    .scrollJumpToYLocation: CGSize(width: 316, height: 97),
    .strokeLineJoin: CGSize(width: 343, height: 97),
    .isSwitchToggled: CGSize(width: 220, height: 97),
    .anchoring: CGSize(width: 249, height: 97),
    .radius3D: CGSize(width: 254, height: 97),
    .startAngle: CGSize(width: 283, height: 97),
    .video: CGSize(width: 285, height: 97),
    .startAnchor: CGSize(width: 264, height: 97),
    .isScrollAuto: CGSize(width: 214, height: 97),
    .contentMode: CGSize(width: 331, height: 97),
    .position: CGSize(width: 390, height: 97),
    .strokeColor: CGSize(width: 223, height: 97),
    .scrollJumpToYStyle: CGSize(width: 324, height: 97),
    .shadowRadius: CGSize(width: 311, height: 97),
    .strokePosition: CGSize(width: 336, height: 97),
    .progressIndicatorStyle: CGSize(width: 270, height: 97),
    .startRadius: CGSize(width: 289, height: 97),
    .setupMode: CGSize(width: 222, height: 97),
    .colorInvert: CGSize(width: 219, height: 97),
    .scale: CGSize(width: 245, height: 97),
    .strokeStart: CGSize(width: 287, height: 97),
    .height3D: CGSize(width: 253, height: 97),
    .textAlignment: CGSize(width: 371, height: 97),
    .rotationZ: CGSize(width: 277, height: 97),
    .videoURL: CGSize(width: 252, height: 97),
    .mapSpan: CGSize(width: 370, height: 97),
    .layerMargin: CGSize(width: 738, height: 97),
    .layerPadding: CGSize(width: 747, height: 97),
    .deviceAppearance: CGSize(width: 366, height: 97),
    .textDecoration: CGSize(width: 377, height: 97),
    .clipped: CGSize(width: 193, height: 97),
    .strokeEnd: CGSize(width: 280, height: 97),
    .size: CGSize(width: 394, height: 97),
    .isMetallic: CGSize(width: 194, height: 97),
    .anchorEntity: CGSize(width: 250, height: 97),
    .layerGroupAlignment: CGSize(width: 244, height: 97),
    .pinTo: CGSize(width: 195, height: 97),
    .pivot: CGSize(width: 214, height: 97),
    .strokeLineCap: CGSize(width: 341, height: 97),
    .endAnchor: CGSize(width: 257, height: 97),
    .image: CGSize(width: 287, height: 97),
    .canvasLineColor: CGSize(width: 228, height: 97),
    .endRadius: CGSize(width: 283, height: 97),
    .mapLatLong: CGSize(width: 396, height: 97),
    .scrollJumpToY: CGSize(width: 209, height: 97),
    .masks: CGSize(width: 184, height: 97),
    .coordinateSystem: CGSize(width: 363, height: 97),
    .isAnimating: CGSize(width: 246, height: 97),
    .heightAxis: CGSize(width: 285, height: 97),
    .mapType: CGSize(width: 302, height: 97),
    .shadowOffset: CGSize(width: 436, height: 97),
    .progress: CGSize(width: 267, height: 97),
    .isCameraEnabled: CGSize(width: 251, height: 97),
    .sfSymbol: CGSize(width: 253, height: 97),
    .shadowColor: CGSize(width: 234, height: 97),
    .materialThickness: CGSize(width: 290, height: 97),
    .rotationY: CGSize(width: 277, height: 97),
    .scale3DEnabled: CGSize(width: 178, height: 97),
    .spacing: CGSize(width: 263, height: 97),
]


//let CANVAS_SIZES_FOR_PATCH_BY_NODE_TYPE: [Patch: [NodeType?: CGSize]] = [
//    .point4DUnpack: [Optional<NodeType>.none: CGSize(width: 188, height: 181)],
//    .textEndsWith: [Optional<NodeType>.none: CGSize(width: 239, height: 125)],
//    .dateAndTimeFormatter: [Optional<NodeType>.none: CGSize(width: 343, height: 153)],
//    .grayscale: [Optional<NodeType>.none: CGSize(width: 392, height: 97)],
//    .wirelessBroadcaster: [.point3D: CGSize(width: 453, height: 97), .networkRequestType: CGSize(width: 244, height: 97), .shapeCommand: CGSize(width: 428, height: 97), .cameraOrientation: CGSize(width: 244, height: 97), .padding: CGSize(width: 659, height: 97), .anchoring: CGSize(width: 210, height: 97), .pulse: CGSize(width: 210, height: 97), .textFont: CGSize(width: 332, height: 97), .sizingScenario: CGSize(width: 244, height: 97), .shape: CGSize(width: 210, height: 97), .transform: CGSize(width: 210, height: 97), .json: CGSize(width: 210, height: 97), .orientation: CGSize(width: 280, height: 97), .interactionId: CGSize(width: 210, height: 97), .layerDimension: CGSize(width: 228, height: 97), .size: CGSize(width: 373, height: 97), .bool: CGSize(width: 210, height: 97), .pinToId: CGSize(width: 210, height: 97), .spacing: CGSize(width: 216, height: 97), .cameraDirection: CGSize(width: 244, height: 97), .fitStyle: CGSize(width: 244, height: 97), .animationCurve: CGSize(width: 244, height: 97), .textDecoration: CGSize(width: 280, height: 97), .point4D: CGSize(width: 568, height: 97), .number: CGSize(width: 216, height: 97), .color: CGSize(width: 210, height: 97), .layerStroke: CGSize(width: 244, height: 97), .string: CGSize(width: 210, height: 97), .position: CGSize(width: 344, height: 97), .media: CGSize(width: 210, height: 97)],
//    .valueAtIndex: [.pulse: CGSize(width: 346, height: 125), .orientation: CGSize(width: 346, height: 125), .string: CGSize(width: 346, height: 125), .textDecoration: CGSize(width: 346, height: 125), .interactionId: CGSize(width: 346, height: 125), .layerDimension: CGSize(width: 346, height: 125), .layerStroke: CGSize(width: 346, height: 125), .position: CGSize(width: 346, height: 125), .textFont: CGSize(width: 346, height: 125), .color: CGSize(width: 346, height: 125), .json: CGSize(width: 346, height: 125), .spacing: CGSize(width: 346, height: 125), .transform: CGSize(width: 346, height: 125), .cameraDirection: CGSize(width: 346, height: 125), .cameraOrientation: CGSize(width: 346, height: 125), .bool: CGSize(width: 346, height: 125), .networkRequestType: CGSize(width: 346, height: 125), .pinToId: CGSize(width: 346, height: 125), .point3D: CGSize(width: 346, height: 125), .padding: CGSize(width: 346, height: 125), .anchoring: CGSize(width: 346, height: 125), .number: CGSize(width: 346, height: 125), .animationCurve: CGSize(width: 346, height: 125), .point4D: CGSize(width: 346, height: 125), .sizingScenario: CGSize(width: 346, height: 125), .media: CGSize(width: 346, height: 125), .size: CGSize(width: 346, height: 125), .shape: CGSize(width: 346, height: 125), .shapeCommand: CGSize(width: 346, height: 125), .fitStyle: CGSize(width: 346, height: 125)],
//    .hexColor: [Optional<NodeType>.none: CGSize(width: 269, height: 97)],
//    .valueForKey: [.padding: CGSize(width: 308, height: 125), .number: CGSize(width: 310, height: 125), .color: CGSize(width: 308, height: 125), .orientation: CGSize(width: 308, height: 125), .bool: CGSize(width: 270, height: 125), .textDecoration: CGSize(width: 308, height: 125), .point3D: CGSize(width: 308, height: 125), .anchoring: CGSize(width: 308, height: 125), .spacing: CGSize(width: 308, height: 125), .size: CGSize(width: 308, height: 125), .pulse: CGSize(width: 308, height: 125), .textFont: CGSize(width: 308, height: 125), .interactionId: CGSize(width: 308, height: 125), .json: CGSize(width: 308, height: 125), .pinToId: CGSize(width: 308, height: 125), .string: CGSize(width: 310, height: 125), .position: CGSize(width: 308, height: 125), .transform: CGSize(width: 308, height: 125), .networkRequestType: CGSize(width: 308, height: 125), .layerDimension: CGSize(width: 308, height: 125), .shape: CGSize(width: 308, height: 125), .layerStroke: CGSize(width: 308, height: 125), .cameraOrientation: CGSize(width: 308, height: 125), .animationCurve: CGSize(width: 308, height: 125), .cameraDirection: CGSize(width: 308, height: 125), .media: CGSize(width: 308, height: 125), .shapeCommand: CGSize(width: 308, height: 125), .fitStyle: CGSize(width: 308, height: 125), .point4D: CGSize(width: 308, height: 125), .sizingScenario: CGSize(width: 308, height: 125)],
//    .loopReverse: [.fitStyle: CGSize(width: 327, height: 97), .animationCurve: CGSize(width: 327, height: 97), .bool: CGSize(width: 192, height: 97), .cameraOrientation: CGSize(width: 327, height: 97), .number: CGSize(width: 299, height: 97), .layerStroke: CGSize(width: 327, height: 97), .layerDimension: CGSize(width: 311, height: 97), .anchoring: CGSize(width: 269, height: 97), .interactionId: CGSize(width: 251, height: 97), .orientation: CGSize(width: 363, height: 97), .transform: CGSize(width: 273, height: 97), .cameraDirection: CGSize(width: 327, height: 97), .color: CGSize(width: 189, height: 97), .spacing: CGSize(width: 299, height: 97), .sizingScenario: CGSize(width: 327, height: 97), .json: CGSize(width: 231, height: 97), .shape: CGSize(width: 273, height: 97), .textDecoration: CGSize(width: 363, height: 97), .networkRequestType: CGSize(width: 327, height: 97), .pulse: CGSize(width: 193, height: 97), .textFont: CGSize(width: 415, height: 97), .padding: CGSize(width: 1108, height: 97), .size: CGSize(width: 564, height: 97), .string: CGSize(width: 273, height: 97), .shapeCommand: CGSize(width: 511, height: 97), .point4D: CGSize(width: 925, height: 97), .pinToId: CGSize(width: 247, height: 97), .position: CGSize(width: 529, height: 97), .media: CGSize(width: 177, height: 97), .point3D: CGSize(width: 722, height: 97)],
//    .roundedRectangleShape: [Optional<NodeType>.none: CGSize(width: 503, height: 153)],
//    .loopSelect: [.cameraDirection: CGSize(width: 384, height: 125), .shape: CGSize(width: 384, height: 125), .position: CGSize(width: 572, height: 125), .spacing: CGSize(width: 384, height: 125), .textDecoration: CGSize(width: 409, height: 125), .networkRequestType: CGSize(width: 384, height: 125), .animationCurve: CGSize(width: 384, height: 125), .orientation: CGSize(width: 409, height: 125), .point4D: CGSize(width: 968, height: 125), .padding: CGSize(width: 1151, height: 125), .shapeCommand: CGSize(width: 557, height: 125), .anchoring: CGSize(width: 384, height: 125), .pulse: CGSize(width: 384, height: 125), .pinToId: CGSize(width: 384, height: 125), .interactionId: CGSize(width: 384, height: 125), .textFont: CGSize(width: 461, height: 125), .fitStyle: CGSize(width: 384, height: 125), .layerDimension: CGSize(width: 384, height: 125), .sizingScenario: CGSize(width: 384, height: 125), .media: CGSize(width: 384, height: 125), .bool: CGSize(width: 384, height: 125), .point3D: CGSize(width: 765, height: 125), .number: CGSize(width: 384, height: 125), .color: CGSize(width: 384, height: 125), .transform: CGSize(width: 384, height: 125), .string: CGSize(width: 384, height: 125), .json: CGSize(width: 384, height: 125), .cameraOrientation: CGSize(width: 384, height: 125), .layerStroke: CGSize(width: 384, height: 125), .size: CGSize(width: 607, height: 125)],
//    .textLength: [Optional<NodeType>.none: CGSize(width: 268, height: 97)],
//    .sampleAndHold: [.networkRequestType: CGSize(width: 331, height: 153), .anchoring: CGSize(width: 273, height: 153), .point3D: CGSize(width: 726, height: 153), .bool: CGSize(width: 209, height: 153), .shapeCommand: CGSize(width: 515, height: 153), .shape: CGSize(width: 277, height: 153), .size: CGSize(width: 568, height: 153), .cameraOrientation: CGSize(width: 331, height: 153), .layerStroke: CGSize(width: 331, height: 153), .textFont: CGSize(width: 419, height: 153), .point4D: CGSize(width: 929, height: 153), .cameraDirection: CGSize(width: 331, height: 153), .pinToId: CGSize(width: 250, height: 153), .pulse: CGSize(width: 210, height: 153), .animationCurve: CGSize(width: 331, height: 153), .media: CGSize(width: 202, height: 153), .textDecoration: CGSize(width: 367, height: 153), .number: CGSize(width: 303, height: 153), .padding: CGSize(width: 1112, height: 153), .spacing: CGSize(width: 303, height: 153), .color: CGSize(width: 208, height: 153), .layerDimension: CGSize(width: 315, height: 153), .sizingScenario: CGSize(width: 331, height: 153), .fitStyle: CGSize(width: 331, height: 153), .interactionId: CGSize(width: 255, height: 153), .transform: CGSize(width: 277, height: 153), .string: CGSize(width: 277, height: 153), .orientation: CGSize(width: 367, height: 153), .position: CGSize(width: 533, height: 153), .json: CGSize(width: 248, height: 153)],
//    .point4DPack: [Optional<NodeType>.none: CGSize(width: 214, height: 181)],
//    .loopOverArray: [Optional<NodeType>.none: CGSize(width: 281, height: 125)],
//    .colorToHSL: [Optional<NodeType>.none: CGSize(width: 267, height: 181)],
//    .absoluteValue: [Optional<NodeType>.none: CGSize(width: 258, height: 97)],
//    .progress: [Optional<NodeType>.none: CGSize(width: 303, height: 153)],
//    .mod: [.point3D: CGSize(width: 681, height: 125), .size: CGSize(width: 523, height: 125), .number: CGSize(width: 258, height: 125), .color: CGSize(width: 148, height: 125), .position: CGSize(width: 488, height: 125)],
//    .hapticFeedback: [Optional<NodeType>.none: CGSize(width: 270, height: 125)],
//    .smoothValue: [Optional<NodeType>.none: CGSize(width: 404, height: 153)],
//    .arrayCount: [Optional<NodeType>.none: CGSize(width: 236, height: 97)],
//    .loopFilter: [.textFont: CGSize(width: 461, height: 125), .fitStyle: CGSize(width: 373, height: 125), .media: CGSize(width: 360, height: 125), .cameraOrientation: CGSize(width: 373, height: 125), .bool: CGSize(width: 360, height: 125), .transform: CGSize(width: 360, height: 125), .anchoring: CGSize(width: 360, height: 125), .size: CGSize(width: 607, height: 125), .animationCurve: CGSize(width: 373, height: 125), .padding: CGSize(width: 1151, height: 125), .string: CGSize(width: 360, height: 125), .json: CGSize(width: 360, height: 125), .orientation: CGSize(width: 409, height: 125), .number: CGSize(width: 360, height: 125), .sizingScenario: CGSize(width: 373, height: 125), .networkRequestType: CGSize(width: 373, height: 125), .shape: CGSize(width: 360, height: 125), .color: CGSize(width: 360, height: 125), .position: CGSize(width: 572, height: 125), .cameraDirection: CGSize(width: 373, height: 125), .interactionId: CGSize(width: 360, height: 125), .textDecoration: CGSize(width: 409, height: 125), .point4D: CGSize(width: 968, height: 125), .layerDimension: CGSize(width: 360, height: 125), .pulse: CGSize(width: 360, height: 125), .layerStroke: CGSize(width: 373, height: 125), .point3D: CGSize(width: 765, height: 125), .pinToId: CGSize(width: 360, height: 125), .spacing: CGSize(width: 360, height: 125), .shapeCommand: CGSize(width: 557, height: 125)],
//    .transformPack: [Optional<NodeType>.none: CGSize(width: 270, height: 321)],
//    .base64StringToImage: [Optional<NodeType>.none: CGSize(width: 184, height: 97)],
//    .lessThanOrEqual: [Optional<NodeType>.none: CGSize(width: 217, height: 125)],
//    .subarray: [Optional<NodeType>.none: CGSize(width: 390, height: 153)],
//    .lessThan: [Optional<NodeType>.none: CGSize(width: 217, height: 125)],
//    .point3DPack: [Optional<NodeType>.none: CGSize(width: 210, height: 153)],
//    .time: [Optional<NodeType>.none: CGSize(width: 224, height: 125)],
//    .max: [.color: CGSize(width: 148, height: 125), .position: CGSize(width: 488, height: 125), .point3D: CGSize(width: 681, height: 125), .number: CGSize(width: 258, height: 125), .string: CGSize(width: 232, height: 125), .size: CGSize(width: 523, height: 125)],
//    .loopBuilder: [.point4D: CGSize(width: 936, height: 209), .pinToId: CGSize(width: 258, height: 209), .media: CGSize(width: 321, height: 209), .bool: CGSize(width: 236, height: 209), .number: CGSize(width: 310, height: 209), .padding: CGSize(width: 1119, height: 209), .networkRequestType: CGSize(width: 338, height: 209), .shapeCommand: CGSize(width: 522, height: 209), .layerStroke: CGSize(width: 338, height: 209), .textDecoration: CGSize(width: 374, height: 209), .textFont: CGSize(width: 426, height: 209), .pulse: CGSize(width: 237, height: 209), .anchoring: CGSize(width: 280, height: 209), .transform: CGSize(width: 284, height: 209), .interactionId: CGSize(width: 262, height: 209), .fitStyle: CGSize(width: 338, height: 209), .cameraOrientation: CGSize(width: 338, height: 209), .sizingScenario: CGSize(width: 338, height: 209), .orientation: CGSize(width: 374, height: 209), .point3D: CGSize(width: 733, height: 209), .json: CGSize(width: 242, height: 209), .shape: CGSize(width: 284, height: 209), .layerDimension: CGSize(width: 322, height: 209), .color: CGSize(width: 235, height: 209), .string: CGSize(width: 284, height: 209), .animationCurve: CGSize(width: 338, height: 209), .size: CGSize(width: 575, height: 209), .position: CGSize(width: 540, height: 209), .cameraDirection: CGSize(width: 338, height: 209), .spacing: CGSize(width: 310, height: 209)],
//    .loopSum: [Optional<NodeType>.none: CGSize(width: 299, height: 97)],
//    .repeatingPulse: [Optional<NodeType>.none: CGSize(width: 297, height: 97)],
//    .clip: [Optional<NodeType>.none: CGSize(width: 303, height: 153)],
//    .textReplace: [Optional<NodeType>.none: CGSize(width: 298, height: 181)],
//    .getKeys: [Optional<NodeType>.none: CGSize(width: 242, height: 97)],
//    .mouse: [Optional<NodeType>.none: CGSize(width: 338, height: 153)],
//    .mathExpression: [Optional<NodeType>.none: CGSize(width: 179, height: 97)],
//    .arcTan2: [Optional<NodeType>.none: CGSize(width: 276, height: 125)],
//    .networkRequest: [.media: CGSize(width: 408, height: 237), .string: CGSize(width: 408, height: 237), .json: CGSize(width: 408, height: 237)],
//    .textStartsWith: [Optional<NodeType>.none: CGSize(width: 238, height: 125)],
//    .loopCount: [Optional<NodeType>.none: CGSize(width: 299, height: 97)],
//    .colorToRGB: [Optional<NodeType>.none: CGSize(width: 238, height: 181)],
//    .springFromResponseAndDampingRatio: [Optional<NodeType>.none: CGSize(width: 432, height: 125)],
//    .cubicBezierAnimation: [.number: CGSize(width: 536, height: 237)],
//    .delay: [.number: CGSize(width: 373, height: 153)],
//    .whenPrototypeStarts: [Optional<NodeType>.none: CGSize(width: 192, height: 97)],
//    .optionSwitch: [Optional<NodeType>.none: CGSize(width: 266, height: 153)],
//    .wirelessReceiver: [.number: CGSize(width: 190, height: 97)],
//    .repeatingAnimation: [Optional<NodeType>.none: CGSize(width: 401, height: 209)],
//    .videoImport: [Optional<NodeType>.none: CGSize(width: 436, height: 209)],
//    .unpack: [.shapeCommand: CGSize(width: 614, height: 125), .transform: CGSize(width: 307, height: 125), .point4D: CGSize(width: 628, height: 125), .size: CGSize(width: 438, height: 125), .point3D: CGSize(width: 513, height: 125), .position: CGSize(width: 404, height: 125)],
//    .loopToArray: [.pulse: CGSize(width: 231, height: 97), .point3D: CGSize(width: 535, height: 97), .transform: CGSize(width: 271, height: 97), .size: CGSize(width: 455, height: 97), .animationCurve: CGSize(width: 325, height: 97), .networkRequestType: CGSize(width: 325, height: 97), .position: CGSize(width: 425, height: 97), .sizingScenario: CGSize(width: 325, height: 97), .spacing: CGSize(width: 297, height: 97), .point4D: CGSize(width: 649, height: 97), .shape: CGSize(width: 271, height: 97), .json: CGSize(width: 231, height: 97), .number: CGSize(width: 297, height: 97), .cameraOrientation: CGSize(width: 325, height: 97), .cameraDirection: CGSize(width: 325, height: 97), .color: CGSize(width: 229, height: 97), .textDecoration: CGSize(width: 361, height: 97), .padding: CGSize(width: 741, height: 97), .orientation: CGSize(width: 361, height: 97), .bool: CGSize(width: 231, height: 97), .anchoring: CGSize(width: 269, height: 97), .layerDimension: CGSize(width: 309, height: 97), .textFont: CGSize(width: 413, height: 97), .interactionId: CGSize(width: 249, height: 97), .string: CGSize(width: 271, height: 97), .shapeCommand: CGSize(width: 509, height: 97), .media: CGSize(width: 223, height: 97), .pinToId: CGSize(width: 245, height: 97), .layerStroke: CGSize(width: 325, height: 97), .fitStyle: CGSize(width: 325, height: 97)],
//    .springFromDurationAndBounce: [Optional<NodeType>.none: CGSize(width: 392, height: 125)],
//    .optionPicker: [.cameraDirection: CGSize(width: 311, height: 153), .interactionId: CGSize(width: 311, height: 153), .pinToId: CGSize(width: 311, height: 153), .orientation: CGSize(width: 322, height: 153), .cameraOrientation: CGSize(width: 311, height: 153), .shapeCommand: CGSize(width: 470, height: 153), .padding: CGSize(width: 1067, height: 153), .bool: CGSize(width: 271, height: 153), .layerStroke: CGSize(width: 311, height: 153), .size: CGSize(width: 523, height: 153), .position: CGSize(width: 488, height: 153), .fitStyle: CGSize(width: 311, height: 153), .number: CGSize(width: 311, height: 153), .json: CGSize(width: 309, height: 153), .layerDimension: CGSize(width: 311, height: 153), .transform: CGSize(width: 311, height: 153), .networkRequestType: CGSize(width: 311, height: 153), .textFont: CGSize(width: 374, height: 153), .textDecoration: CGSize(width: 322, height: 153), .point4D: CGSize(width: 884, height: 153), .color: CGSize(width: 269, height: 153), .pulse: CGSize(width: 271, height: 153), .point3D: CGSize(width: 681, height: 153), .animationCurve: CGSize(width: 311, height: 153), .media: CGSize(width: 263, height: 153), .sizingScenario: CGSize(width: 311, height: 153), .spacing: CGSize(width: 311, height: 153), .string: CGSize(width: 311, height: 153), .anchoring: CGSize(width: 309, height: 153), .shape: CGSize(width: 311, height: 153)],
//    .add: [.color: CGSize(width: 148, height: 125), .number: CGSize(width: 258, height: 125), .point3D: CGSize(width: 681, height: 125), .string: CGSize(width: 232, height: 125), .position: CGSize(width: 488, height: 125), .size: CGSize(width: 523, height: 125)],
//    .arrayAppend: [Optional<NodeType>.none: CGSize(width: 294, height: 153)],
//    .greaterThan: [Optional<NodeType>.none: CGSize(width: 217, height: 125)],
//    .ovalShape: [Optional<NodeType>.none: CGSize(width: 503, height: 125)],
//    .setValueForKey: [.pulse: CGSize(width: 316, height: 153), .cameraDirection: CGSize(width: 382, height: 153), .shapeCommand: CGSize(width: 566, height: 153), .size: CGSize(width: 511, height: 153), .media: CGSize(width: 316, height: 153), .textFont: CGSize(width: 470, height: 153), .animationCurve: CGSize(width: 382, height: 153), .sizingScenario: CGSize(width: 382, height: 153), .json: CGSize(width: 316, height: 153), .networkRequestType: CGSize(width: 382, height: 153), .fitStyle: CGSize(width: 382, height: 153), .layerStroke: CGSize(width: 382, height: 153), .number: CGSize(width: 354, height: 153), .cameraOrientation: CGSize(width: 382, height: 153), .color: CGSize(width: 316, height: 153), .string: CGSize(width: 328, height: 153), .shape: CGSize(width: 328, height: 153), .point3D: CGSize(width: 591, height: 153), .bool: CGSize(width: 316, height: 153), .pinToId: CGSize(width: 316, height: 153), .point4D: CGSize(width: 706, height: 153), .transform: CGSize(width: 328, height: 153), .anchoring: CGSize(width: 326, height: 153), .interactionId: CGSize(width: 316, height: 153), .layerDimension: CGSize(width: 366, height: 153), .padding: CGSize(width: 797, height: 153), .textDecoration: CGSize(width: 418, height: 153), .spacing: CGSize(width: 354, height: 153), .orientation: CGSize(width: 418, height: 153), .position: CGSize(width: 482, height: 153)],
//    .curve: [Optional<NodeType>.none: CGSize(width: 401, height: 125)],
//    .popAnimation: [.anchoring: CGSize(width: 342, height: 153), .color: CGSize(width: 302, height: 153), .position: CGSize(width: 533, height: 153), .point3D: CGSize(width: 726, height: 153), .point4D: CGSize(width: 929, height: 153), .number: CGSize(width: 344, height: 153), .size: CGSize(width: 568, height: 153)],
//    .counter: [Optional<NodeType>.none: CGSize(width: 377, height: 209)],
//    .multiply: [.point3D: CGSize(width: 681, height: 125), .position: CGSize(width: 488, height: 125), .color: CGSize(width: 148, height: 125), .size: CGSize(width: 523, height: 125), .number: CGSize(width: 258, height: 125)],
//    .power: [.point3D: CGSize(width: 681, height: 125), .position: CGSize(width: 488, height: 125), .number: CGSize(width: 258, height: 125), .size: CGSize(width: 523, height: 125)],
//    .deviceInfo: [Optional<NodeType>.none: CGSize(width: 368, height: 265)],
//    .dragInteraction: [Optional<NodeType>.none: CGSize(width: 616, height: 293)],
//    .divide: [.point3D: CGSize(width: 681, height: 125), .number: CGSize(width: 258, height: 125), .size: CGSize(width: 523, height: 125), .color: CGSize(width: 148, height: 125), .position: CGSize(width: 488, height: 125)],
//    .microphone: [Optional<NodeType>.none: CGSize(width: 348, height: 153)],
//    .loop: [Optional<NodeType>.none: CGSize(width: 352, height: 97)],
//    .springAnimation: [.number: CGSize(width: 326, height: 181), .color: CGSize(width: 284, height: 181), .size: CGSize(width: 568, height: 181), .anchoring: CGSize(width: 324, height: 181), .position: CGSize(width: 533, height: 181), .point4D: CGSize(width: 929, height: 181), .point3D: CGSize(width: 726, height: 181)],
//    .cameraFeed: [Optional<NodeType>.none: CGSize(width: 513, height: 153)],
//    .arraySort: [Optional<NodeType>.none: CGSize(width: 269, height: 125)],
//    .or: [Optional<NodeType>.none: CGSize(width: 151, height: 125)],
//    .bouncyConverter: [.number: CGSize(width: 403, height: 125)],
//    .equalsExactly: [.transform: CGSize(width: 191, height: 125), .cameraDirection: CGSize(width: 245, height: 125), .number: CGSize(width: 217, height: 125), .textDecoration: CGSize(width: 281, height: 125), .point4D: CGSize(width: 569, height: 125), .color: CGSize(width: 165, height: 125), .layerStroke: CGSize(width: 245, height: 125), .interactionId: CGSize(width: 169, height: 125), .layerDimension: CGSize(width: 229, height: 125), .shapeCommand: CGSize(width: 429, height: 125), .media: CGSize(width: 165, height: 125), .textFont: CGSize(width: 333, height: 125), .networkRequestType: CGSize(width: 245, height: 125), .json: CGSize(width: 165, height: 125), .bool: CGSize(width: 165, height: 125), .size: CGSize(width: 375, height: 125), .fitStyle: CGSize(width: 245, height: 125), .point3D: CGSize(width: 455, height: 125), .pinToId: CGSize(width: 165, height: 125), .position: CGSize(width: 345, height: 125), .orientation: CGSize(width: 281, height: 125), .string: CGSize(width: 191, height: 125), .pulse: CGSize(width: 165, height: 125), .anchoring: CGSize(width: 189, height: 125), .shape: CGSize(width: 191, height: 125), .cameraOrientation: CGSize(width: 245, height: 125), .animationCurve: CGSize(width: 245, height: 125), .padding: CGSize(width: 661, height: 125), .sizingScenario: CGSize(width: 245, height: 125), .spacing: CGSize(width: 217, height: 125)],
//    .arRaycasting: [Optional<NodeType>.none: CGSize(width: 362, height: 209)],
//    .layerInfo: [Optional<NodeType>.none: CGSize(width: 419, height: 293)],
//    .min: [.number: CGSize(width: 258, height: 125), .position: CGSize(width: 488, height: 125), .string: CGSize(width: 232, height: 125), .point3D: CGSize(width: 681, height: 125), .color: CGSize(width: 148, height: 125), .size: CGSize(width: 523, height: 125)],
//    .arAnchor: [Optional<NodeType>.none: CGSize(width: 387, height: 97)],
//    .optionSender: [.orientation: CGSize(width: 378, height: 153), .cameraOrientation: CGSize(width: 342, height: 153), .point4D: CGSize(width: 940, height: 153), .shape: CGSize(width: 311, height: 153), .textDecoration: CGSize(width: 378, height: 153), .size: CGSize(width: 579, height: 153), .layerDimension: CGSize(width: 326, height: 153), .number: CGSize(width: 314, height: 153), .position: CGSize(width: 544, height: 153), .networkRequestType: CGSize(width: 342, height: 153), .textFont: CGSize(width: 430, height: 153), .sizingScenario: CGSize(width: 342, height: 153), .bool: CGSize(width: 271, height: 153), .cameraDirection: CGSize(width: 342, height: 153), .padding: CGSize(width: 1123, height: 153), .media: CGSize(width: 263, height: 153), .animationCurve: CGSize(width: 342, height: 153), .json: CGSize(width: 309, height: 153), .pinToId: CGSize(width: 311, height: 153), .shapeCommand: CGSize(width: 526, height: 153), .pulse: CGSize(width: 271, height: 153), .transform: CGSize(width: 311, height: 153), .fitStyle: CGSize(width: 342, height: 153), .interactionId: CGSize(width: 311, height: 153), .point3D: CGSize(width: 737, height: 153), .anchoring: CGSize(width: 309, height: 153), .color: CGSize(width: 269, height: 153), .layerStroke: CGSize(width: 342, height: 153), .string: CGSize(width: 311, height: 153), .spacing: CGSize(width: 314, height: 153)],
//    .union: [Optional<NodeType>.none: CGSize(width: 232, height: 125)],
//    .curveToPack: [Optional<NodeType>.none: CGSize(width: 471, height: 153)],
//    .imageImport: [Optional<NodeType>.none: CGSize(width: 403, height: 125)],
//    .loopShuffle: [.textDecoration: CGSize(width: 405, height: 125), .cameraDirection: CGSize(width: 369, height: 125), .point4D: CGSize(width: 967, height: 125), .padding: CGSize(width: 1150, height: 125), .sizingScenario: CGSize(width: 369, height: 125), .pulse: CGSize(width: 250, height: 125), .cameraOrientation: CGSize(width: 369, height: 125), .pinToId: CGSize(width: 290, height: 125), .number: CGSize(width: 341, height: 125), .anchoring: CGSize(width: 311, height: 125), .networkRequestType: CGSize(width: 369, height: 125), .textFont: CGSize(width: 457, height: 125), .animationCurve: CGSize(width: 369, height: 125), .spacing: CGSize(width: 341, height: 125), .shapeCommand: CGSize(width: 553, height: 125), .json: CGSize(width: 288, height: 125), .orientation: CGSize(width: 405, height: 125), .string: CGSize(width: 315, height: 125), .color: CGSize(width: 248, height: 125), .interactionId: CGSize(width: 293, height: 125), .shape: CGSize(width: 315, height: 125), .point3D: CGSize(width: 764, height: 125), .position: CGSize(width: 571, height: 125), .media: CGSize(width: 242, height: 125), .layerStroke: CGSize(width: 369, height: 125), .transform: CGSize(width: 315, height: 125), .size: CGSize(width: 606, height: 125), .bool: CGSize(width: 249, height: 125), .fitStyle: CGSize(width: 369, height: 125), .layerDimension: CGSize(width: 353, height: 125)],
//    .length: [.point3D: CGSize(width: 495, height: 97), .color: CGSize(width: 190, height: 97), .number: CGSize(width: 258, height: 97), .size: CGSize(width: 415, height: 97), .string: CGSize(width: 232, height: 97), .position: CGSize(width: 386, height: 97)],
//    .splitText: [Optional<NodeType>.none: CGSize(width: 279, height: 125)],
//    .sizeUnpack: [Optional<NodeType>.none: CGSize(width: 188, height: 125)],
//    .optionEquals: [.layerStroke: CGSize(width: 298, height: 153), .number: CGSize(width: 298, height: 153), .anchoring: CGSize(width: 298, height: 153), .shapeCommand: CGSize(width: 482, height: 153), .orientation: CGSize(width: 334, height: 153), .point4D: CGSize(width: 622, height: 153), .json: CGSize(width: 298, height: 153), .sizingScenario: CGSize(width: 298, height: 153), .cameraDirection: CGSize(width: 298, height: 153), .spacing: CGSize(width: 298, height: 153), .networkRequestType: CGSize(width: 298, height: 153), .media: CGSize(width: 298, height: 153), .pinToId: CGSize(width: 298, height: 153), .bool: CGSize(width: 298, height: 153), .point3D: CGSize(width: 508, height: 153), .pulse: CGSize(width: 298, height: 153), .transform: CGSize(width: 298, height: 153), .size: CGSize(width: 428, height: 153), .layerDimension: CGSize(width: 298, height: 153), .color: CGSize(width: 298, height: 153), .padding: CGSize(width: 714, height: 153), .shape: CGSize(width: 298, height: 153), .position: CGSize(width: 398, height: 153), .textDecoration: CGSize(width: 334, height: 153), .cameraOrientation: CGSize(width: 298, height: 153), .textFont: CGSize(width: 386, height: 153), .animationCurve: CGSize(width: 298, height: 153), .interactionId: CGSize(width: 298, height: 153), .string: CGSize(width: 298, height: 153), .fitStyle: CGSize(width: 298, height: 153)],
//    .imageToBase64String: [Optional<NodeType>.none: CGSize(width: 184, height: 97)],
//    .sizePack: [Optional<NodeType>.none: CGSize(width: 226, height: 125)],
//    .coreMLDetection: [Optional<NodeType>.none: CGSize(width: 589, height: 181)],
//    .sine: [Optional<NodeType>.none: CGSize(width: 305, height: 97)],
//    .reverseProgress: [Optional<NodeType>.none: CGSize(width: 303, height: 153)],
//    .loopInsert: [.bool: CGSize(width: 348, height: 181), .interactionId: CGSize(width: 348, height: 181), .point4D: CGSize(width: 970, height: 181), .shape: CGSize(width: 348, height: 181), .json: CGSize(width: 348, height: 181), .pulse: CGSize(width: 348, height: 181), .textFont: CGSize(width: 464, height: 181), .textDecoration: CGSize(width: 412, height: 181), .transform: CGSize(width: 348, height: 181), .cameraDirection: CGSize(width: 376, height: 181), .position: CGSize(width: 574, height: 181), .media: CGSize(width: 366, height: 181), .size: CGSize(width: 609, height: 181), .spacing: CGSize(width: 348, height: 181), .orientation: CGSize(width: 412, height: 181), .number: CGSize(width: 348, height: 181), .padding: CGSize(width: 1153, height: 181), .sizingScenario: CGSize(width: 376, height: 181), .cameraOrientation: CGSize(width: 376, height: 181), .pinToId: CGSize(width: 348, height: 181), .animationCurve: CGSize(width: 376, height: 181), .networkRequestType: CGSize(width: 376, height: 181), .color: CGSize(width: 348, height: 181), .string: CGSize(width: 348, height: 181), .layerDimension: CGSize(width: 360, height: 181), .anchoring: CGSize(width: 348, height: 181), .fitStyle: CGSize(width: 376, height: 181), .layerStroke: CGSize(width: 376, height: 181), .point3D: CGSize(width: 767, height: 181), .shapeCommand: CGSize(width: 560, height: 181)],
//    .indexOf: [Optional<NodeType>.none: CGSize(width: 314, height: 125)],
//    .jsonArray: [.spacing: CGSize(width: 300, height: 125), .shape: CGSize(width: 274, height: 125), .position: CGSize(width: 428, height: 125), .shapeCommand: CGSize(width: 512, height: 125), .point3D: CGSize(width: 538, height: 125), .media: CGSize(width: 226, height: 125), .number: CGSize(width: 300, height: 125), .animationCurve: CGSize(width: 328, height: 125), .fitStyle: CGSize(width: 328, height: 125), .networkRequestType: CGSize(width: 328, height: 125), .color: CGSize(width: 232, height: 125), .sizingScenario: CGSize(width: 328, height: 125), .size: CGSize(width: 458, height: 125), .bool: CGSize(width: 234, height: 125), .anchoring: CGSize(width: 272, height: 125), .layerDimension: CGSize(width: 312, height: 125), .padding: CGSize(width: 744, height: 125), .orientation: CGSize(width: 364, height: 125), .point4D: CGSize(width: 652, height: 125), .json: CGSize(width: 234, height: 125), .pulse: CGSize(width: 234, height: 125), .layerStroke: CGSize(width: 328, height: 125), .cameraDirection: CGSize(width: 328, height: 125), .interactionId: CGSize(width: 252, height: 125), .transform: CGSize(width: 274, height: 125), .pinToId: CGSize(width: 248, height: 125), .textDecoration: CGSize(width: 364, height: 125), .textFont: CGSize(width: 416, height: 125), .string: CGSize(width: 274, height: 125), .cameraOrientation: CGSize(width: 328, height: 125)],
//    .circleShape: [Optional<NodeType>.none: CGSize(width: 499, height: 125)],
//    .hslColor: [Optional<NodeType>.none: CGSize(width: 293, height: 181)],
//    .transformUnpack: [Optional<NodeType>.none: CGSize(width: 244, height: 321)],
//    .location: [Optional<NodeType>.none: CGSize(width: 373, height: 153)],
//    .positionPack: [Optional<NodeType>.none: CGSize(width: 210, height: 125)],
//    .greaterOrEqual: [Optional<NodeType>.none: CGSize(width: 217, height: 125)],
//    .equals: [Optional<NodeType>.none: CGSize(width: 293, height: 153)],
//    .shapeToCommands: [Optional<NodeType>.none: CGSize(width: 367, height: 97)],
//    .cosine: [Optional<NodeType>.none: CGSize(width: 305, height: 97)],
//    .jsonObject: [.cameraDirection: CGSize(width: 382, height: 125), .pinToId: CGSize(width: 316, height: 125), .shapeCommand: CGSize(width: 566, height: 125), .layerStroke: CGSize(width: 382, height: 125), .color: CGSize(width: 316, height: 125), .pulse: CGSize(width: 316, height: 125), .point3D: CGSize(width: 591, height: 125), .spacing: CGSize(width: 354, height: 125), .shape: CGSize(width: 328, height: 125), .transform: CGSize(width: 328, height: 125), .padding: CGSize(width: 797, height: 125), .number: CGSize(width: 354, height: 125), .textDecoration: CGSize(width: 418, height: 125), .position: CGSize(width: 482, height: 125), .interactionId: CGSize(width: 316, height: 125), .string: CGSize(width: 328, height: 125), .anchoring: CGSize(width: 326, height: 125), .point4D: CGSize(width: 706, height: 125), .fitStyle: CGSize(width: 382, height: 125), .animationCurve: CGSize(width: 382, height: 125), .media: CGSize(width: 316, height: 125), .cameraOrientation: CGSize(width: 382, height: 125), .json: CGSize(width: 316, height: 125), .size: CGSize(width: 511, height: 125), .networkRequestType: CGSize(width: 382, height: 125), .layerDimension: CGSize(width: 366, height: 125), .sizingScenario: CGSize(width: 382, height: 125), .orientation: CGSize(width: 418, height: 125), .bool: CGSize(width: 316, height: 125), .textFont: CGSize(width: 470, height: 125)],
//    .deviceTime: [Optional<NodeType>.none: CGSize(width: 266, height: 125)],
//    .valueAtPath: [.size: CGSize(width: 313, height: 125), .number: CGSize(width: 315, height: 125), .bool: CGSize(width: 275, height: 125), .point3D: CGSize(width: 313, height: 125), .point4D: CGSize(width: 313, height: 125), .layerStroke: CGSize(width: 313, height: 125), .networkRequestType: CGSize(width: 313, height: 125), .color: CGSize(width: 313, height: 125), .string: CGSize(width: 315, height: 125), .cameraDirec<truncated__content/>
