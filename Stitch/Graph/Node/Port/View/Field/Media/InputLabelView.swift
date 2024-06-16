//
//  InputViewLabel.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import SwiftUI

struct InputLabelView: View {

    let id: InputCoordinate
    let input: Input
    let portDotColor: Color
    let adjustedIndex: Int

    let hasEdge: Bool
    let hasLoopEdge: Bool
    let isWirelessReceiverNode: Bool

    var body: some View {

        // if we have a wireless receiver node,
        // use an wireless input icon
        if isWirelessReceiverNode {
            WirelessPortView(isOutput: false,
                             id: id.nodeId)
        } else {
            PortDot(coordinate: .input(id),
                    portDotColor: portDotColor,
                    isInput: true,
                    hasEdge: hasEdge,
                    hasLoopEdge: hasLoopEdge)
        }

        PortLabelView(label: input.label ?? "",
                      id: id.nodeId)

        InputValueTypeView(
            id: id,
            valueType: input.values[adjustedIndex].valueType)

        IdView(id: input.id,
               nodeId: id.nodeId)

    }
}

// struct InputViewLabel_Previews: PreviewProvider {
//    static var previews: some View {
//        InputViewLabel()
//    }
// }
