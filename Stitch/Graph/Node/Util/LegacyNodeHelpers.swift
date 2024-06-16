//
//  Nodes.swift
//  prototype
//
//  Created by cjc on 1/14/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 Node building helpers
 ---------------------------------------------------------------- */

typealias LabeledValue = (String?, [PortValue])

let DISABLED_PORT_LABEL = "" // "disabled"

// usually defaults to first value?
func toInput(nodeId: NodeId,
             portId: Int,
             value: LabeledValue,
             activeIndex: Int = 0) -> Input {

    Input(coordinate: InputCoordinate(portId: portId, nodeId: nodeId),
          label: value.0,
          values: value.1)
}

// better?: toInputs
func toInputs(id: NodeId,
              values: LabeledValue...) -> Inputs {
    NEA(zip(values.indices, values).map { index, value in
        toInput(nodeId: id,
                portId: index,
                // just do the conversion here,
                // rather than for every single li
                value: value)
    })!
}

// Better?: don't use a `PortValue.none` type,
// instead use whatever value you want,
// but don't display the inputs at all
func fakeInputs(id: NodeId) -> Inputs {
    NEA(toInput(nodeId: id,
                portId: 0,
                value: (DISABLED_PORT_LABEL, [PortValue.number(0)])))
}

extension NodeInputDefinition {
    static let fakeInput = Self.init(label: DISABLED_PORT_LABEL, staticType: .number)
}

func fakeOutputs(id: NodeId, offset: Int) -> Outputs {
    NEA(toOutput(nodeId: id,
                 portId: offset + 1,
                 value: (DISABLED_PORT_LABEL, [PortValue.number(0)])))
}

func toOutput(nodeId: NodeId,
              portId: Int,
              value: LabeledValue) -> Output {

    Output(coordinate: OutputCoordinate(portId: portId, nodeId: nodeId),
           label: value.0,
           values: value.1)
}

// BAD: CONNECTIONS MAY BE FOR DIFFERENT / VARIOUS NODES
// `offset`: the node's `inputs.count` (needed to ensure unique port numbers)

// After the April 2023 perf-refactor,
// output and input port id numbers do NOT affect each other
// TODO: remove the `offset` param from `toOutputs`; use XCode find-and-replace ?
func toOutputs(id: NodeId,
               offset: Int,
               values: LabeledValue...) -> Outputs {

    NEA(zip(values.indices, values).map { index, value in
        toOutput(nodeId: id,
                 portId: index, // + offset,
                 value: value)
    })!
}
