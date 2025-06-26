//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI


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
            
        } // for arg in self.constructorArguments

        // iterate through modifiers
        for modifier in self.modifiers {
            
            guard let port = modifier.name.deriveLayerInputPort(layer) else {
                log("could not create layer input for modifier \(modifier)")
                continue
            }
            
            
            // Start with a default port value of the correct kind for this layer input
            var portValue = port.getDefaultValue(for: layer)
            
            log("deriveSetInputAndIncomingEdgeActions: portValue: \(portValue)")
            
            // Iterate through the modifier's arguments,
            // parsing each arg's `value` as if it were a user-edit;
            // workings equally well
            
            // single field = use `set value in
            if modifier.arguments.count  == 1,
               let arg = modifier.arguments.first {
                
                // picker-option-selected doesn't really do any string-parsing ? it always just takes the actual port value ?
                // portValue.alwaysUsesDropDownMenu
                
                // ah, but there can be single parameter values that don't take
                
                // can you use the coercer directly then ?
                
                // i.e. you know the input's default type; now pretend that the syntax value-string is string port-value flying into a layer input, and which needs to be turned into the input's default type
                
                // this turns e.g. Color.yellow into a string like "Color.yellow", which is not what you want
                var argValue = arg.value
                log("deriveSetInputAndIncomingEdgeActions: one modifier arg: arg.value: \(arg.value)")
                if let colorArgValue = Color.fromSystemName(argValue) {
                    log("deriveSetInputAndIncomingEdgeActions: one modifier arg: colorArgValue: \(colorArgValue)")
                    argValue = colorArgValue.asHexDisplay
                }
                let syntaxValueStringAsPortValueString = PortValue.string(.init(argValue))
                
                let newValues: PortValues = [syntaxValueStringAsPortValueString].coerce(
                    to: portValue,
                    currentGraphTime: .zero // what to do for graph time here?
                )
                
                log("deriveSetInputAndIncomingEdgeActions: one modifier arg: newValues: \(newValues)")
                
                if let newValue = newValues.first {
                    log("deriveSetInputAndIncomingEdgeActions: one modifier arg: newValue: \(newValue)")
                    portValue = newValue
                }
                
                
            } else {
                for (index, arg) in modifier.arguments.enumerated() {
                    log("deriveSetInputAndIncomingEdgeActions: many modifier args: index: \(index), arg: \(arg)")
                    let newValue = portValue.parseInputEdit(
                        fieldValue: .string(.init(arg.value)),
                        fieldIndex: index)
                    log("deriveSetInputAndIncomingEdgeActions: many modifier args: newValue: \(newValue)")
                    portValue = newValue
                }
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
            
            
        } // for modifier in self.modifiers
        
        return actions
    }
}


// https://developer.apple.com/documentation/swiftui/color#Getting-standard-colors
extension Color {
    /// Converts a textual system-color name (“yellow”, “.yellow”, “Color.yellow”)
    /// into a `SwiftUI.Color`. Returns `nil` for unknown names.
    static func fromSystemName(_ raw: String) -> Color? {
        // ── 1. Normalise ────────────────────────────────────────────────────────
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasPrefix("Color.") { key.removeFirst("Color.".count) }
        if key.hasPrefix(".")      { key.removeFirst() }

        // ── 2. Lookup ───────────────────────────────────────────────────────────
        switch key.lowercased() {
        case "black":   return .black
        case "blue":    return .blue
        case "brown":   return .brown
        case "clear":   return .clear
        case "cyan":    return .cyan
        case "gray",    // US spelling
             "grey":    // convenience UK spelling
                        return .gray
        case "green":   return .green
        case "indigo":  return .indigo
        case "mint":    return .mint
        case "orange":  return .orange
        case "pink":    return .pink
        case "purple":  return .purple
        case "red":     return .red
        case "teal":    return .teal
        case "white":   return .white
        case "yellow":  return .yellow
        default:        return nil        // not a standard color
        }
    }
}
