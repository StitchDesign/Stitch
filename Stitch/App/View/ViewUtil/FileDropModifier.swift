//
//  FileDropModifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/22.
//

import StitchSchemaKit
import SwiftUI
import UniformTypeIdentifiers

/*
 TODO: split between graph vs home view .onDrop logic?
 - home view should not allow attempted media drops
 - graph view should not allow attempted .stitch drops
 */
struct FileDropModifier: ViewModifier {
    @Environment(StitchStore.self) var store

    func body(content: Content) -> some View {
        content
            .onDrop(of: [.item],
                    isTargeted: nil,
                    perform: { handleOnDrop(providers: $0,
                                            location: $1,
                                            store: store) })
    }
}

// struct FileDropModifier_Previews: PreviewProvider {
//    static var previews: some View {
//        FileDropModifier()
//    }
// }
//
