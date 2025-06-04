//
//  StepDerivation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/25.
//

import Foundation


extension StitchDocumentViewModel {

    // TODO: should this be based on `StitchDocument`, so that we can support components with actions etc. ? ... have to update the LLM-actions to include graphId ?
    @MainActor
    static func deriveNewAIActions(oldGraphEntity: GraphEntity?,
                                   visibleGraph: GraphReader) -> [any StepActionable] {
        // Can this truly be optional ?
        guard let oldGraphEntity = oldGraphEntity else {
            log("deriveNewAIActions: No graph state found") // should be fatal error ?
            return []
        }
        
        let newGraphEntity = visibleGraph.createSchema()
        let oldNodeIds = oldGraphEntity.nodes.map(\.id).toSet
        let newNodeIds = newGraphEntity.nodes.map(\.id).toSet
        
        let nodeIdsToCreate = newNodeIds.subtracting(oldNodeIds)
        
        let newNodes: [NodeEntity] = nodeIdsToCreate.compactMap { newNodeId -> NodeEntity? in
            guard let nodeEntity = newGraphEntity.nodes.first(where: { $0.id == newNodeId }) else {
                fatalErrorIfDebug()
                return nil
            }
            return nodeEntity
        }
        
        /*
         TODO: proper handling of arbitrarily nested layer groups
         
         We must always create all the *children* of a layer group, BEFORE we can create the layer group.
         
         Note: this is NOT as simple as applying the `StepActionAddNode` actions before the `StepActionsLayerGroupCreated`s actions, since a layer group's child may be another layer group (nested layer groups).
         
         Suppose a sidebar nested hierarchy like:
         
         Grandpa (group)
         - Oval
         - Papa (group)
         - Rectangle
         
         Then our application/creation order is, from left to right:
         
         `[AddNode("Rectangle"), AddLayerGroup("Papa"), AddNode("Oval"), AddLayerGroup("Grandpa")]`
         
         i.e. create deepest level first, then work up a level ?
         
         FOR NOW, WE ASSUME NON-NESTED LAYER GROUPS, AND SO ALWAYS CREATE NON-LAYER-GROUP LAYERS / PATCHES BEFORE LAYER GROUPS.
         */
        var newNodesSteps: [StepActionAddNode] = []
        var newLayerGroupSteps: [StepActionLayerGroupCreated] = []
        
        var newNodeTypesSteps: [StepActionChangeValueType] = []
        var newConnectionSteps: [StepActionConnectionAdded] = []
        var newSetInputSteps: [StepActionSetInput] = []
        
        
        // MARK: DERIVING THE ACTIONS
        
        for nodeEntity in newNodes {
            guard let nodeName = PatchOrLayer.from(nodeKind: nodeEntity.kind) else {
                fatalErrorIfDebug()
                continue
            }
            
            // If we have a layer group, use the StepActionLayerGroupCreated instead of StepActionAddNode
            if nodeName.asNodeKind.getLayer == .group
            
            // TODO: what is the best way to enforce this "no nested groups" policy for now? Do not create a `StepActionLayerGroupCreated` for a layer group if the layer group already has a parent? But then do we create a regular `StepActionNodeAddNode` too? What about the children? ... Probably better just to solve the problem of nested layer groups.
            // , let sidebarForLayerGroup = self.visibleGraph.layersSidebarViewModel.items.get(nodeEntity.id),
            // !sidebarForLayerGroup.parentId.isDefined
            
            {
                // Find all the sidebar items that have this layer group as their parent;
                // those should be the sidebar items that were originally "selected"
                // (ah, but maybe not *primarily* selected ?)
                // ... should be okay
                
                // Find all the children of the LayerGroup
                let children = visibleGraph.getLayerChildren(for: nodeEntity.id)
                log("deriveNewAIActions: children for layer group \(nodeEntity.id) are: \(children)")
                newLayerGroupSteps.append(StepActionLayerGroupCreated(nodeId: nodeEntity.id,
                                                                      children: children))
            } else {
                do {
                    let migratedNodeName = try nodeName.convert(to: PatchOrLayerAI.self)
                    newNodesSteps.append(StepActionAddNode(nodeId: nodeEntity.id,
                                                           nodeName: migratedNodeName))
                } catch {
                    fatalErrorIfDebug("deriveNewAIActions error: unexpectedly failed get node kind: \(error)")
                }
            }
            
            // Value type change if different from default
            let valueType = nodeEntity.nodeTypeEntity.patchNodeEntity?.userVisibleType
            let defaultValueType = nodeEntity.kind.getPatch?.defaultNodeType
            if valueType != defaultValueType,
               let valueType = valueType {
                do {
                    let migratedValueType = try valueType.convert(to: StitchAINodeType.self)
                    newNodeTypesSteps.append(.init(nodeId: nodeEntity.id,
                                                   valueType: migratedValueType))
                } catch {
                    fatalErrorIfDebug("deriveNewAIActions error: unexpectedly failed get node type: \(error)")
                }
            }
            
            // Create actions for values and connections
            switch nodeEntity.nodeTypeEntity {
                
            case .patch(let patchNode):
                let defaultInputs = patchNode.patch.patchOrLayer.defaultInputs(for: valueType)
                
                for (input, defaultInputValues) in zip(patchNode.inputs, defaultInputs) {
                    Self.deriveNewInputActions(input: input.portData,
                                               port: input.id,
                                               defaultInputs: defaultInputValues,
                                               newConnectionSteps: &newConnectionSteps,
                                               newSetInputSteps: &newSetInputSteps)
                }
                
            case .layer(let layerNode):
                for layerInput in layerNode.layer.layerGraphNode.inputDefinitions {
                    let port = NodeIOCoordinate(portType: .keyPath(.init(layerInput: layerInput,
                                                                         portType: .packed)),
                                                nodeId: nodeEntity.id)
                    let defaultInputValue = layerInput.getDefaultValue(for: layerNode.layer)
                    
                    if let input = layerNode[keyPath: layerInput.schemaPortKeyPath].inputConnections.first {
                        
                        Self.deriveNewInputActions(input: input,
                                                   port: port,
                                                   defaultInputs: [defaultInputValue],
                                                   newConnectionSteps: &newConnectionSteps,
                                                   newSetInputSteps: &newSetInputSteps)
                    }
                }
                
            case .group, .component:
                // We currently do not support the creation of GroupNodes (ui-groupings) or Components via LLM Step Actions
                continue
            }
        }
        
        
        // MARK: SORTING THE DERIVED ACTIONS
        
        // Sorting necessary for validation (just consistent ordering)
        let newNodesStepsSorted = newNodesSteps
            .sorted { $0.nodeId < $1.nodeId }
            // .map { $0.toStep }
        
        let newLayerGroupStepsSorted = newLayerGroupSteps
            .sorted { $0.nodeId < $1.nodeId }
            // .map { $0.toStep }
        
        let newNodeTypesStepsSorted = newNodeTypesSteps
            .sorted { $0.nodeId < $1.nodeId }
            // .map { $0.toStep }
        
        let newConnectionStepsSorted = newConnectionSteps
            .sorted { ($0.toPortCoordinate?.hashValue ?? 0) < ($1.toPortCoordinate?.hashValue ?? 0) }
            // .map { $0.toStep }
        
        let newSetInputStepsSorted = newSetInputSteps
            .sorted { ($0.toPortCoordinate?.hashValue ?? 0) < ($1.toPortCoordinate?.hashValue ?? 0) }
            // .map { $0.toStep }
        
        // TODO: see note above about properly handling nested layer groups
        let creatingNodes: [any StepActionable] = newNodesStepsSorted + newLayerGroupStepsSorted
        let updatingPatchNodesTypes = newNodeTypesStepsSorted
        let creatingConnections = newConnectionStepsSorted
        let settingInputs = newSetInputStepsSorted
        
        
        // This order is important! We want to create nodes first, then change their node types, etc.
        let derivedActions = creatingNodes + updatingPatchNodesTypes + creatingConnections + settingInputs
        log("deriveNewAIActions: derivedActions: \(derivedActions)")
        return derivedActions
    }
    
    private static func deriveNewInputActions(input: NodeConnectionType,
                                              port: NodeIOCoordinate,
                                              defaultInputs: PortValues,
                                              newConnectionSteps: inout [StepActionConnectionAdded],
                                              newSetInputSteps: inout [StepActionSetInput]) {
        do {
            let migratedPortType = try port.portType.convert(to: CurrentStep.NodeIOPortType.self)

            switch input {
            case .upstreamConnection(let upstreamConnection):
                
                let connectionStep: StepActionConnectionAdded = .init(port: migratedPortType,
                                                                      toNodeId: port.nodeId,
                                                                      fromPort: upstreamConnection.portId!,
                                                                      fromNodeId: upstreamConnection.nodeId)
                newConnectionSteps.append(connectionStep)
                
            case .values(let newInputs):
                if defaultInputs != newInputs {
                    let value = newInputs.first!
                    
                    do {
                        let migratedValue = try value.convert(to: CurrentStep.PortValue.self)
                        
                        let setInputStep = StepActionSetInput(nodeId: port.nodeId,
                                                              port: migratedPortType,
                                                              value: migratedValue,
                                                              valueType: migratedValue.nodeType)
                        newSetInputSteps.append(setInputStep)
                        
                    } catch {
                        fatalErrorIfDebug("deriveNewInputActions: unable to convert value: \(value)\nError: \(error)")
                    }
                }
            }
        } catch {
            fatalErrorIfDebug("deriveNewInputActions: unable to convert port type: \(port.portType)\nError: \(error)")
        }
    }
}
