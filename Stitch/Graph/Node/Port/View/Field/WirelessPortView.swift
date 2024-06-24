//
//  WirelessPortView.swift
//  prototype
//
//  Created by Christian J Clampitt on 11/22/21.
//

import SwiftUI
import StitchSchemaKit

struct WirelessPortView: View {

    let isOutput: Bool
    let id: NodeId

    var body: some View {
        Image(systemName: "wifi")
            .foregroundColor(STITCH_TITLE_FONT_COLOR)
            .rotation3DEffect(.degrees(isOutput ? 90 : 270),
                              axis: (x: 0, y: 0, z: 1))
            .frame(PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE)
            //            .offset(x: isOutput ? -4 : 4)
            .offset(x: isOutput ? -12 : 12)
        #if targetEnvironment(macCatalyst)
        .scaleEffect(1.2)
        #else
        .scaleEffect(0.85)
        #endif
    }
}

struct WirelessPortView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 50) {
            WirelessPortView(isOutput: true, id: fakeNodeId)
            WirelessPortView(isOutput: false, id: fakeNodeId)
        }
    }
}
