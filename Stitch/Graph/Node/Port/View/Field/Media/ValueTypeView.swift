//
//  ValueTypeView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/16/22.
//

import SwiftUI

struct ValueTypeView: View {

    let valueType: String
    let id: NodeId

    var body: some View {
        Text(valueType)
            .foregroundColor(TEXT_COLOR)
    }
}

// struct ValueTypeView_Previews: PreviewProvider {
//    static var previews: some View {
//        ValueTypeView()
//    }
// }
