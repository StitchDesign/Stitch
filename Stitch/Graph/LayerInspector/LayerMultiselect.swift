//
//  LayerMultiselect.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/26/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension String {
    static let HETEROGENOUS_VALUES = "Multi"
}

extension InputFieldViewModel {
    var isFieldInsideLayerInspector: Bool {
        self.rowViewModelDelegate?.id.graphItemType.isLayerInspector ?? false
    }
    
    // Is this input-field for a layer input, and if so, which one?
    var layerInput: LayerInputPort? {
        self.rowViewModelDelegate?.id.portType.keyPath?.layerInput
    }
}

/*
 Suppose:
 
 Left sidebar:
 - Oval P (selected)
 - Rectangle Q (selected)
 
 And:
 * P and Q's scale input = 1
 * P and Q's size input = { width: 100, height: 100 }
 * P's position input = { x: 0, y: 0 }
 * Q's position input = { x: 50, y: 0 }
 
 The inspector's inputs/fields will display:
 * scale = 1
 * size = { 100, 100 }
 * position = { "Multi", 0 }
 */
typealias LayerMultiselectInputDict = [LayerInputPort: LayerMultiselectInput]

@Observable
final class LayerMultiSelectObserver {
    // TODO: Don't need the dictionary now? Just set of "inputs common to all currently-selected layers" and have GraphState methods for retrieving `observers`, `hasHeterogenousValue` etc.
    // inputs that are common across all the selected layers
    var inputs: LayerMultiselectInputDict
    
    init(inputs: LayerMultiselectInputDict) {
        self.inputs = inputs
    }
    
    // Note: this loses information about the heterogenous values etc.
    @MainActor
    func asLayerInputObserverDict(_ graph: GraphState) -> LayerInputObserverDict {
        self.inputs.reduce(into: LayerInputObserverDict()) { partialResult, layerInput in
            if let firstObserver = layerInput.value.multiselectObservers(graph).first {
                partialResult.updateValue(firstObserver,
                                          forKey: layerInput.key)
            }
        }
    }
}

// A representation of a layer node's ports, separate from the layer node itself
typealias LayerInputObserverDict = [LayerInputPort: LayerInputObserver]

extension LayerNodeViewModel {
    
    @MainActor
    func filteredLayerInputObserverDict(supportedInputs: LayerInputTypeSet) -> LayerInputObserverDict {
        
        LayerInputPort.allCases.reduce(into: LayerInputObserverDict()) { partialResult, layerInput in
            if supportedInputs.contains(layerInput) {
                partialResult.updateValue(self[keyPath: layerInput.layerNodeKeyPath],
                                          forKey: layerInput)
            }
        }
    }
}

extension GraphState {
}

// `input` but actually could be input OR output
@Observable
final class LayerMultiselectInput {
    let input: LayerInputPort // will need to be Input OR Output
    
    @MainActor
    func multiselectObservers(_ graph: GraphState) -> [LayerInputObserver] {
                
        let selectedLayers = graph.sidebarSelectionState.inspectorFocusedLayers
        
        let observers: [LayerInputObserver] = selectedLayers.compactMap {
                if let layerNode = graph.getNode($0.id)?.layerNode {
                    let observer: LayerInputObserver = layerNode[keyPath: input.layerNodeKeyPath]
                    return observer
                }
                return nil
            }
        
        return observers
    }

    @MainActor
    func fieldsInMultiselectInputWithHeterogenousValues(_ graph: GraphState) -> Set<Int> {
        
        // field index -> values in that field
        var fieldIndexToFieldValues = [Int: [FieldValue]]()
        var acc = Set<Int>()
        
        // build a dictionary of `fieldCoordinate -> [value]` and if the list of `value`s in the end are all the same, then that field coordinate is NOT heterogenous
        self.multiselectObservers(graph).forEach { (observer: LayerInputObserver) in
            observer
                ._packedData // TODO: do not assume packed
                .inspectorRowViewModel // Only interested in inspector view models
                .fieldValueTypes.first? // .first = ignore the shape command case
            
            // "Does every multi-selected layer have the same value at this input-field?"
            // (Note: NOT "Does every field in this input have same value?")
                .fieldObservers.forEach({ (field: InputFieldViewModel) in
                    var existing = fieldIndexToFieldValues.get(field.fieldIndex) ?? []
                    existing.append(field.fieldValue)
                    fieldIndexToFieldValues.updateValue(existing, forKey: field.fieldIndex)
                })
        }
        
        fieldIndexToFieldValues.forEach { (key: Int, values: [FieldValue]) in
            if let someValue = values.first,
               !values.allSatisfy({ $0 == someValue }) {
                acc.insert(key)
            }
        }
        
        return acc
    }
        
    init(input: LayerInputPort) {
        self.input = input
    }
}

