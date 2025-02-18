//
//  SchemaNodesUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/3/24.
//

import Foundation
import StitchSchemaKit

extension [NodePortInputEntity] {
    @MainActor
    func createInputObservers(nodeId: NodeId,
                              kind: NodeKind,
                              userVisibleType: UserVisibleType?) -> [InputNodeRowObserver] {
        
        // Note: can be called for GroupNode as well?
        guard let patch = kind.getPatch else {
            fatalErrorIfDebug("createInputObservers is not intended only for layer node inputs")
            return .init()
        }
        
        let defaultInputs: NodeInputDefinitions = kind.rowDefinitions(for: userVisibleType).inputs

        // Determine count of inputs based on persisted data in case extra rows created
        // Note: look at input count from schema; important for e.g. removing inputs where e.g. LoopBuilder has had inputs removed and so has fewer inputs than the 5 declared in its node row definition
        let inputsCount = self.count

        return (0..<inputsCount).compactMap { portId -> InputNodeRowObserver? in
            
            // If we don't have a NodePortInputEntity, we can't create an observer.
            guard let schemaData: NodePortInputEntity = self[safe: portId] else {
                log("createInputObservers: no schemaData for \(portId) for node \(nodeId)")
                return nil
            }

            let values = schemaData.getInitialValuesForPatchNodeInput(
                patch: patch,
                schemaValues: schemaData.portData.values,
                defaultInputs: defaultInputs)
            
            guard let values: PortValues = values else {
                log("createInputObservers: could not create observer for \(portId) for node \(nodeId)")
                // MARK: from Elliot--seems to work ok if this gets hit
                return nil
            }

            return InputNodeRowObserver(values: values,
                                        id: .init(portId: portId, nodeId: nodeId),
                                        upstreamOutputCoordinate: schemaData.portData.upstreamConnection)
        }
    }
}

typealias NodeInputDefinitions = [NodeInputDefinition]

func getDefaultValueForPatchNodeInput(_ portId: Int,
                                      _ defaultInputs: NodeInputDefinitions,
                                      patch: Patch) -> PortValues? {
    
    let isMathExpressionNode = patch == .mathExpression
    let defaultValues: PortValues? = defaultInputs[safe: portId]?.defaultValues
    let lastDefaultInputValues: PortValues? = defaultInputs.last?.defaultValues
    
    // Math-Expression nodes are a special case where we cannot rely on default-inputs (which can be
    // This fix helps to resolve https://github.com/vpl-codesign/stitch/issues/5503
    let defaultMathExpressionInputValues: PortValues? = isMathExpressionNode ? [.number(.zero)] : nil
            
    let values = defaultValues
        // Assume then that this input is for an added-input,
        // which can be assumed to be the same port-value-type
        // as last default input.
        ?? lastDefaultInputValues
        ?? defaultMathExpressionInputValues
    
    return values
}

// ONLY FOR PATCH NODE INPUTS
extension NodePortInputEntity {
    
    func getInitialValuesForPatchNodeInput(patch: Patch,
                                           schemaValues: PortValues?,
                                           defaultInputs: NodeInputDefinitions) -> PortValues? {
        
        guard let portId: Int = self.id.portId else {
            // e.g. we had a layer node input, which needs to be handled differently
            fatalErrorIfDebug("getInitialValuesForPatchNodeInput: was this called for a layer node input?")
            return nil
        }
       
        let defaultValue: PortValues? = getDefaultValueForPatchNodeInput(
            portId,
            defaultInputs, 
            patch: patch)
        
        let values = schemaValues ?? defaultValue
            
        guard let values: PortValues = values else {
            log("getInitialValuesForPatchNodeInput: could not get initial values for input \(self.id)")
            // MARK: from Elliot--seems to work ok if this gets hit
//                fatalErrorIfDebug()
            return nil
        }
        
        return values
    }
}

extension NodeRowDefinitions {
    // Used when initializing patch's outputs upon Graph Open. We start with `allLoopedValues = []` just as we do in Graph Reset.
    @MainActor
    func createEmptyOutputObservers(nodeId: NodeId) -> [OutputNodeRowObserver] {
        self.outputs.enumerated().map { portId, _ in
            OutputNodeRowObserver(values: [],
                                  id: .init(portId: portId, nodeId: nodeId),
                                  upstreamOutputCoordinate: nil)
        }
    }

    // Used when initializing layer's outputs upon Graph Open. We start with `allLoopedValues = []` just as we do in Graph Reset.
    @MainActor
    func createEmptyOutputLayerPorts(schema: LayerNodeEntity,
                                     // Pass in values directly from eval
                                     valuesList: PortValuesList) -> [OutputLayerNodeRowData] {
        let nodeId = schema.id
        
        assertInDebug(self.outputs.count == schema.outputCanvasPorts.count)
        
        return zip(valuesList.enumerated(), schema.outputCanvasPorts).map { outputData, canvasEntity in
            var canvasObserver: CanvasItemViewModel?
            let portId = outputData.0
//            let values = outputData.1
            
            let observer = OutputNodeRowObserver(values: [], //values,
                                                 id: .init(portId: portId, nodeId: nodeId))

            if let canvasEntity = canvasEntity {
                canvasObserver = CanvasItemViewModel(
                    from: canvasEntity,
                    id: .layerOutput(.init(node: nodeId,
                                                  portId: portId)),
                    inputRowObservers: [],
                    outputRowObservers: [observer],
                    // Irrelevant for output
                    unpackedPortParentFieldGroupType: nil,
                    unpackedPortIndex: nil)
            }
            
            let outputData = OutputLayerNodeRowData(rowObserver: observer,
                                                    canvasObserver: canvasObserver)
            
            outputData.inspectorRowViewModel.canvasItemDelegate = outputData.canvasObserver
            
            return outputData
        }
    }
}
