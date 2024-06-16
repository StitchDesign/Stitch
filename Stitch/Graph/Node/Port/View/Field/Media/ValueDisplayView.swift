//
//  ValueDisplayView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/16/22.
//

import SwiftUI

struct ValueDisplayView: View {

    let display: String
    let id: NodeId

    var body: some View {
        Text(display).foregroundColor(TEXT_COLOR)
            .frame(maxWidth: PORTVALUE_DISPLAY_WIDTH, maxHeight: 25)
    }
}

struct ValueDisplayView_Previews: PreviewProvider {
    static var previews: some View {
        ValueDisplayView(display: "Test value", id: 1)
    }
}
