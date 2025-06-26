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
            
            guard let port = arg.toLayerInput(layer) else {
                log("deriveSetInputAndIncomingEdgeActions: could not handle constructor argument label: \(arg.label)")
                // fatalErrorIfDebug()
                continue
            }
            
            switch arg.syntaxKind {
            
            case .literal:
                actions.append(
                    .layerInputSet(VPLLayerInputSet(id: id,
                                                    input: port,
                                                    value: arg.value))
                )
                
            case .expression, .variable:
                actions.append(
                    .incomingEdge(VPLIncomingEdge(name: port))
                )
            } // switch
            
        } // for arg in ...

        // iterate through modifiers
        for modifier in self.modifiers {
            
            guard let port = modifier.kind.toLayerInput(layer) else {
                log("could not create layer input for modifier \(modifier)")
                continue
            }
            
            // JUNE 24: PROPERLY HANDLE WHEN INPUT HAS ONE FIELD WITH A LITERAL AND ANOTHER FIELD WITH AN INCOMING EDGE
            let allLiteral = modifier.arguments.allSatisfy {
                if case .literal = $0.syntaxKind { return true }
                return false
            }
            if allLiteral {
                // Emit ONE SASetLayerInput: kind = modifier.kind, value = joined literal list
                // Format: "label1: value1, value2"
                let parts: [String] = modifier.arguments.map {
                    let label = $0.label
                    if !label.rawValue.isEmpty {
                        return "\(label): \($0.value)"
                    } else {
                        return $0.value
                    }
                }
                
                let joined = parts.joined(separator: ", ")
                actions.append(.layerInputSet(VPLLayerInputSet(id: id,
                                                               input: port,
                                                               value: joined)))
            } else {
                // Emit ONE action per argument
                for arg in modifier.arguments {
                    switch arg.syntaxKind {
                    case .literal:
                        actions.append(.layerInputSet(VPLLayerInputSet(
                            id: id,
                            input: port,
                            value: arg.value)))
                        
                    case .variable, .expression:
                        actions.append(.incomingEdge(VPLIncomingEdge(name: port)))
                    }
                }
            }
            
        } // for modifier in ...
        
        return actions
    }
}
