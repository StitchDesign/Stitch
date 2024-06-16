//
//  PortLabelView.swift
//  prototype
//
//  Created by Christian J Clampitt on 2/16/22.
//

import SwiftUI

// label for input or output;
// only used when input/output.label != nil
struct PortLabelView: View {

    let label: String
    let id: NodeId

    var body: some View {
        Text("\(label)")
            .foregroundColor(TEXT_COLOR)
    }
}

struct PortLabelView_Previews: PreviewProvider {
    static var previews: some View {
        PortLabelView(label: "Test", id: 1)
    }
}
