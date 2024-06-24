//
//  OutputLabelView.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import SwiftUI
import DisplayLink

struct OutputLabelView: View {
    let id: OutputCoordinate
    let valueAtIndex: PortValue
    let patchName: Patch?
    let output: Output
    let portDotColor: Color

    let hasEdge: Bool
    let hasLoopEdge: Bool

    var body: some View {
        ValueTypeView(valueType: valueAtIndex.valueType,
                      id: id.nodeId)

        PortLabelView(label: output.label ?? "",
                      id: id.nodeId)

        // ALSO: need to NOT show certain fields if it's a broadcaster?

        // if we have a wireless broadcaster node,
        // use an wireless input icon
        if let patch = patchName,
           patch == .wirelessBroadcaster {
            WirelessPortView(isOutput: true,
                             id: id.nodeId)

        } else {
            PortDot(coordinate: .output(id),
                    portDotColor: portDotColor,
                    isInput: false,
                    hasEdge: hasEdge,
                    hasLoopEdge: hasLoopEdge)

        }
    }
}

// struct OutputLabelView_Previews: PreviewProvider {
//    static var previews: some View {
//        OutputLabelView()
//    }
// }
