//
//  TabKeyPressActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/30/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import OrderedCollections


// TODO: can likely consolidate a lot of the portId vs layerInput, tab vs shift+tab logic

extension StitchDocumentViewModel {
    @MainActor
    func tabPressed(focusedField: FieldCoordinate,
                    node: NodeViewModel) {
            
        let isCanvas = !focusedField.rowId.graphItemType.isLayerInspector
        let layerInputOnCanvas = isCanvas ? focusedField.rowId.portType.keyPath?.layerInput : nil
        
        let newFocusedField = node.nextInput(focusedField,
                                             layerInput: layerInputOnCanvas,
                                             propertySidebarState: self.visibleGraph.propertySidebar)

        log("tabPressed: newFocusedField: \(newFocusedField)")
        self.reduxFocusedField = .textInput(newFocusedField)
    }
    
    @MainActor
    func shiftTabPressed(focusedField: FieldCoordinate,
                         node: NodeViewModel) {
        
        let isCanvas = !focusedField.rowId.graphItemType.isLayerInspector
        let layerInputOnCanvas = isCanvas ? focusedField.rowId.portType.keyPath?.layerInput : nil
        
        let newFocusedField = node.previousInput(focusedField,
                                                 layerInputOnCanvas: layerInputOnCanvas,
                                                 propertySidebarState: self.visibleGraph.propertySidebar)
        
        log("shiftTabPressed: newFocusedField: \(newFocusedField)")
        self.reduxFocusedField = .textInput(newFocusedField)
    }
}

extension PortValue {
    func inputUsesTextField(layerInputPort: LayerInputPort?,
                            isLayerInputInspector: Bool) -> Bool {
        self.getNodeRowType(nodeIO: .input,
                            layerInputPort: layerInputPort,
                            isLayerInspector: isLayerInputInspector)
        .inputUsesTextField(isLayerInputInspector: isLayerInputInspector)
    }
}

extension Array where Element: InputNodeRowViewModel {
    // Intended for PatchNodes, i.e. inputs that use portId integers
    @MainActor
    func portIdEligibleFields(isLayerInputInspector: Bool) -> PortIdEligibleFields {
        let eligibleFields = self
            .enumerated()
            .flatMap { (item) -> [PortIdEligibleField] in
                
                let input = item.element
                let portId = item.offset
                
                // We are only interested in inputs that use text-fields
                guard input.activeValue.inputUsesTextField(
                    layerInputPort: input.id.layerInputPort,
                    isLayerInputInspector: isLayerInputInspector),
                      let fields = input.fieldValueTypes.first?.fieldObservers else {
                    return []
                }

                return fields.map { (field: InputFieldViewModel) in
                    PortIdEligibleField(portId: portId,
                                        fieldIndex: field.fieldIndex)
                }
            }
        
        return PortIdEligibleFields(eligibleFields)
    }
}

extension NodeRowViewModelId {
    var portType: NodeIOPortType {
        
        switch self.graphItemType {
        
        case .layerInspector(let x):
            return x
        
        case .node(let canvasItemId):
            switch canvasItemId {
            case .layerInput(let x):
                return .keyPath(x.keyPath)
            case .layerOutput(let x):
                return .portIndex(x.portId)
            case .node:
                return .portIndex(self.portId)
            }
        }
    }
}

extension NodeViewModel {
    @MainActor
    func nextInput(_ currentFocusedField: FieldCoordinate,
                   // non-nil = we're tabbing through this layer input on the canvas
                   layerInput: LayerInputPort? = nil,
                   propertySidebarState: PropertySidebarObserver) -> FieldCoordinate {
        
        let currentInputCoordinate: NodeRowViewModelId = currentFocusedField.rowId
        let isLayerInspector = layerInput != nil
                        
        switch currentInputCoordinate.portType {
            
        case .portIndex(let portId):
                        
            let eligibleFields: PortIdEligibleFields = self.allInputRowViewModels.portIdEligibleFields(isLayerInputInspector: isLayerInspector)
            
            guard let currentEligibleField = eligibleFields.first(where: {
                $0 == .init(portId: portId,
                            fieldIndex: currentFocusedField.fieldIndex)
            }),
                  let currentEligibleFieldIndex = eligibleFields.firstIndex(of: currentEligibleField),
                  let lastEligibleField = eligibleFields.last,
                  let firstEligibleField = eligibleFields.first else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate
            }
            
            // If we're already on the last eligible input-field, loop around to the first eligible input-field
            if currentEligibleField == lastEligibleField {
                return FieldCoordinate(
                    rowId: currentInputCoordinate.updatePortId(firstEligibleField.portId),
                    fieldIndex: firstEligibleField.fieldIndex)
            }
            
            // Else, move to next eligible input-field
            else if let nextEligibleField = eligibleFields[safe: currentEligibleFieldIndex + 1] {
                return FieldCoordinate(
                    rowId: currentInputCoordinate.updatePortId(nextEligibleField.portId),
                    fieldIndex: nextEligibleField.fieldIndex)
            }
            
            // Should never happen
            else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
            
        case .keyPath(let currentInputKey):
            
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
            // If we're editing a Position layer input on the canvas,
            // then we should only have two eligible fields.
            let eligibleFields = getTabEligibleFields(
                layerNode: layerNode,
                layerInputOnCanvas: layerInput,
                flyoutInput: propertySidebarState.flyoutState?.flyoutInput,
                collapsedSections: propertySidebarState.collapsedSections)
            
            guard let currentEligibleField = eligibleFields.first(where: {
                $0 == LayerInputEligibleField(input: currentInputKey.layerInput,
                                              fieldIndex: currentFocusedField.fieldIndex)
            }),
                  let currentEligibleFieldIndex = eligibleFields.firstIndex(of: currentEligibleField),
                  let lastEligibleField = eligibleFields.last,
                  let firstEligibleField = eligibleFields.first else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate
            }
            
            // If we're already on the last eligible input-field, loop around to the first eligible input-field
            if currentEligibleField == lastEligibleField {
                return FieldCoordinate(
                    // TODO: support unpacking in tabs
                    rowId: currentInputCoordinate.updateLayerInputKeyPath(.init(layerInput: firstEligibleField.input,
                                                                                portType: .packed)),
                    fieldIndex: firstEligibleField.fieldIndex)
            }
            
            // Else, move to next eligible input-field
            else if let nextEligibleField = eligibleFields[safe: currentEligibleFieldIndex + 1] {
                // TODO: support unpacking in tabs
                return FieldCoordinate(
                    rowId: currentInputCoordinate.updateLayerInputKeyPath(.init(layerInput: nextEligibleField.input,
                                                                                portType: .packed)),
                    fieldIndex: nextEligibleField.fieldIndex)
            } 
            
            // Should never happen
            else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate
            }
                        
        } // switch currentInputCoordindate.portType
    }
}

extension NodeRowViewModelId {
    func updatePortId(_ newPortId: Int) -> Self {
        // Only portId changes; tabbing to next input-field can't change the graph-item-type i.e. can't change the canvas-item-id
        .init(graphItemType: self.graphItemType,
              nodeId: self.nodeId,
              portId: newPortId)
    }
    
    func updateLayerInputKeyPath(_ newLayerInput: LayerInputType) -> Self {
        
        let newGraphItemType: GraphItemType = self.graphItemType.isLayerInspector
        // Can assume .keyPath because we're only updating inputs
        ? .layerInspector(.keyPath(newLayerInput))
        : .node(.layerInput(.init(node: self.nodeId, keyPath: newLayerInput)))
        
        return .init(graphItemType: newGraphItemType,
                     nodeId: self.nodeId,
                     // Technically, irrelevant for LayerInput
                     portId: self.portId)
    }
}

// BETTER: use single structure
struct EligibleField: Equatable, Hashable {
    let input: NodeIOPortType // portId || layerInput
    let fieldIndex: Int
}

struct PortIdEligibleField: Equatable, Hashable {
    let portId: Int // portId || layerInput
    let fieldIndex: Int
}

typealias PortIdEligibleFields = OrderedSet<PortIdEligibleField>

struct LayerInputEligibleField: Equatable, Hashable {
    let input: LayerInputPort // portId || layerInput
    let fieldIndex: Int
}

typealias LayerInputEligibleFields = OrderedSet<LayerInputEligibleField>

@MainActor
func getTabEligibleFields(layerNode: LayerNodeViewModel,
                          layerInputOnCanvas: LayerInputPort?,
                          flyoutInput: LayerInputPort?,
                          collapsedSections: Set<LayerInspectorSection>) -> LayerInputEligibleFields {
    
//    if let flyoutInput = flyoutInput,
//       flyoutInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY {
//        
//    }
    
    // TODO: handle the case of shadow flyout
    // If we are tabbing through fields in an open 'generic flyout' (i.e. a flyout that represents fields on a single input),
    // or through fields on a layer-input-on-the-canvas,
    // our logic is a little simpler:
    if let singleInputToTabThrough = flyoutInput ?? layerInputOnCanvas,
       
        // Shadow Flyout uses multiple inputs
       flyoutInput != SHADOW_FLYOUT_LAYER_INPUT_PROXY {
        
        let fields = layerNode.getLayerInspectorInputFields(singleInputToTabThrough).map({ field in
            LayerInputEligibleField(input: singleInputToTabThrough, fieldIndex: field.fieldIndex)
        })
        return LayerInputEligibleFields(fields)
    }
    
    // If we are in the shadow flyout,
    // then we only tab through shadow inputs and input-fields
    if flyoutInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY {
        let eligibleShadowFields = LayerInspectorSection.shadow.flatMap { (shadowInput: LayerInputPort) -> [LayerInputEligibleField] in
            
            guard shadowInput.usesTextFields(layerNode.layer) else {
                return []
            }
            
            if shadowInput == .shadowOffset {
                return layerNode.getLayerInspectorInputFields(shadowInput).map({ field in
                    LayerInputEligibleField(input: shadowInput, fieldIndex: field.fieldIndex)
                })
            } else {
                return [LayerInputEligibleField(input: shadowInput, fieldIndex: 0)]
            }
        }
        
        return LayerInputEligibleFields(eligibleShadowFields)
    }
    
    
    let layer = layerNode.layer
    let inputsForThisLayer = layer.layerGraphNode.inputDefinitions
  
    let eligibleFields = LayerInspectorSection
    // Master, ordered list (ordered set)
        .allCases
    
    // Remove inputs from sections that are (1) collapsed or (2) use a flyout
        .filter {
//            $0.name != .shadow
//            && 
            !collapsedSections.contains($0)
        }
        .flatMap { section in
            section.displaysOnTabbing(layer: layer) ? section.sectionData : []
        }
    
    // We're only interested in layer inputs that (1) are for this layer, (2) use textfield and (3) do not use a flyout
        .filter { layerInput in
            inputsForThisLayer.contains(layerInput)
            && layerInput.usesTextFields(layer)
             && !layerInput.usesFlyout
        }
    
    // Turn each non-blocked field on a layeri input into a LayerInputEligibleField
        .reduce(into: LayerInputEligibleFields(), { partialResult, layerInput in
            (layerNode.getLayerInspectorInputFields(layerInput)).forEach { field in
                let blockedFields = layerNode.getLayerInputObserver(layerInput).blockedFields
                
                if !field.isBlocked(blockedFields) {
                    partialResult.append(.init(input: layerInput,
                                               fieldIndex: field.fieldIndex))
                }
            }
        })

    return eligibleFields
}

extension NodeViewModel {
    @MainActor
    func previousInput(_ currentFocusedField: FieldCoordinate,
                       // non-nil = we're tabbing through this layer input on the canvas
                       layerInputOnCanvas: LayerInputPort? = nil,
                       propertySidebarState: PropertySidebarObserver) -> FieldCoordinate {
        
        let currentInputCoordinate = currentFocusedField.rowId
        let isLayerInputInspector = layerInputOnCanvas != nil
        
        switch currentInputCoordinate.portType {
        
        case .portIndex(let portId):
            let eligibleFields: PortIdEligibleFields = self.allNodeInputRowViewModels.portIdEligibleFields(isLayerInputInspector: isLayerInputInspector)
              
            guard let currentEligibleField = eligibleFields.first(where: {
                // eligible fields are equatable
                $0 == .init(portId: portId,
                            fieldIndex: currentFocusedField.fieldIndex)
            }),
                  let currentEligibleFieldIndex = eligibleFields.firstIndex(of: currentEligibleField),
                  let lastEligibleField = eligibleFields.last,
                  let firstEligibleField = eligibleFields.first else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate
            }
            
            // If we're already on the first input, loop back to the last eligible input-field
            if currentEligibleField == firstEligibleField {
                return FieldCoordinate(
                    rowId: currentInputCoordinate.updatePortId(lastEligibleField.portId),
                    fieldIndex: lastEligibleField.fieldIndex)
            }
                        
            // Else, move to previous eligible input-field
            else if let previousEligibleField = eligibleFields[safe: currentEligibleFieldIndex - 1] {
                return FieldCoordinate(
                    rowId: currentInputCoordinate.updatePortId(previousEligibleField.portId),
                    fieldIndex: previousEligibleField.fieldIndex)
            }
            
            // Should never happen
            else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate
            }
            
        case .keyPath(let currentInputKey):
            //
            guard let layerNode = self.layerNode else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }

            let eligibleFields = getTabEligibleFields(
                layerNode: layerNode,
                layerInputOnCanvas: layerInputOnCanvas,
                flyoutInput: propertySidebarState.flyoutState?.flyoutInput,
                collapsedSections: propertySidebarState.collapsedSections)
            
            guard let currentEligibleField = eligibleFields.first(where: {
                // eligible fields are equatable
                // TODO: support prev input tabbing for unpacked
                $0 == LayerInputEligibleField(input: currentInputKey.layerInput,
                                              fieldIndex: currentFocusedField.fieldIndex)
            }),
                  let currentEligibleFieldIndex = eligibleFields.firstIndex(of: currentEligibleField),
                  let lastEligibleField = eligibleFields.last,
                  let firstEligibleField = eligibleFields.first else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate
            }
            
            // If we're already on the first input, loop back to the last eligible input-field
            if currentEligibleField == firstEligibleField {
                // TODO: support prev input tabbing for unpacked
                return FieldCoordinate(
                    rowId: currentInputCoordinate.updateLayerInputKeyPath(.init(layerInput: lastEligibleField.input,
                                                                                portType: .packed)),
                    fieldIndex: lastEligibleField.fieldIndex)
            }
            
            // Else, move to previous eligible input-field
            else if let previousEligibleField = eligibleFields[safe: currentEligibleFieldIndex - 1] {
                return FieldCoordinate(
                    // TODO: support prev input tabbing for unpacked
                    rowId: currentInputCoordinate.updateLayerInputKeyPath(.init(layerInput: previousEligibleField.input,
                                                                                portType: .packed)),
                    fieldIndex: previousEligibleField.fieldIndex)
            } 
            
            // Should not happen
            else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate
            }
            
        } // switch currentInput.id.portType
    }
    
    @MainActor
    var maxInputIndex: Int {
        self.getAllInputsObservers().count - 1
    }
}

extension NodeRowViewModel {
    @MainActor
    var maxFieldIndex: Int {
        // I would expect an input to have [field];
        // but this is [[field]] ?
        // is that because at one point we thought an input could have multiple rows?
        // Yeah, seems so.
        (self.fieldValueTypes.first?.fieldObservers.count ?? 1) - 1
    }
}
