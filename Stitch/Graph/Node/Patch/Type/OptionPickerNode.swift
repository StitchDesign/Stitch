//
//  OptionPickerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func optionPickerPatchNode(id: NodeId,
                           n: Double? = 0,
                           n2: Double? = 1,
                           nodePosition: CGSize = .zero,
                           nodeZIndex: Double = 0) -> PatchNode {

    // default
    var opt1: PortValue = colorDefaultFalse
    var opt2: PortValue = colorDefaultTrue
    var userVisibleType: UserVisibleType = .color

    if let x = n,
       let x2 = n2 {
        opt1 = .number(x)
        opt2 = .number(x2)
        userVisibleType = .number
    }

    let inputs = toInputs(
        id: id,
        values:
            ("Option", [numberDefaultFalse]),
        //        (nil, [colorDefaultFalse]),
        //        (nil, [colorDefaultTrue]))
        (nil, [opt1]),
        (nil, [opt2]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [opt1]))

    return PatchNode(
        position: nodePosition,
        zIndex: nodeZIndex,
        id: id,
        patchName: .optionPicker,
        //        userVisibleType: .color,
        userVisibleType: userVisibleType,
        inputs: inputs,
        outputs: outputs)
}

func optionPickerEval(inputs: PortValuesList,
                      outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        guard let defaultFakeValue = values.first?.defaultFalseValue else {
            fatalErrorIfDebug()
            return colorDefaultFalse
        }
        
        let selection: Int = Int(values.first?.getNumber ?? 0.0)

        // + 1 because want to skip the first item in values
        if selection < 0 {
            return values[safe: 1] ?? defaultFakeValue
        } else if selection + 1 >= values.count {
            return values.last ?? defaultFakeValue
        } else {
            return values[safe: selection + 1] ?? defaultFakeValue
        }
    }

    return resultsMaker(inputs)(op)
}
