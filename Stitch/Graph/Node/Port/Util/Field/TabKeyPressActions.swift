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

extension GraphState {
    @MainActor
    func tabPressed(_ focusedInput: FieldCoordinate) {
        if let newFocusedInput = nextFieldOrInput(state: self,
                                                  focusedField: focusedInput) {
            // log("tabPressed: newFocusedInput: \(newFocusedInput)")
            self.graphUI.reduxFocusedField = .textInput(newFocusedInput)
        }
    }
    
    @MainActor
    func shiftTabPressed(_ focusedInput: FieldCoordinate) {
        if let newFocusedInput = previousFieldOrInput(state: self,
                                                      focusedField: focusedInput) {
            // log("shiftTabPressed: newFocusedInput: \(newFocusedInput)")
            self.graphUI.reduxFocusedField = .textInput(newFocusedInput)
        }
    }
}

// nil = no field focused
// 0 =
@MainActor
func nextFieldOrInput(state: GraphDelegate,
                      focusedField: FieldCoordinate) -> FieldCoordinate? {

    let currentInputCoordinate = focusedField.rowId
    let canvasId = focusedField.canvasId
    
    // Retrieve the node view model,
    guard let canvas = state.getCanvasItem(canvasId),
          let node = canvas.nodeDelegate,
          // actually, want to look at the activeValue?
          // but that won't matter
            let input = node.getInputRowObserver(for: currentInputCoordinate)?.rowViewModel else {
        log("nextFieldOrInput: Could not find node or input for field \(focusedField)")
        return nil
    }

    let maxFieldIndex = input.maxFieldIndex
    let nextFieldIndex = focusedField.fieldIndex + 1
    
    // If we're not yet past max field index, return the incremented field index.
    if nextFieldIndex <= maxFieldIndex {
        return FieldCoordinate(rowId: currentInputCoordinate,
                               canvasId: canvasId,
                               fieldIndex: nextFieldIndex)
    }
    
    // Else, move to next input (or first input, if already on last input).
    else {
        return canvas.nextInput(focusedField.rowId)
    }
}

struct TabEligibleInput: Equatable, Hashable {
    // Input's original index in the last of node's inputs
    let originalIndex: Int
}

extension Array where Element: InputNodeRowViewModel {
    func tabEligibleInputs() -> OrderedSet<TabEligibleInput> {
        self.enumerated()
            .reduce(into: OrderedSet<TabEligibleInput>()) { acc, item in
                if item.element.activeValue.getNodeRowType(nodeIO: .input).inputUsesTextField {
                    acc.append(.init(originalIndex: item.offset))
                }
            }
    }
}

extension CanvasItemViewModel {
    @MainActor
    func nextInput(_ currentInputCoordinate: NodeIOPortType) -> FieldCoordinate {
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return .fakeFieldCoordinate
        }
        
        let allInputs = node.allInputRowViewModels
        
        switch currentInputCoordinate {
        
        case .portIndex(let portId): // current port id
                                    
            // Input Indices, for only those ports on a patch node which are eligible for Tab or Shift+Tab.
            // so e.g. a patch node with inputs like `[color, string, bool, position3D]`
            // would have tab-eligible-input indices like `[1, 3]`
            let eligibleInputs: OrderedSet<TabEligibleInput> = allInputs.tabEligibleInputs()
            
            guard let currentEligibleInput = eligibleInputs.first(where: { $0.originalIndex == portId }),
                  let firstEligibleInput = eligibleInputs.first,
                  let lastEligibleInput = eligibleInputs.last else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
            // If we're already on last input, then move to first input.
            if currentEligibleInput == lastEligibleInput {
                return FieldCoordinate(rowId: .portIndex(firstEligibleInput.originalIndex),
                                       canvasId: self.id,
                                       fieldIndex: 0)
            }
            
            // Else, move to next input. In the list of eligible inputs, go to the next eligible input right after our current eligible input.
//            else if let nextEligibleInput = eligibleInputs.drop(while: { $0 != currentEligibleInput }).dropFirst().first {
            
            else if let nextEligibleInput = eligibleInputs.after(currentEligibleInput) {
                return FieldCoordinate(rowId: .portIndex(nextEligibleInput.originalIndex),
                                       canvasId: self.id,
                                       fieldIndex: 0)
            }
            
            else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
        case .keyPath(let currentInputKey):
            
            guard let layer = node.kind.getLayer else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
            let layerInputs = layer.textInputsForThisLayer
                        
            guard let currentInputKeyIndex = layerInputs.firstIndex(where: { $0 == currentInputKey }),
                  let firstInput = layerInputs.first,
                  let lastInput = layerInputs.last else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
            // If we're already on last input, then move to first input.
            if currentInputKey == lastInput {
                return FieldCoordinate(rowId: .keyPath(firstInput),
                                       canvasId: self.id,
                                       fieldIndex: 0)
            }
            // Else, move to next input:
            else if let nextInputKey = layerInputs[safe: currentInputKeyIndex + 1] {
                return FieldCoordinate(rowId: .keyPath(nextInputKey),
                                       canvasId: self.id,
                                       fieldIndex: 0)
            } else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
        } // switch
    }
}

extension Layer {
    @MainActor var textInputsForThisLayer: [LayerInputType] {
        
        let layer = self
        
        // text-field-using inputs for this layer
        let thisLayersTextUsingInputs = layer.layerGraphNode.inputDefinitions.filter({
            $0.getDefaultValue(for: layer).getNodeRowType(nodeIO: .input).inputUsesTextField
        })
        
        // filtering the property sidebar's master list down to only those inputs that are both (1) for this layer and (2) actually use tex-field
        let layerInputs = LayerInspectorView.allInputs.filter { masterListInput in
            thisLayersTextUsingInputs.contains(masterListInput)
        }
        
        return layerInputs
    }
}

@MainActor
func previousFieldOrInput(state: GraphDelegate,
                          focusedField: FieldCoordinate) -> FieldCoordinate? {
    
    let currentFieldIndex = focusedField.fieldIndex
    let currentInputCoordinate = focusedField.rowId
    
    guard let canvas = state.getCanvasItem(focusedField.canvasId),
          let node = canvas.nodeDelegate,
          // actually, want to look at the activeValue?
          // but that won't matter
            let input = node.getInputRowObserver(for: currentInputCoordinate)?.rowViewModel else {
        log("nextFieldOrInput: Could not find node or input for field \(focusedField)")
        return nil
    }

    // I would expect an input to have [field];
    // but this is [[field]] ?
    // is that because at one point we thought an input could have multiple rows?
    // Yeah, seems so.
//    let fieldsList: FieldGroupTypeViewModelList = input.fieldValueTypes
//    let minimumFieldIndex = 0
    
    let previousFieldIndex = currentFieldIndex - 1
    
    // If we're not yet at the very first field, return the decremented field index.
    if previousFieldIndex >= 0 {
        return FieldCoordinate(rowId: currentInputCoordinate,
                               canvasId: canvas.id,
                               fieldIndex: previousFieldIndex)
    }
    
    // Else: attempt to go to a previous input.
    else {
        return canvas.previousInput(input)
    }
}

extension CanvasItemViewModel {
    @MainActor
    func previousInput(_ currentInput: InputNodeRowViewModel) -> FieldCoordinate {
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return .fakeFieldCoordinate
        }
        
        let nodeId = self.id
        let currentInputCoordinate = currentInput.id
        
        switch currentInputCoordinate {
        
        case .portIndex(let portId):
            
            // Input Indices, for only those ports on a patch node which are eligible for Tab or Shift+Tab.
            // so e.g. a patch node with inputs like `[color, string, bool, position3D]`
            // would have tab-eligible-input indices like `[1, 3]`
            let allInputs = node.allInputRowViewModels
            let eligibleInputs: OrderedSet<TabEligibleInput> = allInputs.tabEligibleInputs()
            
            guard let currentEligibleInput = eligibleInputs.first(where: { $0.originalIndex == portId }),
                  let firstEligibleInput = eligibleInputs.first,
                  let lastEligibleInput = eligibleInputs.last else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
            // If we're already on the first eligible input, then "loop back" to the last field of the last eligible input.
            if currentEligibleInput == firstEligibleInput,
               let maxFieldIndex = allInputs[safe: lastEligibleInput.originalIndex]?.maxFieldIndex {
                return FieldCoordinate(
                    rowId: .portIndex(lastEligibleInput.originalIndex),
                    canvasId: self.id,
                    fieldIndex: maxFieldIndex)
            }
            
            // Else, move to previous eligible input. In the list of eligible inputs, go to the previous eligible input right after our current eligible input.
            else if let previousEligibleInput = eligibleInputs.before(currentEligibleInput),
                    let maxFieldIndex = allInputs[safe: previousEligibleInput.originalIndex]?.maxFieldIndex{
                
                return FieldCoordinate(rowId: .portIndex(previousEligibleInput.originalIndex),
                                       canvasId: self.id,
                                       fieldIndex: maxFieldIndex)
            }
            
            else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
            
            
        case .keyPath(let currentInputKey):
            
            guard let layer = node.kind.getLayer else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }

            let layerInputs = layer.textInputsForThisLayer
            
            guard let currentInputKeyIndex = layerInputs.firstIndex(where: { $0 == currentInputKey }),
                  let firstInput = layerInputs.first,
                  let lastInput = layerInputs.last else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
                        
            // If we're already on first input, then "loop back" to the last field of the last input.
            if currentInputKey == firstInput {
                return FieldCoordinate(rowId: .keyPath(lastInput),
                                       canvasId: self.id,
                                       fieldIndex: lastInput.maxFieldIndex(layer))
            }
            
            // Else, move to last field of the previous input:
            else if let previousInputKey = layerInputs[safe: currentInputKeyIndex - 1] {
                return FieldCoordinate(rowId: .keyPath(previousInputKey),
                                       canvasId: self.id,
                                       fieldIndex: previousInputKey.maxFieldIndex(layer))
            } else {
                fatalErrorIfDebug()
                return .fakeFieldCoordinate // should never happen
            }
            
        } // switch
    }
    
    @MainActor
    var maxInputIndex: Int {
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return 0
        }
        
        return node.getAllInputsObservers().count - 1
    }
}

extension LayerInputType {
    func maxFieldIndex(_ layer: Layer) -> Int {
        let fieldCount = self.getDefaultValue(for: layer)
            .createFieldValues(nodeIO: .input,
                               importedMediaObject: nil)
            .first?.count ?? 1
        
        return fieldCount - 1
    }
}

extension NodeRowViewModel {
    var maxFieldIndex: Int {
        // I would expect an input to have [field];
        // but this is [[field]] ?
        // is that because at one point we thought an input could have multiple rows?
        // Yeah, seems so.
        (self.fieldValueTypes.first?.fieldObservers.count ?? 1) - 1
    }
}
