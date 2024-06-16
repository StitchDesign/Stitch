//
//  InputValueTypeView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/16/22.
//

import SwiftUI

struct InputValueTypeView: View {

    let id: InputCoordinate
    let valueType: String

    var body: some View {
        Text(valueType)
            .foregroundColor(TEXT_COLOR)
    }
}

struct InputValueTypeView_Previews: PreviewProvider {
    static var previews: some View {
        InputValueTypeView(id: InputCoordinate(portId: 1,
                                               nodeId: 2),
                           valueType: "Test")
    }
}
