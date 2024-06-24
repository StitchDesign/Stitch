//
//  iPadDropdownView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/26/22.
//

import SwiftUI
import StitchSchemaKit

// Just displays the values; the selection logic is handled by Picker's selection-binding.
struct iPadPickerChoicesView: View {

    let choices: [String]

    var body: some View {
        ForEach(choices, id: \.self) { (choice: String) in
            StitchTextView(string: choice)
        }
    }
}

// struct iPadDropdownView_Previews: PreviewProvider {
//    static var previews: some View {
//        iPadDropdownView()
//    }
// }
