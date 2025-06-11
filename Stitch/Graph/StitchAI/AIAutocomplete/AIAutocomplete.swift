//
//  AIAutocomplete.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/10/25.
//

import SwiftUI

struct AIAutocompleteState: Equatable, Hashable, Codable {
    // TODO: `suggestions` ?
    var suggestion: PatchOrLayer
}

struct AIAutocomplete: View {
    @Binding var state: AIAutocompleteState

    var body: some View {
        Text("Hello, World!")
            .onAppear {
                state = AIAutocompleteState(suggestion: PatchOrLayer.patch(.add))
            }
    }
}

//#Preview {
//    AIAutocomplete()
//}
