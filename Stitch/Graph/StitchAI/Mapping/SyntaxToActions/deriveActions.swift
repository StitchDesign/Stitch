//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation


extension SyntaxView {
    
    func deriveStitchActions() -> VPLLayerConceptOrderedSet {
        
        var actions = VPLLayerConceptOrderedSet()

        // 1. Every ViewNode → one SACreateLayer (with children).
        if let createdLayer = self.deriveCreateLayerAction() {
            actions.append(.layer(createdLayer))
            
            // 2. For each initializer argument in ViewNode.arguments:
            // 3. For each modifier in ViewNode.modifiers:
            actions.append(contentsOf: self.deriveSetInputAndIncomingEdgeActions(
                createdLayer.name,
                id: createdLayer.id))
            
            // 4. Recurse into children (emit their actions in order).
            for child in self.children {
                let childActions = child.deriveStitchActions()
                actions.append(contentsOf: childActions)
            }
        } else {
            // if we can't create the layer, then we can't (or shouldn't) process its constructor-args, modifiers and children
            log("deriveStitchActions: Could not create layer for view node. Name: \(self.name), viewNode: \(self)")
        }
        
        return actions
    }
    
    // derived from name and construct arguments
    func deriveCreateLayerAction() -> VPLLayer? {
        if let layer: Layer = self.deriveLayer() {
            return VPLLayer(
                id: self.id,
                name: layer,
                children: self.children.compactMap { $0.deriveCreateLayerAction() } )
        }
        return nil
    }
        
    // dervied from modifiers and constructor arguments
    func deriveSetInputAndIncomingEdgeActions(_ layer: Layer, id: UUID) -> [VPLLayerConcept] {
        
        var actions = [VPLLayerConcept]()
        
        // iterate through constructor arguments
        for arg in self.constructorArguments {
            
            guard let port: LayerInputPort = arg.deriveLayerInputPort(layer) else {
                log("deriveSetInputAndIncomingEdgeActions: could not handle constructor argument label: \(arg.label)")
                // fatalErrorIfDebug()
                continue
            }
            
            // TODO: alternatively, rely on the layer input port's default port-value and user-input-edit logic?
            guard let portValue = arg.derivePortValue(layer) else {
                log("deriveSetInputAndIncomingEdgeActions: could not handle constructor argument value: \(arg.value)")
                // fatalErrorIfDebug()
                continue
            }
            
            switch arg.syntaxKind {
            
            case .literal:
                actions.append(
                    .layerInputSet(VPLLayerInputSet(
                        id: id,
                        input: port,
                        value: portValue
                    ))
                )
                
            case .expression, .variable:
                actions.append(
                    .incomingEdge(VPLIncomingEdge(name: port))
                )
            } // switch
            
        } // for arg in ...

        // iterate through modifiers
        for modifier in self.modifiers {
            
            guard let port = modifier.name.deriveLayerInputPort(layer) else {
                log("could not create layer input for modifier \(modifier)")
                continue
            }
            
            
            // Start with a default port value of the correct kind for this layer input
            var portValue = port.getDefaultValue(for: layer)
            
            // Iterate through the modifier's arguments,
            // parsing each arg's `value` as if it were a user-edit;
            // workings equally well
            for (index, arg) in modifier.arguments.enumerated() {
                portValue = portValue.parseInputEdit(
                    fieldValue: .string(.init(arg.value)),
                    fieldIndex: index)
            }
            
            actions.append(.layerInputSet(
                VPLLayerInputSet(id: id,
                                 input: port,
                                 value: portValue)
            ))
            
            
            // TODO: handle incoming edges
            // TODO: handle unpacked layer inputs where some fields receive edges, others manually-set values
            //            for arg in modifier.arguments {
            //                switch arg.syntaxKind {
            //                case .variable, .expression:
            //                    actions.append(.incomingEdge(VPLIncomingEdge(name: port)))
            //                default:
            //                    continue
            //                }
            //            }
            
            
        } // for modifier in ...
        
        return actions
    }
}
