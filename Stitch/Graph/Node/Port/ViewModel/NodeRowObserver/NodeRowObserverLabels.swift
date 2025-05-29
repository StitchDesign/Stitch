//
//  NodeRowObserverLabels.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/25/25.
//

import Foundation


@MainActor
func getLabelForRowObserver(useShortLabel: Bool = false,
                            node: NodeViewModel,
                            coordinate: Coordinate,
                            graph: GraphState) -> String {
    /*
     Two scenarios re: a Group Node and its splitters:
     
     1. We are looking at the Group Node itself; so we want to use its underlying group node input- and output-splitters' titles as labels for the group node's rows
     
     2. We are INSIDE THE GROUP NODE, looking at its input- and output-splitters at that traversal level; so we do not use the splitters' titles as labels
     */
    switch node.nodeType {
        
    case .patch(let patchNodeViewModel):
        return getLabelForRowObserver(node: .patch(node: node, patch: patchNodeViewModel),
                                      useShortLabel: useShortLabel,
                                      coordinate: coordinate)
        
    case .layer(let layerNodeViewModel):
        return getLabelForRowObserver(node: .layer(node: node, layer: layerNodeViewModel),
                                      useShortLabel: useShortLabel,
                                      coordinate: coordinate)
        
    // TODO: is this accuurate for components ?
    case .group, .component:
        // Cached values which get underlying splitter node's title
        guard let labelFromSplitter = graph.cachedGroupPortLabels.get(coordinate) else {
            return "" // can fail when initially loading the graph
        }
        
        // Don't show label on group node's input/output row unless it is custom
        if labelFromSplitter == Patch.splitter.defaultDisplayTitle() {
            return ""
        }
        
        return labelFromSplitter
    }
}

@MainActor
func getLabelForRowObserver(node: PatchOrLayerNode,
                            useShortLabel: Bool,
                            coordinate: Coordinate) -> String {
        
    switch coordinate {
    
    // Patch and Layer both use ints for outputs
    case .output(let outputCoordinate):
        switch outputCoordinate.portType {
        case .portIndex(let portId):
            return getLabelForOutput(portId: portId,
                                     node: node)
        case .keyPath:
            fatalErrorIfDebug("keyPath is never used for outputs")
            return ""
        }
    
    // Patch uses int, Layer uses keypath, for inputs
    case .input(let inputCoordinate):
        switch inputCoordinate.portType {
        case .portIndex(let portId):
            guard let patchNode = node.patchNode else {
                fatalErrorIfDebug("Had portIndex with input but did not have a patch node")
                return ""
            }
            return getLabelForPatchInput(portId: portId,
                                         patch: patchNode)
        case .keyPath(let keyPath):
            return getLabelForLayerInput(layerInputType: keyPath,
                                         useShortLabel: useShortLabel)
        }
    }
}

@MainActor
func getLabelForOutput(portId: Int,
                       node: PatchOrLayerNode) -> String {
    let outputs = node.patchOrLayer
        .rowDefinitionsOldOrNewStyle(for: node.patchNode?.userVisibleType)
        .outputs
    
    return outputs[safe: portId]?.label ?? ""
}

func getLabelForLayerInput(layerInputType: LayerInputType,
                           useShortLabel: Bool) -> String {
    layerInputType.layerInput.label(useShortLabel: useShortLabel)
}

@MainActor
func getLabelForPatchInput(portId: Int,
                           patch: PatchNodeViewModel) -> String {
    
    if let mathExpr = patch.mathExpression?.getSoulverVariables(),
       let variableChar = mathExpr[safe: portId] {
        return String(variableChar)
    }
    
    let rowDefinitions = patch.patchOrLayer.rowDefinitionsOldOrNewStyle(for: patch.userVisibleType)
    return rowDefinitions.inputs[safe: portId]?.label ?? ""
}

@MainActor
func getLabelForPatchOutput(portId: Int,
                            patch: PatchNodeViewModel) -> String {
    
    let rowDefinitions = patch.patchOrLayer.rowDefinitionsOldOrNewStyle(for: patch.userVisibleType)
    return rowDefinitions.outputs[safe: portId]?.label ?? ""
}
