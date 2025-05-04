////
////  OldTabKeyPressActions.swift
////  Stitch
////
////  Created by Christian J Clampitt on 7/31/24.
////
//
//import Foundation
//import SwiftUI
//import StitchSchemaKit
//import OrderedCollections
//
////extension GraphState {
////    @MainActor
////    func tabPressed(_ focusedInput: FieldCoordinate) {
////        if let newFocusedInput = nextFieldOrInput(state: self,
////                                                  focusedField: focusedInput) {
////            // log("tabPressed: newFocusedInput: \(newFocusedInput)")
////            self.reduxFocusedField = .textInput(newFocusedInput)
////        }
////    }
////    
////    @MainActor
////    func shiftTabPressed(_ focusedInput: FieldCoordinate) {
////        if let newFocusedInput = previousFieldOrInput(state: self,
////                                                      focusedField: focusedInput) {
////            // log("shiftTabPressed: newFocusedInput: \(newFocusedInput)")
////            self.reduxFocusedField = .textInput(newFocusedInput)
////        }
////    }
////}
//
//// nil = no field focused
//// 0 =
//
//// differs with FieldCoordinate's `input` vs `rowId`, but that shouldn't matter
////@MainActor
////func _nextFieldOrInput(state: GraphState,
////                      focusedField: FieldCoordinate) -> FieldCoordinate? {
////
////    let currentInputCoordinate = focusedField.input
////    let nodeId = currentInputCoordinate.nodeId
////    
////    // Retrieve the node view model,
////    guard let node = state.getNode(nodeId),
////          // actually, want to look at the activeValue?
////          // but that won't matter
////            let input = node.getInputRowObserver(for: currentInputCoordinate.portType) else {
////        log("nextFieldOrInput: Could not find node or input for field \(focusedField)")
////        return nil
////    }
////
////    let maxFieldIndex = input.maxFieldIndex
////    let nextFieldIndex = focusedField.fieldIndex + 1
////    
////    // If we're not yet past max field index, return the incremented field index.
////    if nextFieldIndex <= maxFieldIndex {
////        return FieldCoordinate(input: currentInputCoordinate,
////                               fieldIndex: nextFieldIndex)
////    }
////    
////    // Else, move to next input (or first input, if already on last input).
////    else {
////        return node.nextInput(focusedField.input)
////    }
////}
//
////struct _TabEligibleInput: Equatable, Hashable {
////    // Input's original index in the last of node's inputs
////    let originalIndex: Int
////}
//
////// seems close enough / fine
////extension NodeRowObservers {
////    func _tabEligibleInputs() -> OrderedSet<TabEligibleInput> {
////        self.enumerated()
////            .reduce(into: OrderedSet<TabEligibleInput>()) { acc, item in
////                if item.element
////                    .allLoopedValues
////                    .first?.getNodeRowType(nodeIO: .input)
////                    .inputUsesTextField ?? false {
////                    
////                    acc.append(.init(originalIndex: item.offset))
////                }
////            }
////    }
////}
//
//extension NodeViewModel {
//    
//    @MainActor
//    func _nextInput(_ currentInputCoordinate: InputCoordinate) -> FieldCoordinate {
//        
//        let nodeId = self.id
//        
//        switch currentInputCoordinate.portType {
//        
//        case .portIndex(let portId): // current port id
//                                    
//            // Input Indices, for only those ports on a patch node which are eligible for Tab or Shift+Tab.
//            // so e.g. a patch node with inputs like `[color, string, bool, position3D]`
//            // would have tab-eligible-input indices like `[1, 3]`
//            let allInputs = self.inputRowObservers()
//            let eligibleInputs: OrderedSet<TabEligibleInput> = allInputs.tabEligibleInputs()
//            
//            guard let currentEligibleInput = eligibleInputs.first(where: { $0.originalIndex == portId }),
//                  let firstEligibleInput = eligibleInputs.first,
//                  let lastEligibleInput = eligibleInputs.last else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//            
//            // If we're already on last input, then move to first input.
//            if currentEligibleInput == lastEligibleInput {
//                return FieldCoordinate(input: .init(portType: .portIndex(firstEligibleInput.originalIndex),
//                                                    nodeId: nodeId),
//                                       fieldIndex: 0)
//            }
//            
//            // Else, move to next input. In the list of eligible inputs, go to the next eligible input right after our current eligible input.
////            else if let nextEligibleInput = eligibleInputs.drop(while: { $0 != currentEligibleInput }).dropFirst().first {
//            
//            else if let nextEligibleInput = eligibleInputs.after(currentEligibleInput) {
//                return FieldCoordinate(input: .init(portType: .portIndex(nextEligibleInput.originalIndex),
//                                                    nodeId: nodeId),
//                                       fieldIndex: 0)
//            }
//            
//            else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//            
//        case .keyPath(let currentInputKey):
//            
//            guard let layer = self.kind.getLayer else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//            
//            let layerInputs = layer.textInputsForThisLayer
//                        
//            guard let currentInputKeyIndex = layerInputs.firstIndex(where: { $0 == currentInputKey }),
//                  let firstInput = layerInputs.first,
//                  let lastInput = layerInputs.last else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//            
//            // If we're already on last input, then move to first input.
//            if currentInputKey == lastInput {
//                return FieldCoordinate(input: .init(portType: .keyPath(firstInput),
//                                                    nodeId: nodeId),
//                                       fieldIndex: 0)
//            }
//            // Else, move to next input:
//            else if let nextInputKey = layerInputs[safe: currentInputKeyIndex + 1] {
//                return FieldCoordinate(input: .init(portType: .keyPath(nextInputKey),
//                                                    nodeId: nodeId),
//                                       fieldIndex: 0)
//            } else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//            
//        } // switch
//    }
//}
//
//extension Layer {
//    var _textInputsForThisLayer: [LayerInputType] {
//        
//        let layer = self
//        
//        // text-field-using inputs for this layer
//        let thisLayersTextUsingInputs = layer.layerGraphNode.inputDefinitions.filter({
//            $0.getDefaultValue(for: layer).getNodeRowType(nodeIO: .input).inputUsesTextField
//        })
//        
//        // filtering the property sidebar's master list down to only those inputs that are both (1) for this layer and (2) actually use tex-field
//        let layerInputs = LayerInspectorView.allInputs.filter { masterListInput in
//            thisLayersTextUsingInputs.contains(masterListInput)
//        }
//        
//        return layerInputs
//    }
//}
//
//@MainActor
//func _previousFieldOrInput(state: GraphState,
//                          focusedField: FieldCoordinate) -> FieldCoordinate? {
//    
//    let currentFieldIndex = focusedField.fieldIndex
//    let currentInputCoordinate = focusedField.input
//    let nodeId = currentInputCoordinate.nodeId
//    
//    guard let node = state.getNode(nodeId),
//          // actually, want to look at the activeValue?
//          // but that won't matter
//            let input = node.getInputRowObserver(for: currentInputCoordinate.portType) else {
//        log("nextFieldOrInput: Could not find node or input for field \(focusedField)")
//        return nil
//    }
//
//    // I would expect an input to have [field];
//    // but this is [[field]] ?
//    // is that because at one point we thought an input could have multiple rows?
//    // Yeah, seems so.
////    let fieldsList: FieldGroupTypeDataList = input.fieldValueTypes
////    let minimumFieldIndex = 0
//    
//    let previousFieldIndex = currentFieldIndex - 1
//    
//    // If we're not yet at the very first field, return the decremented field index.
//    if previousFieldIndex >= 0 {
//        return FieldCoordinate(input: currentInputCoordinate,
//                               fieldIndex: previousFieldIndex)
//    }
//    
//    // Else: attempt to go to a previous input.
//    else {
//        return node.previousInput(input)
//    }
//}
//
//extension NodeViewModel {
//    @MainActor
//    func _previousInput(_ currentInput: NodeRowObserver) -> FieldCoordinate {
//        let nodeId = self.id
//        let currentInputCoordinate: InputCoordinate = currentInput.id
//        
//        switch currentInputCoordinate.portType {
//        
//        case .portIndex(let portId):
//            
//            // Input Indices, for only those ports on a patch node which are eligible for Tab or Shift+Tab.
//            // so e.g. a patch node with inputs like `[color, string, bool, position3D]`
//            // would have tab-eligible-input indices like `[1, 3]`
//            let allInputs = self.inputRowObservers()
//            let eligibleInputs: OrderedSet<TabEligibleInput> = allInputs.tabEligibleInputs()
//            
//            guard let currentEligibleInput = eligibleInputs.first(where: { $0.originalIndex == portId }),
//                  let firstEligibleInput = eligibleInputs.first,
//                  let lastEligibleInput = eligibleInputs.last else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//            
//            // If we're already on the first eligible input, then "loop back" to the last field of the last eligible input.
//            if currentEligibleInput == firstEligibleInput,
//               let maxFieldIndex = allInputs[safe: lastEligibleInput.originalIndex]?.maxFieldIndex {
//                return FieldCoordinate(
//                    input: .init(portType: .portIndex(lastEligibleInput.originalIndex),
//                                 nodeId: nodeId),
//                    fieldIndex: maxFieldIndex)
//            }
//            
//            // Else, move to previous eligible input. In the list of eligible inputs, go to the previous eligible input right after our current eligible input.
//            else if let previousEligibleInput = eligibleInputs.before(currentEligibleInput),
//                    let maxFieldIndex = allInputs[safe: previousEligibleInput.originalIndex]?.maxFieldIndex{
//                
//                return FieldCoordinate(input: .init(portType: .portIndex(previousEligibleInput.originalIndex),
//                                                    nodeId: nodeId),
//                                       fieldIndex: maxFieldIndex)
//            }
//            
//            else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//            
//            
//            
//        case .keyPath(let currentInputKey):
//            
//            guard let layer = self.kind.getLayer else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//
//            let layerInputs = layer.textInputsForThisLayer
//            
//            guard let currentInputKeyIndex = layerInputs.firstIndex(where: { $0 == currentInputKey }),
//                  let firstInput = layerInputs.first,
//                  let lastInput = layerInputs.last else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//                        
//            // If we're already on first input, then "loop back" to the last field of the last input.
//            if currentInputKey == firstInput {
//                return FieldCoordinate(input: .init(portType: .keyPath(lastInput),
//                                                    nodeId: nodeId),
//                                       fieldIndex: lastInput.maxFieldIndex(layer))
//            }
//            
//            // Else, move to last field of the previous input:
//            else if let previousInputKey = layerInputs[safe: currentInputKeyIndex - 1] {
//                return FieldCoordinate(input: .init(portType: .keyPath(previousInputKey),
//                                                    nodeId: nodeId),
//                                       fieldIndex: previousInputKey.maxFieldIndex(layer))
//            } else {
//                fatalErrorIfDebug()
//                return .fakeFieldCoordinate // should never happen
//            }
//            
//        } // switch
//    }
//    
////    @MainActor
////    var maxInputIndex: Int {
////        self.inputRowObservers().count - 1
////    }
//}
//
////extension LayerInputType {
////    func maxFieldIndex(_ layer: Layer) -> Int {
////        let fieldCount = self.getDefaultValue(for: layer)
////            .createFieldValues(nodeIO: .input,
////                               importedMediaObject: nil)
////            .first?.count ?? 1
////        
////        return fieldCount - 1
////    }
////}
////
////extension NodeRowObserver {
////    var maxFieldIndex: Int {
////        // I would expect an input to have [field];
////        // but this is [[field]] ?
////        // is that because at one point we thought an input could have multiple rows?
////        // Yeah, seems so.
////        (self.fieldValueTypes.first?.fieldObservers.count ?? 1) - 1
////    }
////}
