//
//  PatchNodeTypeExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let emptySet: Set<UserVisibleType> = Set()

let allNodeTypesSet: Set<UserVisibleType> = UserVisibleType
    .allCases
    .filter(\.isSelectableAsNodeType)
    .toSet

extension UserVisibleType {

    var isSelectableAsNodeType: Bool {
        switch self {
        case .none, .int, .shapeCommandType, .scrollMode, .scrollJumpStyle, .scrollDecelerationRate, .textVerticalAlignment, .textAlignment, .textTransform, .shapeCoordinates:
            return false
        default:
            return true
        }
    }
}

extension NodeViewModel {
    /// Certain patch nodes can have varying input counts (i.e. "add" node).
    @MainActor
    var canInputCountsChange: Bool {
        self.kind.getPatch?.inputCountChanged.isDefined ?? false
    }
    
    @MainActor
    var canAddInputs: Bool {
        self.kind.getPatch?.inputCountChanged.isDefined ?? false
    }
    
    @MainActor
    var canRemoveInputs: Bool {
        if let patch = self.kind.getPatch,
        let minimumInputs = patch.minimumInputs {
            return patch.inputCountChanged.isDefined && (self.inputsRowCount > minimumInputs)
        }
        
        // Always false for LayerNodes and GroupNodes
        return false
    }
}

extension Patch {
    
    // nil when patch node cannot add/remove inputs
    var minimumInputs: Int? {
        switch self {
        case .loopBuilder, .jsonArray:
            return 1

        // minimum 2 inputs
        case .add, .multiply, .divide,
             .or, .and, .union, .arrayJoin, .subtract:
            return 2

        // minimum 3 inputs (including Option slot)
        case .optionPicker,
             .optionSwitch,
             .optionEquals:
            return 3

        default:
            // ie noop
            return nil
        }
    }
    
    @MainActor
    var inputCountChanged: InputsChangedHandler? {
        guard let minimumInputCount = self.minimumInputs else {
            return nil
        }
        
        return minimumInputsChangedHandler(minimumInputs: minimumInputCount)
    }

    var availableNodeTypes: Set<UserVisibleType> {
        switch self {
        // ALL
        case .splitter, .loopSelect, .loopInsert, .setValueForKey, .jsonObject, .jsonArray, .wirelessBroadcaster, .optionPicker, .optionEquals, .pulseOnChange, .loopBuilder, .optionSender, .loopFilter, .loopToArray, .loopReverse, .sampleAndHold, .delay, .loopDedupe, .valueAtPath, .valueAtIndex, .valueForKey:
            return AllUVT.value

        // NUMBER

        // max can also have eg position and point3D type
        // TODO: update these nodes' evals to handle more than just PortValue.number
        // https://github.com/vpl-codesign/stitch/issues/3241
        //        case .max, .min, .mod:
        //            return NumberUVT.value

        // ARITHMETIC
        case .add, .length:
            // LATER: color
            return ArithmeticUVT.value

        // Updated to exclude text/string types
        case .subtract, .multiply, .divide, .power, .squareRoot:
            return MathUVT.value

        // ANIMATION
        // TODO: add .size, .anchor etc.?
        case .classicAnimation, .transition:
            return AnimationNodeType.choices

        // TODO: ?: add .color, and update .springAnimation
        case .popAnimation, .springAnimation:
            return .init([.number, .position])

        // PACK
        case .pack, .unpack:
            return PackUVT.value

//        case .wirelessReceiver: // wirelessRec type determined by value from broadcaster
//            return EmptyUVT.value

        case .networkRequest:
            return Set([.media, .string, .json])

        default:
            return EmptyUVT.value
        }
    }

}

// Every input
// (node, added?, minimum?) -> node
typealias InputsChangedHandler = (NodeViewModel, Bool) -> ()

@MainActor
func minimumInputsChangedHandler(minimumInputs: Int) -> InputsChangedHandler {
    { (node: NodeViewModel, added: Bool) in
        if added {
            node.inputAdded()
        } else {
            node.inputRemoved(minimumInputs: minimumInputs)
        }
    }
}
