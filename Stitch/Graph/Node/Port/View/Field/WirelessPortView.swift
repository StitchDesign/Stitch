//
//  WirelessPortView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/22/21.
//

import SwiftUI
import StitchSchemaKit

let WIRELESS_ICON = "wifi"

struct WirelessPortView: View {

    let isOutput: Bool
    let id: NodeId

    var body: some View {
        EmptyView()
    }
    
    var _body: some View {
        
        Image(systemName: WIRELESS_ICON)
//            .scaledToFit()
            .resizable()
            .foregroundColor(STITCH_TITLE_FONT_COLOR)
        
//            .rotation3DEffect(.degrees(isOutput ? 90 : 270),
//                              axis: (x: 0, y: 0, z: 1))
        
//            .scaledToFit()
//            .resizable()
//            .frame(PORT_ENTRY_NON_EXTENDED_HITBOX_SIZE)
            //            .offset(x: isOutput ? -4 : 4)
            .offset(x: isOutput ? -12 : 12)
//            .frame(height: NODE_ROW_HEIGHT)
            .frame(width: NODE_ROW_HEIGHT,
                   height: NODE_ROW_HEIGHT)
            .border(.orange)
            
//        #if targetEnvironment(macCatalyst)
//        .scaleEffect(1.2)
//        #else
//        .scaleEffect(0.85)
//        #endif
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
