//
//  NodeTypeChangedHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/29/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine

extension NodeKind {
    @MainActor
    func rowIsTypeStatic(nodeType: UserVisibleType?,
                         portId: Int) -> Bool {
        // Note: whether a row is type-static or not does not depend on node type,
        // but node type determines how many rows there are.
        self.rowDefinitions(for: nodeType)
            .inputs[safe: portId]?
            .isTypeStatic ?? false
    }
}

extension InputNodeRowObserver {

    // used only for type coercion
    @MainActor
    func changeInputType(to newType: UserVisibleType,
                         nodeKind: NodeKind,
                         currentGraphTime: TimeInterval,
                         computedState: ComputedNodeState?,
                         activeIndex: ActiveIndex,
                         isVisible: Bool) {

        if let portId = self.id.portId,
           nodeKind.rowIsTypeStatic(nodeType: newType, portId: portId) {
            // log("NodeRowObserver: coerceInput: had static node row, so nothing to do")
            return
        }

        var preservedComputedValues: PortValues?
        let values = self.allLoopedValues

        if let _preservedComputedValue = computedState?.preservedValues.get(newType) {
            preservedComputedValues = [_preservedComputedValue]
        }

        // Attempt to retrieve previous value for this node type
        let valuesToUse: PortValues = preservedComputedValues ?? values

        // Preserve current value.
        // (If port has loop, don't preserve value.)
        if values.count == 1 {
            let value: PortValue = values.first!
            let oldUserType: UserVisibleType = portValueToNodeType(value)

            computedState?.preservedValues.updateValue(
                value,
                // Save not for the newType,
                // but rather the old.
                forKey: oldUserType)
        }

        // If we had preserved values for this node type,
        // do we really need to coerce again?
        // They're already same type.
        
        let valuesCoercedToNewType = valuesToUse.coerce(to: newType.defaultPortValue,
                                                        currentGraphTime: currentGraphTime)
        
        self.updateValuesInInput(valuesCoercedToNewType,
                                 // already coerced
                                 shouldCoerceToExistingInputType: false)
    }
}

extension ComputedNodeState {
    func resetClassicAnimationStates(newType: UserVisibleType) {
        self.classicAnimationState = self.classicAnimationState?.reset(by: newType)
    }
}

extension ClassicAnimationState {
    func reset(by nodeType: UserVisibleType) -> Self {
        ClassicAnimationState.defaultFromNodeType(.fromNodeType(nodeType))
    }
}
