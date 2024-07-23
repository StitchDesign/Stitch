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
                              userVisibleType: UserVisibleType?,
                              nodeDelegate: NodeDelegate?) -> [InputNodeRowObserver] {
        
        // Note: can be called for GroupNode as well?
        guard !kind.isLayer else {
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
                schemaValues: schemaData.portData.values,
                defaultInputs: defaultInputs)
            
            guard let values: PortValues = values else {
                log("createInputObservers: could not create observer for \(portId) for node \(nodeId)")
                // MARK: from Elliot--seems to work ok if this gets hit
                return nil
            }

            return InputNodeRowObserver(values: values,
                                        nodeKind: kind,
                                        userVisibleType: userVisibleType,
                                        id: .init(portId: portId, nodeId: nodeId),
                                        activeIndex: .init(.zero),
                                        upstreamOutputCoordinate: schemaData.portData.upstreamConnection,
                                        nodeDelegate: nodeDelegate)
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
    
    func getInitialValuesForPatchNodeInput(schemaValues: PortValues?,
                                           defaultInputs: NodeInputDefinitions) -> PortValues? {
        
        guard !self.nodeKind.getLayer.isDefined,
                let portId: Int = self.id.portId,
                let patch = self.nodeKind.getPatch else {
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
    @MainActor
    func createOutputObservers(nodeId: NodeId,
                               // Pass in values directly from eval
                               values: PortValuesList,
                               patch: Patch,
                               userVisibleType: UserVisibleType?,
                               nodeDelegate: NodeDelegate?) -> [OutputNodeRowObserver] {
        self.outputs.enumerated().map { portId, _ in
            OutputNodeRowObserver(values: values[safe: portId] ?? [],
                                  nodeKind: .patch(patch),
                                  userVisibleType: userVisibleType,
                                  id: .init(portId: portId, nodeId: nodeId),
                                  activeIndex: .init(.zero),
                                  upstreamOutputCoordinate: nil,
                                  nodeDelegate: nodeDelegate)
        }
    }

    @MainActor
    func createOutputLayerPorts(schema: LayerNodeEntity,
                               // Pass in values directly from eval
                               valuesList: PortValuesList,
                               userVisibleType: UserVisibleType?,
                               nodeDelegate: NodeDelegate?) -> [OutputLayerNodeRowData] {
        let nodeId = schema.id
        let kind = NodeKind.layer(schema.layer)
        
        assertInDebug(self.outputs.count == schema.outputCanvasPorts.count)
        
        return zip(valuesList.enumerated(), schema.outputCanvasPorts).map { outputData, canvasEntity in
            var canvasObserver: CanvasItemViewModel?
            let portId = outputData.0
            let values = outputData.1
            
            let observer = OutputNodeRowObserver(values: values,
                                                 nodeKind: kind,
                                                 userVisibleType: userVisibleType,
                                                 id: .init(portId: portId, nodeId: nodeId),
                                                 activeIndex: .init(.zero),
                                                 nodeDelegate: nodeDelegate)

            if let canvasEntity = canvasEntity {
                canvasObserver = CanvasItemViewModel(
                    from: canvasEntity,
                    id: .layerOutput(.init(node: nodeId,
                                                  portId: portId)),
                    inputRowObservers: [],
                    outputRowObservers: [observer],
                    node: nodeDelegate)
            }
            
            return OutputLayerNodeRowData(rowObserver: observer,
                                          canvasObserver: canvasObserver)
        }
    }
}
